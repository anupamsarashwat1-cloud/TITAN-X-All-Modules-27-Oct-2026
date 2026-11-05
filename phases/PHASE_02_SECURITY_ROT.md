# Phase 02: Security Architecture & Trust Anchor

**Phase ID:** `PHASE-02`  
**Target Milestone:** M2 — Hardware Root-of-Trust Architecture  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** `PHASE-01` complete  

## 1. Objective
Replace immutable RTL-gate public keys with a 4-slot OTP eFuse model (`DEF-SEC-02`) and integrate monotonic anti-rollback counters (`DEF-SEC-03`).

## 2. Tasks
- `TASK-02-01`: Implement OTP eFuse controller model and multi-key trust anchor verification (`DEF-SEC-02`).
- `TASK-02-02`: Implement monotonic security counter and anti-rollback verification in secure boot (`DEF-SEC-03`).

## 3. Architectural Decision Gates
- `ADR-02`: 4-Slot OTP eFuse Model with Revocation Bitmask.
- `ADR-03`: 64-Word Extended Boot Image Header Format.

## 4. Verification Plan
- Unit test: `tb_efuse_ctrl.v`.
- Subsystem test: `tb_secure_boot.v` with valid keys, revoked keys, and downgraded images.

## 5. Acceptance Criteria
- Revoked key slots reject firmware signatures.
- Image with security version < hardware counter halts in `S_HALT`.
