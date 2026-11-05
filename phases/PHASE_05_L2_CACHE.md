# Phase 05: L2 Cache SRAM Integration & Geometry Closure

**Phase ID:** `PHASE-05`  
**Target Milestone:** M4 — Coherent Memory Hierarchy  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** `PHASE-01` complete  

## 1. Objective
Replace behavioral flip-flop arrays with compiled foundry SRAM macros (`DEF-ARCH-04`) and propagate target capacity parameters (`DEF-ARCH-03`).

## 2. Tasks
- `TASK-05-01`: Integrate compiled foundry SRAM macros into L2 cache data and tag arrays (`DEF-ARCH-04`).
- `TASK-05-02`: Propagate L2 cache capacity parameters and scale sets to architectural target (`DEF-ARCH-03`).

## 3. Architectural Decision Gate
- `ADR-05`: Banked Foundry SRAM Macro Architecture (1-cycle synchronous latency).

## 4. Verification Plan
- Unit test: `tb_l2_data_array.v` verifying 1-cycle synchronous read latency.
- Subsystem test: `tb_l2_cache_top.v` running 10,000 random reads and writes.

## 5. Acceptance Criteria
- L2 cache operates cleanly with SRAM macros; synthesis cell area reduced by >70%.
- Zero address aliasing across full set-index space.
