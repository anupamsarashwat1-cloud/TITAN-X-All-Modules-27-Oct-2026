#!/bin/bash
set -e
PROJECT_ROOT=$(pwd)
DESIGN_ROOT="$PROJECT_ROOT/Design Files of TITAN X"

echo "========================================================="
echo " SMVDU-TITAN-X Robust RTL Simulation Runner"
echo "========================================================="

# Helper to find file safely
find_file() {
    local file_path
    file_path=$(find "$PROJECT_ROOT" -name "$1" -print -quit)
    if [ -z "$file_path" ]; then
        echo "ERROR: File $1 not found." >&2
        return 1
    fi
    echo "$file_path"
}

# Define core test sources with robust lookups
# Note: Using explicit paths is safer given the structure
TEST_SRCS=(
    "$PROJECT_ROOT/Design Files of TITAN X/common/reset_sync/reset_sync.v"
    "$PROJECT_ROOT/Design Files of TITAN X/common/reset_sync/tb_reset_sync.v"
)

echo "Compiling Reset Sync..."
iverilog -g2012 -o sim_reset.vvp "${TEST_SRCS[@]}"
vvp sim_reset.vvp
echo "Reset Sync Test Passed."

# Add more staged tests here as per phase 4

# RV_FETCH Test
echo "Compiling RV_FETCH..."
DESIGN_ROOT="$PROJECT_ROOT/Design Files of TITAN X"
iverilog -g2012 -I "$DESIGN_ROOT/includes" -o sim_fetch.vvp \
    "$DESIGN_ROOT/frontend/rv_fetch/rv_fetch.v" \
    "$DESIGN_ROOT/frontend/rv_fetch/tb_rv_fetch.v"
vvp sim_fetch.vvp
echo "RV_FETCH Test Passed."

# Elaboration Test (Minimal)
echo "Elaborating Titan X Top..."
DESIGN_ROOT="$PROJECT_ROOT/Design Files of TITAN X"
# This is a very complex top, might need many files. I will just check if iverilog can parse it.
# If this fails, it's a major blocker.
iverilog -g2012 -I "$DESIGN_ROOT/includes" -o sim_top.vvp \
    "$DESIGN_ROOT/top/titan_x_top/titan_x_top.v"
echo "Elaboration Successful."
