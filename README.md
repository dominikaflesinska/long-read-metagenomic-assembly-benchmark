# Long-read metagenomic assembly benchmark: metaFlye vs myloasm

## Overview

**myloasm** ([Shaw & Yu, *Nat. Biotechnol.* 2026](https://doi.org/10.1038/s41587-026-03053-z)) is a recently published long-read metagenome assembler reporting large improvements over the previous state of the art, particularly on Oxford Nanopore data. This repository benchmarks it against the established **metaFlye** assembler ([Kolmogorov et al., *Nat. Methods* 2020](https://doi.org/10.1038/s41592-020-00971-x)) on one sample from the CAMI III toy human gut long-read dataset ([cami-challenge.org](https://cami-challenge.org/datasets/toy-human-gut)), to get a hands-on feel for how each performs on a complex, realistic microbial community.

The workflow:

1. assembly with **metaFlye** and **myloasm** on the same set of long reads
2. comparison of both assemblies against the sample's gold-standard reference with **(Meta)QUAST** ([Mikheenko et al., *Bioinformatics* 2016](https://doi.org/10.1093/bioinformatics/btv697))
3. inspection of the QUAST HTML report to get a feeling for assembly metrics and possible assembly issues (fragmentation, misassemblies, genome recovery)

Optional long-read trimming ([fastplong](https://github.com/OpenGene/fastplong)) and host-read filtering ([deacon](https://github.com/bede/deacon)) were not applied in this run, reads were assembled directly from the raw CAMI III FASTQ, since the dataset is already simulated/host-free.

The project was performed on an HPC Linux environment and includes workflow automation, reproducibility files, and documentation of a real-world Rust/C FFI compilation issue encountered during myloasm installation.

## Project status

Completed:
- long-read assembly with metaFlye and myloasm
- gold-standard reference comparison using metaQUAST
- assembly metric analysis
- reproducible workflow scripts
- documentation of myloasm SIMD compilation/debugging issue
## Workflow

```text
CAMI III human gut long reads
            |
            |
     -----------------
     |               |
     v               v
 metaFlye        myloasm
     |               |
     v               v
assembly.fasta  assembly_primary.fa
     \             /
      \           /
       v         v
     metaQUAST comparison
            |
            v
 Assembly quality assessment
```

## Dataset

**Dataset:** CAMI III toy human gut long-read dataset

**Input reads:** `reads/sample_0_reads/anonymous_reads.fq.gz`

**Read statistics:**

| Metric | Value |
|---|---|
| Number of reads | 1,136,798 |
| Mean read length | 4,001 bp |
| Read N50 | 4,663 bp |
| Maximum read length | 23,439 bp |

**Reference:** `reference/gold.fasta`

**Reference size:** 416.96 Mb

## Assembly methods

### metaFlye

Flye was executed in metagenomic mode (`--meta`), i.e. metaFlye:

```bash
flye \
  --nano-hq reads/sample_0_reads/anonymous_reads.fq.gz \
  --meta \
  -o assemblies/flye_sample0 \
  -t 50
```

### myloasm

myloasm was executed using Nanopore long reads:

```bash
myloasm \
  reads/sample_0_reads/anonymous_reads.fq.gz \
  -o assemblies/myloasm_sample0_retry \
  -t 50
```

## Assembly evaluation

Assemblies were compared against the CAMI gold-standard reference using:

- metaQUAST
- QUAST assembly statistics

Main metrics: total assembly length, number of contigs, N50, L50, genome fraction, misassemblies, aligned fraction.

## Results

| Assembler | Total length | Contigs | N50 | Genome fraction |
|---|---|---|---|---|
| metaFlye | 4.42 Mb | 61 | 190.6 kb | 1.95% |
| myloasm | 110.88 Mb | 13,186 | 9.0 kb | 11.16% |

### Results interpretation

**metaFlye**

metaFlye generated a highly contiguous assembly:

- 61 contigs
- N50: 190,611 bp
- largest contig: 608 kb

However, only 1.95% of the reference genome content was recovered. This indicates that metaFlye reconstructed mainly higher-abundance members of the microbial community while failing to recover a large fraction of lower-abundance organisms.

**Strength:** excellent contiguity
**Limitation:** limited community recovery

**myloasm**

myloasm recovered substantially more genomic content:

- assembly size: 110.88 Mb
- genome fraction: 11.16%

However, the assembly was highly fragmented:

- 13,186 contigs
- N50: 9,034 bp
- L50: 4,776

The result demonstrates the difficulty of long-read metagenomic assembly when reconstructing diverse microbial communities containing many organisms and strains.

**Strength:** improved recovery of community sequence space
**Limitation:** increased fragmentation

### Key finding

This benchmark highlights that N50 alone is not sufficient for evaluating metagenomic assemblies. metaFlye produced a much more contiguous assembly, but recovered much less of the microbial community. myloasm recovered substantially more sequence content, but with increased fragmentation.

For complex metagenomes, assembly evaluation requires balancing continuity, completeness, diversity recovery, and accuracy.

## Engineering challenge: myloasm SIMD compilation failure

During the installation of myloasm, the build failed at the linking stage of its `abpoa-rs` / `abpoa-ffi-sys` dependency, which compiles the [abPOA](https://github.com/yangao07/abPOA) partial-order aligner from C via a Cargo `build.rs` script.

### Symptom

```
undefined reference to `simd_sse2_abpoa_align_sequence_to_subgraph'
```

The CPU-dispatch layer (`abpoa_dispatch_simd.c`) expected an SSE2 symbol, but inspecting the compiled static library showed it exported the wrong one:

```bash
nm libabpoa_align_simd_sse2.a | grep " T simd"
# 0000000000000000 T simd_sse41_abpoa_align_sequence_to_subgraph
```

A library named `_sse2` contained SSE4.1 code — despite `build.rs` compiling that variant with `-msse2 -U__SSE4_1__`.

### Root cause

The build script compiles four ISA variants of the same C source (`abpoa_align_simd.c`) — SSE2, SSE4.1, AVX2, AVX512BW — using the [`cc`](https://docs.rs/cc) crate, once per variant with different flags. Diagnosis required intercepting the actual compiler invocations (via a logging wrapper on `PATH`, since `cargo build -vv` does not print `cc`-crate-issued compiler commands) and comparing them byte-for-byte against manual reproductions. Two independent bugs were found stacked on top of each other:

1. **Object file collisions.** The `cc` crate derives each compiled object's filename from a hash of the *source file path*, not its compile flags. Since all four variants compile `abpoa_align_simd.c` into the same `OUT_DIR`, they raced to write the same `.o` filename, so the wrong variant's object could end up archived into `libabpoa_align_simd_sse2.a`.

   **Fix:** give each ISA variant its own `OUT_DIR` subfolder via `cc::Build::out_dir()`, so the four compilations never touch the same object file.

2. **`-U__SSE4_1__` doesn't disable the actual target ISA.** Even after isolating the output directories, the SSE2 variant *still* compiled to the SSE4.1 code path. `-U__SSE4_1__` removes only the preprocessor macro; on this toolchain (GCC 11.5, RHEL 9) SSE4.1/4.2 are part of the default enabled instruction set, and `<immintrin.h>`'s per-intrinsic `#pragma GCC target(...)` / `push_options` / `pop_options` blocks restore ISA-related macros based on what the compiler can *actually* target — not what the command line last `#undef`'d. The macro was gone right after preprocessing in isolation, but came back once the real compilation walked through the SSE4.1 intrinsic headers.

   **Fix:** explicitly disable the higher ISA levels at the target-feature level, not just their macros:
   ```rust
   compile_variant(
       "abpoa_align_simd_sse2",
       &["-msse2", "-mno-sse3", "-mno-ssse3", "-mno-sse4.1", "-mno-sse4.2", "-mno-avx", "-mno-avx2"],
   );
   ```

Both fixes were verified independently with `nm`, confirming each of the four resulting static libraries exports exactly the symbol its filename promises, after which the crate linked and `myloasm` built successfully.

This issue is a good illustration of a class of bug that's easy to misdiagnose as an environment problem (stale cache, wrong `CFLAGS`, `ccache`) when it's actually rooted in how build tooling composes per-target compiler invocations, and in the difference between *preprocessor* and *codegen* ISA state in GCC.

Detailed troubleshooting notes are included in `docs/TROUBLESHOOTING.md`.

## Reproducibility

The project provides scripts and environment information required to reproduce the analysis.

The workflow was executed using separate Conda environments for assembly and QUAST evaluation.

**Run metaFlye assembly**

```bash
bash scripts/run_flye.sh
```

**Run myloasm assembly**

```bash
bash scripts/run_myloasm.sh
```

**Run metaQUAST evaluation**

```bash
bash scripts/run_metaquast.sh
```

All scripts are executed from the project root directory.

## Repository structure

```
cami_project/
├── README.md
├── environment.yml
│
├── scripts/
│   ├── run_flye.sh
│   ├── run_myloasm.sh
│   └── run_metaquast.sh
│
├── results/
│   ├── assembly_summary.tsv
│   ├── report.tsv
│   └── metaquast_report.html
│
├── docs/
│   └── TROUBLESHOOTING.md
│
├── assemblies/
├── reads/
├── reference/
└── myloasm/
```

Large generated files - raw sequencing reads, assembly outputs, temporary build files, and intermediate assembler data, are excluded from version control.

## Limitations

This benchmark was performed on a single CAMI III toy human gut sample. The results should not be interpreted as a universal ranking of assemblers. Assembly performance depends on sequencing technology, read accuracy, microbial community complexity, abundance distribution, and computational resources.

## Conclusion

This project demonstrates the challenges of long-read metagenomic assembly and evaluation. metaFlye generated a highly contiguous assembly but recovered only a small fraction of the microbial community. myloasm recovered considerably more genomic content, suggesting improved recovery of community diversity, but produced a more fragmented assembly.

Beyond biological analysis, the project also demonstrates practical computational skills including HPC workflow development, reproducible pipeline design, assembler benchmarking, assembly quality evaluation, and debugging of Rust/C FFI dependencies and compiler-level SIMD/ISA compilation issues.

The final workflow provides a reproducible framework for comparing long-read metagenomic assemblers and analysing their trade-offs.
