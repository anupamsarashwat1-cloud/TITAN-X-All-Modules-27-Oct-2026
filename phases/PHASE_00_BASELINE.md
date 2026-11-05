# Phase 00: Baseline Environment & Reproducibility Harness

**Phase ID:** `PHASE-00`  
**Target Milestone:** M1 — Pre-Remediation Reproducibility  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** None  

## 1. Objective
Establish an automated regression harness to compile and simulate all existing modules, recording exit codes and logs without manual log inspection.

## 2. Tasks
- `TASK-00-01`: Build automated Python regression runner (`scripts/run_regression.py`).

## 3. Verification Plan
- Run harness across 10 sample unit testbenches.
- Validate capture of exit codes and log files in `artifacts/qualification/logs/`.
- Ensure tool failures produce explicit non-zero exit codes.

## 4. Acceptance Criteria
- Reproducible regression results generated automatically for all standalone modules.
