# TITAN-X Top Level

## Overview
The top-level SoC wrapper for the TITAN-X multi-core processor.

## Working
Instantiates 4 primary RISC-V cores and 1 monitor core. Connects them via an AXI4 Crossbar to main memory (AXI RAM) and peripherals (UART, SPI, I2C, PLIC, CLINT) via an AXI-AHB-APB bridge hierarchy.

## Need
Serves as the root module for Verilator simulation and synthesis.

## Steps to Use
1. Provide `clk` and `rst_n`.
2. Connect external I/O pins (UART TX/RX, GPIOs).
3. Load firmware into the RAM model and simulate.