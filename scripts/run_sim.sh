#!/bin/bash
set -e
# Determine project root based on script location (assumes scripts/run_sim.sh)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DESIGN_ROOT="$PROJECT_ROOT/Design Files of TITAN X"

echo "============================================"
echo " SMVDU-TITAN-X SoC RTL Simulation (Portable)"
echo "============================================"

# Using absolute paths is acceptable here because we derive them from the repository root
SRCS=(
    "$DESIGN_ROOT/common/interfaces.sv"
    "$DESIGN_ROOT/common/reset_sync/reset_sync.v"
    "$DESIGN_ROOT/common/cdc_sync/cdc_sync.v"
    "$DESIGN_ROOT/common/fifo_sync/fifo_sync.v"
    "$DESIGN_ROOT/common/fifo_async/fifo_async.v"
    "$DESIGN_ROOT/frontend/rv_fetch/rv_fetch.v"
    "$DESIGN_ROOT/frontend/rv_decode/rv_decode.v"
    "$DESIGN_ROOT/backend/rv_execute/rv_execute.v"
    "$DESIGN_ROOT/backend/rv_mem/rv_mem.v"
    "$DESIGN_ROOT/backend/rv_writeback/rv_writeback.v"
    "$DESIGN_ROOT/backend/rv_core_top/rv_core_top.v"
    "$DESIGN_ROOT/backend/clint/clint.v"
    "$DESIGN_ROOT/backend/plic/plic.v"
    "$DESIGN_ROOT/memory/sram_32x64_180nm/sram_32x64_180nm.v"
    "$DESIGN_ROOT/memory/l2_tag_array/l2_tag_array.v"
    "$DESIGN_ROOT/memory/l2_data_array/l2_data_array.v"
    "$DESIGN_ROOT/memory/l2_cache_ctrl/l2_cache_ctrl.v"
    "$DESIGN_ROOT/memory/l2_cache_top/l2_cache_top.v"
    "$DESIGN_ROOT/interconnect/axi4_crossbar/axi4_crossbar.v"
    "$DESIGN_ROOT/top/titan_x_top/titan_x_top.v"
)

# Check all exist
for f in "${SRCS[@]}"; do
    if [ ! -f "$f" ]; then echo "MISSING: $f"; exit 1; fi
done

# Compile
iverilog -g2012 -o sim.vvp "${SRCS[@]}"
# Simulate
vvp sim.vvp
