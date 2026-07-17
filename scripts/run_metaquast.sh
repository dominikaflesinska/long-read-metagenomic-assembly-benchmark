#!/bin/bash

set -e

# Run from project root directory

metaquast.py \
  assemblies/flye_sample0/assembly.fasta \
  assemblies/myloasm_sample0/assembly_primary.fa \
  -r reference/gold.fasta \
  -o quast/metaquast_compare \
  -t 8
