# AXI4 to AHB Bridge

## Overview
A protocol converter bridging the 64-bit AXI4 interconnect to the 32-bit AHB-Lite peripheral bus.

## Working
Translates AXI4 transactions (AW/W/B for writes, AR/R for reads) into AHB-Lite phases (Address and Data). Handles byte lane shifting for 64-bit to 32-bit width conversions.

## Need
Required because high-speed memory uses AXI4, while lower-speed peripherals use AHB/APB.

## Steps to Use
1. Connect the AXI slave interface to the crossbar.
2. Connect the AHB master interface to the APB bridge.