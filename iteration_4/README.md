# TITAN-X SoC: Iteration 4 (Linux Bring-up & Architecture Upgrades)

## Description
This directory contains the updated RTL design files for **Iteration 4** of the TITAN-X multi-core RISC-V SoC. 
In Iteration 3, the design successfully verified basic AXI interconnects, memory mapping, and peripherals. However, the RISC-V cores (`rv_core_top`) were implemented as simple `rv64imac` subsets without Control and Status Registers (CSRs) or hardware Atomic Memory Operations (AMOs).

## The Need for Iteration 4
To boot modern Operating Systems like Linux and multi-core bootloaders like OpenSBI, the processor *must* support:
1. **The "Zicsr" Extension:** OpenSBI and Linux rely on CSRs (e.g., `mhartid`, `mstatus`, `mtvec`, `satp`) to manage processor state, identify core IDs, handle interrupts, and configure virtual memory.
2. **The "A" (Atomic) Extension:** Multi-core systems require atomic instructions (e.g., `amoadd.w`, `amoswap.w`, `lr`/`sc`) to implement hardware spinlocks. Without them, OpenSBI's boot lottery fails, causing all cores to spin endlessly.

## Plan & Objective
The goal of Iteration 4 is to upgrade the TITAN-X core architecture to be fully Linux-capable:
- **`rv_csr` Implementation:** Build and integrate a new CSR module to handle Machine and Supervisor level privileges.
- **AMO Implementation:** Upgrade the Load-Store Unit and D-Cache to handle atomic read-modify-write sequences.
- **Trap Handling:** Add hardware trap vectors to correctly handle exceptions, page faults, and system calls (`ecall`/`ebreak`).
- **Firmware Execution:** Successfully boot OpenSBI and run the Linux kernel payload in a Verilator simulation, verifiable via UART terminal output.

## Directory Structure
- `src/`: Contains all the baseline design modules inherited from Iteration 3 (with APB and PMP bug fixes applied). These files will be actively modified during this iteration. Each sub-directory contains its own custom, descriptive `README.md`.
- `design and everything after iteration 4/`: (To be created upon completion) Will hold the final, verified architecture and synthesis scripts post-bringup.

## Status
- **Current Phase:** Implementation.
- **Next Steps:** Developing `rv_csr.v` and integrating trap logic into `rv_core_top.v`.
