# SMVDU TITAN-X — Baseline Qualification & Forensics Audit Report

- **Baseline Commit**: `20703fef5e6934f40fe71ddbf090d241aead954a`
- **Execution Date**: 2026-11-04
- **Branch**: `remediation/final-engineering-qualification`
- **Recovery Tag**: `recovery/baseline-20703fe`
- **Target Remote**: `pub` (`https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-03.git`)
- **Protected Upstream**: `origin` (`https://github.com/anupamsarashwat1-cloud/TITAN-X-All-Modules-27-Oct-2026.git`) [READ-ONLY / UNTOUCHED]

---

## 1. Executive Baseline Findings

The source-level forensic audit of commit `20703fef5e6934f40fe71ddbf090d241aead954a` confirms that while previous records claimed 100% verification across all findings, several critical subsystems contain simulation stubs, false-positive test reporting, and incomplete architectural paths:

### Defect A: ECDSA P-256 Engine and Secure Boot Stubs
- **`security/ecdsa_engine/ecdsa_engine.v`**: Lines 89–108 contain a 16-cycle dummy counter that unconditionally asserts `stat_reg[2] <= 1'b1;` (pass) without performing any elliptic-curve point operations or modular arithmetic.
- **`security/secure_boot/secure_boot.v`**:
  - Compares only 32-bit `hash[0]` against expected digest `exp_digest` instead of the full 256-bit SHA-256 output.
  - Maintains a legacy rolling-hash bypass (`legacy_hash == exp_digest`) that enables authentication without genuine SHA-256 computation.
  - Releases `boot_pass` without checking the outcome of ECDSA signature verification.
  - Makes illegal non-synthesizable cross-module assignments directly into `u_sha256.msg_block`.
- **`top/titan_x_top/titan_x_top.v`**:
  - Hardcodes boot image data via combinational `assign envm_rdata = ...` in the top-level SoC wrapper.
  - Leaves `envm_ctrl` disconnected and bypassed.

### Defect B: L1 Cache Integration and False-Pass Testbench
- **`backend/rv_core_top/tb_rv_core_l1_cache.v`**:
  - Scenarios 5 through 13 print unconditional `$display("PASS [Scenario ...]")` without driving transactions or evaluating DUT outputs.
- **`backend/rv_core_top/rv_core_top.v`**:
  - Drops address bits `[2:0]` on memory accesses (`{cur_mem_addr[39:3], 3'b000}`).
  - Hardcodes memory request size to `3'b011` (doubleword), causing sub-word operations (`LB`, `LH`, `LW`, `SB`, `SH`, `SW`) to fail or misalign.
  - Directly couples AXI `arready` to `dcache_cpu_valid`.
- **`backend/rv_dcache/rv_dcache.v`**:
  - Only services snoop requests when idle (`state == D_IDLE`), ignoring snoops during active bursts or line refilling.

### Defect C: L2 Cache Geometry, Refill, Writeback & MESI Coherence
- **`memory/l2_cache_top/l2_cache_top.v`**:
  - Hardcodes tag lookups and writes to way 0 (`tags[tag_index][0]`), disabling 15 of the 16 claimed associative ways.
  - Leaves snoop filter responses (`sf_resp_*`) completely disconnected from the cache controller.
  - Indexes data array with only 6 bits, restricting capacity to 64 entries.
- **`memory/l2_cache_ctrl/l2_cache_ctrl.v`**:
  - Implements a single 64-bit word write-through controller rather than an 8-beat 64-byte burst refill and write-back architecture.
  - Lacks dirty-owner intervention datapath.

---

## 2. Protected Recovery Point and Branch Isolation

The dedicated qualification branch `remediation/final-engineering-qualification` has been created and verified at commit `20703fef5e6934f40fe71ddbf090d241aead954a`.
A persistent recovery tag `recovery/baseline-20703fe` points to this exact starting state.
All subsequent repairs will follow the Roo Code + GSD + Ralph Loop methodology.
