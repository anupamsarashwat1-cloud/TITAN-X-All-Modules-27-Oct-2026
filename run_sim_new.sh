#!/bin/bash
set -e
H_DIR="/home/anupam-sarashwat/rtl_verification_handoff"
TB_DIR="/home/anupam-sarashwat/SMVDU_TITAN_X_RTL_to_GDS/verification"

echo "Compiling..."
iverilog -g2012 -Wall -Wno-timescale -Wno-implicit-dimensions \
  -I$H_DIR/includes -I$H_DIR/common \
  -o $TB_DIR/sim_titan_x.vvp \
  $(find $H_DIR -type f \( -name "*.v" -o -name "*.sv" \) | grep -v "/tb_") \
  $TB_DIR/axi_rom.sv \
  $TB_DIR/tb_titan_x_top.sv

echo "Simulating..."
vvp $TB_DIR/sim_titan_x.vvp
