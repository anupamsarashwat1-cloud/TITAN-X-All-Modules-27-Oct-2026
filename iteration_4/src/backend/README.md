# Backend

## Description
The backend subsystem handles instruction execution, memory access, and exception handling.

## Working
It includes execution units (rv_execute, rv_fpu), the memory management unit (rv_mmu), caches (rv_dcache), and control/status registers (clint, plic, rv_pmp). It executes decoded micro-ops, resolves branches, accesses memory, and retires instructions.

## Need
This is the core computational engine of the SoC, necessary for executing the RISC-V instruction set and managing system state.

## Steps to Use / Integrate
1. Instantiate the core execution pipeline (rv_core_top).
2. Connect to the data cache and interconnect.
3. Verify execution correctness against RISC-V ISA tests.
