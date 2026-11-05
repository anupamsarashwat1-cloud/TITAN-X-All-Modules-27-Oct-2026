# AXI4 Crossbar

## Overview
A high-performance N-master, M-slave AXI4 interconnect matrix.

## Working
Routes requests from multiple bus masters (e.g., 5 cores) to multiple slaves (RAM, APB bridge, Peripherals) using priority or round-robin arbitration. Handles address decoding to select the correct slave.

## Need
Allows multiple processors to share memory and peripherals concurrently without data collision.

## Steps to Use
1. Define `NM` (Masters) and `NS` (Slaves).
2. Configure address decoding ranges inside the module.
3. Connect master and slave AXI ports.