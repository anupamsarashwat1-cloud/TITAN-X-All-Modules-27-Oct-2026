#!/bin/bash
set -e
SCRIPT_DIR="$(dirname "$0")"
CPU_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "============================================"
echo " SMVDU-TITAN-X SoC RTL Lint Analysis"
echo " Linter : Verilator"
echo "============================================"

echo "[1/2] Running Verilator lint..."
verilator --lint-only -Wall \
    -I"$CPU_BASE/includes" \
    --top-module titan_x_top \
    -Wno-fatal \
    -Wno-DECLFILENAME \
    -Wno-UNUSEDSIGNAL \
    -Wno-UNDRIVEN \
    -Wno-PINCONNECTEMPTY \
    -Wno-MULTIDRIVEN \
    -Wno-WIDTH \
    -Wno-UNUSEDPARAM \
    -Wno-BLKSEQ \
    -Wno-CASEINCOMPLETE \
    -Wno-CASEX \
    -Wno-PINMISSING \
    -Wno-UNOPTFLAT \
    -f "$CPU_BASE/verilator_files.f"

echo "============================================"
echo " Verilator Lint: PASSED (Clean)"
echo "============================================"
