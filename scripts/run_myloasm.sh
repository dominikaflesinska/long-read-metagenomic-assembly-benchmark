#!/bin/bash

set -e

./myloasm/target/release/myloasm \
  reads/sample_0_reads/anonymous_reads.fq.gz \
  -o assemblies/myloasm_sample0 \
  -t 50
