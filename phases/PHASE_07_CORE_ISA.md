# Phase 07: Processor Core ISA Baseline & Traps

**Phase ID:** `PHASE-07`  
**Target Milestone:** M5 — Processor Execution & Netlist Reconciliation  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** `PHASE-04` complete  

## 1. Objective
Formally baseline processor core as RV64IM_Zicsr Machine-Mode, stabilize trap handling (`DEF-ARCH-05`), and clean up 18 unintegrated repository modules (`DEF-ARCH-06`).

## 2. Tasks
- `TASK-07-01`: Formally baseline processor core as RV64IM_Zicsr Machine-Mode and stabilize trap handling (`DEF-ARCH-05`).
- `TASK-07-02`: Reconcile top-level SoC netlist and clean up 18 unintegrated IP blocks (`DEF-ARCH-06`).

## 3. Architectural Decision Gate
- `ADR-08`: RV64IM_Zicsr Machine-Mode Baseline with Phased OS Evolution.

## 4. Verification Plan
- Compliance suite: `tb_rv_core_compliance.v` running official `riscv-tests` (rv64ui, rv64um).
- Top elaboration: Yosys `hierarchy -top titan_x_top` checking for undriven nets.

## 5. Acceptance Criteria
- 100% pass on RV64UI and RV64UM compliance suites.
- Top-level netlist elaborates without undriven nets or blackbox warnings.
