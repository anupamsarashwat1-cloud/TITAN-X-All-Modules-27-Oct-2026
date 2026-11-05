# RV Core Top

## Overview
The `rv_core_top` module is the top-level wrapper for a single RISC-V hart in the TITAN-X SoC. It instantiates the execution pipeline (fetch, decode, execute, memory, writeback), MMU/TLB interfaces, caches, and physical memory protection (PMP).

## Working
Coordinates instruction fetching, decoding, execution, and exception handling. It acts as the orchestrator for all backend components, routing data between caches and execution units.

## Need
Essential to encapsulate the complex inner workings of the RISC-V core, providing a clean interface (AXI/AHB) to the rest of the SoC.

## Steps to Use
1. Instantiate in `titan_x_top`.
2. Tie `HART_ID` and `RESET_PC` parameters.
3. Connect to the AXI Interconnect for memory and peripheral access.