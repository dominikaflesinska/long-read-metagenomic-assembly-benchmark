# Troubleshooting notes

## abpoa-rs / abpoa-ffi-sys SIMD linker failure

## Symptom

During myloasm compilation:
undefined reference to simd_sse2_abpoa_align_sequence_to_subgraph


## Investigation

The dispatcher expected:
simd_sse2_abpoa_align_sequence_to_subgraph


but the compiled SIMD library exported:
simd_sse41_abpoa_align_sequence_to_subgraph


Inspection:
nm libabpoa_align_simd_sse2.a | grep " T simd"

revealed an SSE2/SSE4.1 mismatch.

## Resolution

The SIMD components were rebuilt with consistent architecture settings.
After cleaning stale build artifacts:
cargo clean
cargo build --release

myloasm compiled successfully.

## Lesson

Hybrid Rust/C bioinformatics tools require compatibility between:
- Rust FFI bindings
- C libraries
- compiler SIMD flags
- CPU architecture

## Build evidence

The original compiler output is preserved in:
myloasm_build_failure.log

The failure occurred during linking of the abpoa SIMD implementation.
