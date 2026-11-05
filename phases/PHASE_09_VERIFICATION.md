# Phase 09: Verification Overhaul & Coverage Closure

**Phase ID:** `PHASE-09`  
**Target Milestone:** M6 — Verification Quality & Assertion Closure  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** `PHASE-04`, `PHASE-07` complete  

## 1. Objective
Replace vacuous testbenches with genuine CPU boot regressions (`DEF-VERIF-01`), de-mock integration decoders (`DEF-VERIF-02`), and catalog SVA formal properties (`DEF-VERIF-03`).

## 2. Tasks
- `TASK-09-01`: Implement genuine end-to-end CPU boot and instruction retirement testbench (`DEF-VERIF-01`).
- `TASK-09-02`: De-mock integration testbench APB decoders and build exhaustive boundary regression (`DEF-VERIF-02`).
- `TASK-09-03`: Document formal verification SVA property inventory and toolchain prerequisites (`DEF-VERIF-03`).

## 3. Verification Plan
- Run overhauled `tb_titan_x_top.v` with self-checking test firmware.
- Run de-mocked `tb_integ_peripheral_bus.v` across all 28 APB address spaces.

## 4. Acceptance Criteria
- Top testbench verifies instruction retirement and writes 'TITAN-X OK' to UART0.
- 100% address boundary coverage on APB peripherals.
