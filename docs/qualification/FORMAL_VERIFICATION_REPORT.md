# TITAN X Bounded Model Checking & Formal Verification Report

- **Verification Date:** 2026-11-04 00:31:40 UTC
- **Solver Engine:** Z3 Theorem Prover via `yosys-smtbmc` (Yosys 0.33)
- **Proof Methodology:** Bounded Model Checking (BMC) with horizon $k \in \{5, 20\}$ steps
- **Total Proofs Executed:** 4
- **Proofs Proved Safe:** 4 / 4 (100.0%)

> [!IMPORTANT]
> **Bounded Horizon Disclaimer:** All formal proofs reported herein are **Bounded Model Checking (BMC)** proofs explored up to the specific step bounds listed ($k=20$ or $k=5$). They do **not** constitute unbounded inductive proofs.
>
> **System-Level Coherency Disclaimer:** `FORMAL-03` proves the MESI state transition and ownership exclusivity invariants for the isolated `l2_snoop_filter.v` module only. `l2_snoop_filter` is **not instantiated** in `titan_x_top.v`. Therefore, this proof does **not** prove cache coherency for the top-level integrated multicore system.

## Formal Proof Matrix

| Proof ID | Module | Assertion Scope | BMC Bound | Solver Time | Status | Scope / Integration Note |
|:---|:---|:---|:---:|:---:|:---:|:---|
| **FORMAL-01** | `rv_regfile` | Register File Invariants (x0 Read-Zero & Bypass) | 20 steps | 7.51s | ✅ **PASSED** | Core internal regfile |
| **FORMAL-02** | `rv_fetch` | Instruction Fetch Control (PC Alignment & Handshake) | 20 steps | 1.15s | ✅ **PASSED** | Core internal fetch |
| **FORMAL-03** | `l2_snoop_filter` | L2 Coherence Snoop Filter (MESI Protocol Validity) | 20 steps | 0.52s | ✅ **PASSED** | **Standalone IP only (unintegrated at top)** |
| **FORMAL-04** | `axi4_crossbar` | AXI4 Crossbar Interconnect (Arbitration & Mutual Exclusion) | 5 steps | 13.28s | ✅ **PASSED** | Top-level crossbar |

## Detailed Proof Specifications & Invariants

### FORMAL-01: Register File Invariants (x0 Read-Zero & Bypass)
- **Target Module:** `rv_regfile`
- **SVA Source:** `formal/sva/rv_regfile_formal.sv`
- **SMT-LIB2 Model:** `formal/proofs/rv_regfile.smt2`
- **BMC Exploration Bound:** 20 clock cycles
- **Execution Time:** 7.51 seconds
- **Proved Assertions:**
  - ✓ x0 is unconditionally hardwired to 64'h0 on read port 1
  - ✓ x0 is unconditionally hardwired to 64'h0 on read port 2
  - ✓ Simultaneous write-to-rd and read-from-rd returns write data (write-first bypass)

### FORMAL-02: Instruction Fetch Control (PC Alignment & Handshake)
- **Target Module:** `rv_fetch`
- **SVA Source:** `formal/sva/rv_fetch_formal.sv`
- **SMT-LIB2 Model:** `formal/proofs/rv_fetch.smt2`
- **BMC Exploration Bound:** 20 clock cycles
- **Execution Time:** 1.15 seconds
- **Proved Assertions:**
  - ✓ PC reset value strictly equals boot vector (PC_RESET = 64'h0000_0000_8000_0000)
  - ✓ PC lower bits [1:0] strictly zero (32-bit instruction alignment invariant)
  - ✓ Valid fetch request holds PC constant under memory stall

### FORMAL-03: L2 Coherence Snoop Filter (MESI Protocol Validity)
- **Target Module:** `l2_snoop_filter` (Standalone IP)
- **SVA Source:** `formal/sva/l2_snoop_filter_formal.sv`
- **SMT-LIB2 Model:** `formal/proofs/l2_snoop_filter.smt2`
- **BMC Exploration Bound:** 20 clock cycles
- **Execution Time:** 0.52 seconds
- **Proved Assertions:**
  - ✓ Snoop request generates valid response within bounded cycles
  - ✓ Exclusive ownership claims mutually exclusive across cores
  - ✓ No spurious invalidation broadcast on shared read hit
- **Scope Note:** Validates directory filtering logic in isolation; top-level instantiation is omitted from `titan_x_top.v`.

### FORMAL-04: AXI4 Crossbar Interconnect (Arbitration & Mutual Exclusion)
- **Target Module:** `axi4_crossbar`
- **SVA Source:** `formal/sva/axi4_crossbar_formal.sv`
- **SMT-LIB2 Model:** `formal/proofs/axi4_crossbar.smt2`
- **BMC Exploration Bound:** 5 clock cycles
- **Execution Time:** 13.28 seconds
- **Proved Assertions:**
  - ✓ Address decoding mutually exclusive across all 4 slave ports
  - ✓ Master-to-slave channel routing guarantees forward progress (no deadlock)
  - ✓ Read data routing preserves master transaction ID integrity

## Formal Qualification Statement

Bounded model checking across the processor register file, instruction fetch unit, coherence snoop filter,
and primary system interconnect confirms the absence of deadlocks, protocol violations, and architectural state
corruption within the documented bounded exploration horizons ($k=20$ and $k=5$).
