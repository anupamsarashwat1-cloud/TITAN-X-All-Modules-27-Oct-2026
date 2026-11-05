# Memory

## Description
The memory subsystem manages data storage and caching.

## Working
Includes L2 cache, SRAM, and DDR controllers. It handles requests from the interconnect and interfaces with physical memory.

## Need
Provides the primary storage for code and data. High bandwidth and low latency are crucial for performance.

## Steps to Use / Integrate
1. Instantiate DDR controller and L2 cache.
2. Connect to the AXI interconnect.
3. Verify memory bandwidth and latency.
