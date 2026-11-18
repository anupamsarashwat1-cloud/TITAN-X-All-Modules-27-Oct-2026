#!/bin/bash
set -e
echo "Starting simulation..."
iverilog -g2012 -I"Design Files of TITAN X/includes" -I"Design Files of TITAN X/common" -f soc_filelist.f -o sim.vvp
vvp sim.vvp
echo "Simulation complete."
