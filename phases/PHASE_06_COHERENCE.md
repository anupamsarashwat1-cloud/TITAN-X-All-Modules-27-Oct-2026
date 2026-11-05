# Phase 06: Cache Coherence & Multicore MESI

**Phase ID:** `PHASE-06`  
**Target Milestone:** M4 — Multicore Cache Coherence  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** `PHASE-05` complete  

## 1. Objective
Validate multicore MESI snooping, directory invalidations, and dirty-line interventions across Cores 0–3 on the new SRAM-backed L2 cache.

## 2. Tasks
- `TASK-06-01`: Validate multicore MESI cache coherence protocol and snoop directory invalidations.

## 3. Verification Plan
- Integration test: `tb_integ_multicore_mesi.v`.
- Concurrent true-sharing and false-sharing multi-core test cases.

## 4. Acceptance Criteria
- Mutual exclusion maintained; zero stale reads; snoop filter invalidates cleanly.
