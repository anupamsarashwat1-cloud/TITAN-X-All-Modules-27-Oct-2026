#!/bin/bash
# ============================================================================
# SMVDU-TITAN-X SoC — Restructured RTL Simulation Script
# Usage: ./run_sim.sh [--waves] [--lint-only]
# ============================================================================
set -e
CPU_BASE="$(dirname "$0")"

echo "============================================"
echo " SMVDU-TITAN-X SoC RTL Simulation (Restructured)"
echo " Simulator : Icarus Verilog (iverilog)"
echo "============================================"

# ── File lists ───────────────────────────────────────────────────────────────
COMMON_SRCS=(
    "$CPU_BASE/common/interfaces.sv"
    "$CPU_BASE/common/reset_sync.v"
    "$CPU_BASE/common/cdc_sync.v"
    "$CPU_BASE/common/fifo_sync.v"
    "$CPU_BASE/common/fifo_async.v"
)

CPU_SRCS=(
    "$CPU_BASE/frontend/rv_fetch.v"
    "$CPU_BASE/frontend/rv_decode.v"
    "$CPU_BASE/backend/rv_execute.v"
    "$CPU_BASE/backend/rv_mem.v"
    "$CPU_BASE/backend/rv_writeback.v"
    "$CPU_BASE/backend/rv_core_top.v"
    "$CPU_BASE/backend/clint.v"
    "$CPU_BASE/backend/plic.v"

)

MEM_SRCS=(
    "$CPU_BASE/memory/sram_32x64_180nm.v"
    "$CPU_BASE/memory/l2_tag_array.v"
    "$CPU_BASE/memory/l2_data_array.v"
    "$CPU_BASE/memory/l2_cache_ctrl.v"
    "$CPU_BASE/memory/l2_cache_top.v"
    "$CPU_BASE/memory/ddr_phy_if.v"
    "$CPU_BASE/memory/ddr_scheduler.v"
    "$CPU_BASE/memory/ddr_ctrl_top.v"
)

INTC_SRCS=(
    "$CPU_BASE/interconnect/axi4_crossbar.v"
    "$CPU_BASE/interconnect/axi4_to_ahb.v"
    "$CPU_BASE/interconnect/ahb_to_apb.v"
)

PERIPH_SRCS=(
    "$CPU_BASE/peripherals/uart_16550.v"
    "$CPU_BASE/peripherals/gpio_ctrl.v"
    "$CPU_BASE/peripherals/spi_master.v"
    "$CPU_BASE/peripherals/i2c_master.v"
    "$CPU_BASE/peripherals/watchdog_timer.v"
    "$CPU_BASE/peripherals/gem_ethernet.v"
    "$CPU_BASE/peripherals/pcie_top.v"
    "$CPU_BASE/peripherals/aes_engine.v"
    "$CPU_BASE/peripherals/sha256_engine.v"
    "$CPU_BASE/peripherals/trng.v"
)

TOP_SRCS=(
    "$CPU_BASE/top/titan_x_top.v"
)

TB_SRCS=(
    "$CPU_BASE/verification/axi_rom.sv"
    "$CPU_BASE/verification/tb_titan_x_top.sv"
)

ALL_SRCS=(
    "${COMMON_SRCS[@]}"
    "${CPU_SRCS[@]}"
    "${MEM_SRCS[@]}"
    "${INTC_SRCS[@]}"
    "${PERIPH_SRCS[@]}"
    "${TOP_SRCS[@]}"
    "${TB_SRCS[@]}"
)

# ── Options ───────────────────────────────────────────────────────────────────
WAVES=0
LINT_ONLY=0
for arg in "$@"; do
    case $arg in
        --waves)    WAVES=1 ;;
        --lint-only)LINT_ONLY=1 ;;
    esac
done

IVLOG_FLAGS="-g2012 -Wall -Wno-timescale -Wno-implicit-dimensions -I$CPU_BASE/common"
if [ $WAVES -eq 1 ]; then
    IVLOG_FLAGS="$IVLOG_FLAGS -DDUMP_WAVES"
fi

# ── Verify all source files exist ─────────────────────────────────────────────
echo "[1/4] Checking source files..."
MISSING=0
for f in "${ALL_SRCS[@]}"; do
    if [ ! -f "$f" ]; then
        echo "  MISSING: $f"
        MISSING=$((MISSING+1))
    fi
done
if [ $MISSING -gt 0 ]; then
    echo "ERROR: $MISSING source file(s) missing. Aborting."
    exit 1
fi
echo "  All $(echo "${#ALL_SRCS[@]}") source files present."

# ── Compile ───────────────────────────────────────────────────────────────────
echo "[2/4] Compiling with iverilog..."
iverilog $IVLOG_FLAGS \
    -o "$CPU_BASE/verification/sim_titan_x.vvp" \
    "${ALL_SRCS[@]}"
echo "  Compilation: PASSED"

if [ $LINT_ONLY -eq 1 ]; then
    echo "Lint-only mode: skipping simulation."
    exit 0
fi

# ── Simulate ──────────────────────────────────────────────────────────────────
echo "[3/4] Running simulation..."
vvp "$CPU_BASE/verification/sim_titan_x.vvp" | tee "$CPU_BASE/verification/sim_output.log"
echo "  Simulation complete. Log: verification/sim_output.log"

# ── Open waveforms ────────────────────────────────────────────────────────────
if [ $WAVES -eq 1 ] && [ -f "$CPU_BASE/verification/titan_x_waves.vcd" ]; then
    echo "[4/4] Opening GTKWave..."
    gtkwave "$CPU_BASE/verification/titan_x_waves.vcd" &
    echo "  GTKWave launched."
else
    echo "[4/4] Run with --waves to generate VCD and open GTKWave."
fi

echo "============================================"
echo " Done."
echo "============================================"
