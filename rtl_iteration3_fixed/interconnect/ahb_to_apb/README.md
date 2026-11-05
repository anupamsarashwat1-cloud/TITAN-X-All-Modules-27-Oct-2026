# AHB to APB Bridge

## Overview
A bridge connecting the AHB-Lite bus to the APB (Advanced Peripheral Bus).

## Working
Converts pipelined AHB transactions into two-cycle APB transfers (Setup and Access phases). Drives `psel`, `penable`, and `pwrite` for APB peripherals.

## Need
Peripherals like UART, GPIO, and I2C operate on the simpler APB protocol. This bridge integrates them into the AHB hierarchy.

## Steps to Use
1. Connect AHB inputs from the AXI-AHB bridge.
2. Fan out APB signals to all instantiated peripherals.