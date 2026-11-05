# Phase 03: Cryptographic Engines & Compliance

**Phase ID:** `PHASE-03`  
**Target Milestone:** M2 — Cryptographic Primitives Compliance  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** `PHASE-02` complete  

## 1. Objective
Implement automated FIPS 180-4 message padding in SHA-256 (`DEF-SEC-04`) and redesign ECDSA P-256 with a synthesizable multicycle Montgomery multiplier (`DEF-SEC-05`).

## 2. Tasks
- `TASK-03-01`: Implement automated FIPS 180-4 message padding and length encoding for SHA-256 (`DEF-SEC-04`).
- `TASK-03-02`: Redesign ECDSA P-256 engine with synthesizable multicycle Montgomery multiplier (`DEF-SEC-05`).

## 3. Architectural Decision Gate
- `ADR-04`: Multicycle Montgomery Multiplier Architecture.

## 4. Verification Plan
- Unit test: `tb_sha256_engine.v` against NIST CAVP test vectors.
- Unit test: `tb_ecdsa_engine.v` with valid and invalid signatures.
- Synthesis check: Yosys compilation of `ecdsa_engine.v` verifying timing closure.

## 5. Acceptance Criteria
- SHA-256 output matches standard OpenSSL digests for non-block-aligned inputs.
- ECDSA engine synthesizes cleanly without hanging and achieves timing closure at >= 50 MHz.
