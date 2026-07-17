# Assembly benchmark results

Dataset: CAMI III toy human gut long-read sample 0

| Assembler | Total length (bp) | Contigs | N50 | Genome fraction (%) |
|-----------|------------------:|--------:|----:|--------------------:|
| Flye | 4416721 | 61 | 190611 | 1.948 |
| myloasm | 110884960 | 13186 | 9034 | 11.156 |

## Interpretation

Flye produced a highly contiguous assembly with large contigs,
but recovered only a small fraction of the reference metagenome.

myloasm recovered substantially more genomic content,
but produced a much more fragmented assembly.

This highlights the trade-off between contiguity and genome recovery
in long-read metagenomic assembly.
