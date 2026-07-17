#!/bin/bash

set -e

flye \
  --nano-hq reads/sample_0_reads/anonymous_reads.fq.gz \
  --meta \
  -o assemblies/flye_sample0 \
  -t 50
