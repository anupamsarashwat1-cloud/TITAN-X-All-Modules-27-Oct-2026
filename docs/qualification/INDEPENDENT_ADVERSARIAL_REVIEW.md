# SMVDU TITAN X — Independent Adversarial Engineering Review Report

**Document ID:** `DOC-QUAL-REV-2026-11-17`  
**Review Type:** Independent Adversarial Engineering Audit & Technical Due Diligence  
**Target Repository:** [`TITAN-X-2026-11-04`](https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04)  
**Target Branch:** [`reconciliation/canonical-repository-2026-11-05`](https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04/tree/reconciliation/canonical-repository-2026-11-05)  
**Reviewed Remote HEAD SHA:** `662917b943ee58d878c890a4d4acbdfd4d1a87ef`  
**Review Date:** 2026-11-17  
**Review Status:** **COMPLETE**

---

## 1. Executive Summary & Review Verdict

### Final Review Verdict: **CONDITIONAL PASS**

> **Formal Determination:**  
> The SMVDU TITAN X SoC RTL baseline achieves **CONDITIONAL PASS** for qualification.
> 
> **Rationale:**
> 1. **No Fatal Security or Functional Gaps in Remediated Subsystems:** The hardware Root of Trust (RoT), multi-key OTP eFuse anchor, monotonic anti-rollback mechanism, FIPS 180-4 SHA-256 automated padding, multicycle NIST P-256 ECDSA engine, 28-aperture APB decoding, and AXI4 crossbar queue routing are implemented, synthesizable, and functionally sound.
> 2. **High-Severity Architectural Scope Deviations:** The actual instantiated processor core is **RV64IM_Zicsr in Machine-mode (M-mode)**. Floating-Point (`rv_fpu.v`), Atomic extensions (A), Compressed instructions (C), and Memory Management (`rv_mmu`, `rv_tlb`, `rv_ptw`, `rv_pmp`) exist in the repository as standalone files but are **not integrated** into the active `rv_core_top.v` pipeline (`fpu_result` is tied to zero; C-extension instructions are decoded as illegal). Documentation claiming "RV64GC Unix/Linux-ready" is inaccurate.
> 3. **Coherence Overflow Limitation:** `l2_snoop_filter.v` does not implement back-invalidation (eviction) of L1 cache lines when a directory set overflows (`alloc_way_comb` defaults to way 0).
> 4. **Physical ASIC Maturity Distinction:** Synthesis verification is currently at **technology-independent RTL elaboration** (Yosys 0.33 `hierarchy -check` and `stat`), not gate-level mapped standard-cell netlist, Place & Route (P&R), Clock Tree Synthesis (CTS), or sign-off Static Timing Analysis (STA).

---

## 2. Repository & Source Revision Provenance

| Parameter | Independent Audit Evidence | Status |
|---|---|---|
| **Remote URL** | `https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04.git` | Verified |
| **Audit Branch** | `reconciliation/canonical-repository-2026-11-05` | Verified |
| **Local Working Tree** | `/home/anupam-sarashwat/TITAN-X-2026-11-04` | Clean (0 uncommitted changes) |
| **Remote Commit SHA** | `662917b943ee58d878c890a4d4acbdfd4d1a87ef` | Verified live on GitHub via `git ls-remote` |
| **Preceding Milestones** | Main Repo: `b205625` (Phase 10 + bulk snapshot `gg`); Canonical: `bf50b16` | Verified |

---

## 3. Subsystem Adversarial Engineering Reviews

### A. Secure Boot & Root of Trust (RoT) — **VERIFIED PASS**
- **Trust Anchor Hardware Coupling:** Evaluated [`secure_boot.v:59-77`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/secure_boot/secure_boot.v#L59-L77) and [`efuse_ctrl.v:75-105`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/efuse_ctrl/efuse_ctrl.v#L75-L105). Public keys are retrieved strictly from immutable hardware eFuse arrays (`hw_rot_qx`, `hw_rot_qy`). While the firmware container header indicates a key slot index, the key data loaded into the ECDSA engine is sourced directly from `efuse_ctrl`, making rogue public key substitution in firmware impossible.
- **Anti-Rollback Enforcement:** `secure_boot.v:291-304` compares the firmware security version against `hw_security_counter`. Counter values can only increase in hardware (`monotonic_counter <= pwdata` only if `pwdata > monotonic_counter`). Downgrade images trigger immediate transition to `S_HALT`.
- **Fail-Safe Isolation:** In [`secure_boot.v:577-578`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/secure_boot/secure_boot.v#L577-L578), `boot_pass` is asserted strictly in `S_SUCCESS`. Any error (magic mismatch, length corruption, timeout, hash mismatch, or invalid ECDSA signature) locks the FSM in `S_HALT` (`boot_fail = 1`). In [`axi_rom.v:115-125`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/axi_rom/axi_rom.v#L115-L125), `s_arready` and `s_rvalid` are held at `1'b0` while `boot_pass == 0`, locking the processor fetch interface until authentication passes.

### B. SHA-256 Engine — **VERIFIED PASS**
- **FIPS 180-4 Compliance:** Evaluated [`sha256_engine.v:59-134`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/peripherals/sha256_engine/sha256_engine.v#L59-L134). Automated padding correctly handles:
  - Exact 64-byte multiples (`rem_bytes == 0`): Block 1 processes raw data; Block 2 emits `0x80` followed by 55 zero bytes and 64-bit length.
  - Multi-block transition (`rem_bytes >= 56`): Emits `calc_pad_block1` then pads length in Block 2.
  - Single-block messages (`rem_bytes < 56`): Appends `0x80`, zero padding, and 64-bit length in words 14–15.
- **Chaining State:** Verified iterative 64-round compression maintains intermediate hash values ($H_0 \dots H_7$). Multi-block streaming via `secure_boot.v:388-393` sets `init_hash=1` on Block 0 and `init_hash=0` on subsequent blocks, correctly preserving digest chaining across arbitrary image lengths.

### C. Processor Core ISA Scope — **HIGH-SEVERITY DISCREPANCY (FINDING-01)**
- **Advertised vs Implemented ISA:** Documentation across the project claims "RV64GC Application Cores". Inspection of the RTL netlist reveals:
  - **F & D Extensions:** [`rv_core_top.v:400`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/backend/rv_core_top/rv_core_top.v#L400) wires `.fpu_result(64'h0), .fpu_valid(1'b0), .fpu_done(1'b0)`. `rv_fpu.v` is not integrated into the execution datapath.
  - **A Extension:** [`rv_dcache.v:39`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/backend/rv_dcache/rv_dcache.v#L39) explicitly documents: `// Atomic: LR/SC reservation (A-ext absent in core today; tied off)`.
  - **C Extension:** [`rv_decode.v:65`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/frontend/rv_decode/rv_decode.v#L65) asserts `illegal_comb = (instr_in[1:0] != 2'b11);`. All 16-bit compressed instructions trap as illegal.
  - **Privilege & Virtual Memory:** `rv_mmu`, `rv_tlb`, `rv_ptw`, and `rv_pmp` are not instantiated in `rv_core_top.v`. Physical addressing is wired directly from execution to caches. The core supports only Machine Mode (M-mode) with basic CSRs and traps.
- **True Baseline:** The core is an authentic, functional **RV64IM_Zicsr M-mode** processor, not RV64GC.

### D. L1 & L2 Cache Subsystem — **VERIFIED WITH PARAMETER LIMITATIONS (FINDING-06)**
- **L1 Cache Geometry:**
  - D-Cache: 8 ways $\times$ 64 sets $\times$ 64 bytes = **32 KiB**, write-back, write-allocate.
  - I-Cache: 8 ways $\times$ 64 sets $\times$ 64 bytes = **32 KiB**, SEC-DED ECC protection on tag entries.
- **L2 Cache Capacity & Tag Array Implementation:**
  - Data storage integrates 256 compiled foundry SRAM macros (`sram_32x64_180nm`) across 4 banks.
  - In [`l2_cache_ctrl.v:115`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/memory/l2_cache_ctrl/l2_cache_ctrl.v#L115), `tag_mem` is implemented as behavioral flip-flop registers (`reg [TAG_W-1:0] tag_mem [0:SETS-1][0:WAYS-1]`).
  - At 2,048 sets (2 MiB), behavioral tag registers demand >688,000 flip-flop bits, which is impractical for ASIC synthesis without a compiled tag SRAM macro. Thus, `params.vh` scales `L2_SETS` to 64 sets (64 KiB) when `SYNTHESIS` is defined.

### E. Cache Coherence Directory — **HIGH-SEVERITY GAP (FINDING-02)**
- **MESI State Protocol:** Verified in [`l2_snoop_filter.v:65-210`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/memory/l2_snoop_filter/l2_snoop_filter.v#L65-L210). Directory correctly tracks `ST_I (00)`, `ST_S (01)`, `ST_E (10)`, and `ST_M (11)`. Handles `GetS` (downgrade to Shared), `GetM` (invalidate others), and `Inv` transactions across the 4 cores.
- **Directory Set Saturation (Eviction Omission):**
  In [`l2_snoop_filter.v:115-125`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/memory/l2_snoop_filter/l2_snoop_filter.v#L115-L125), `alloc_way_comb` defaults to `5'd0` if no invalid (`ST_I`) way is found:
  ```verilog
  alloc_way_comb = 5'd0;
  for (ai = 0; ai < DIR_WAYS; ai = ai + 1) begin
      if (dir_state[index][ai] == ST_I) alloc_way_comb = ai[4:0];
  end
  ```
  Line 214 admits: `// Allocate (find empty way or evict - PLRU omitted for brevity)`. If all 32 ways in a set are occupied, the filter overwrites way 0 without generating back-invalidations to the core holding the victim line. The victim line becomes an orphaned line in L1 that escapes future snoops.

### F. Interconnect & Memory Subsystem — **VERIFIED PASS**
- **AXI4 Crossbar:** 15 masters $\times$ 9 slaves. Queue-based routing (`wr_q`, `b_own`, `r_own`) preserves transaction integrity across pipeline bursts. Unmapped address access returns internal `DECERR (2'b11)`. Formally verified under SVA BMC.
- **APB Subsystem:** 28 distinct memory-mapped apertures decoded cleanly with zero wait-state combinational `prdata`.
- **DDR4 Memory Controller:** Synthesizable command scheduler, bank interleaver, and auto-refresh manager. However, [`ddr_phy_if.v`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/memory/ddr_phy_if/ddr_phy_if.v) uses an internal behavioral memory array rather than hard analog PHY macros.

---

## 4. Comprehensive Findings Register

| Finding ID | Severity | Subsystem | File & Line Reference | Summary & Technical Impact | Confirmation |
|---|---|---|---|---|---|
| **FINDING-01** | **High** | Processor Core | `backend/rv_core_top/rv_core_top.v:400` | **ISA Mismatch:** Advertised as RV64GC; actual integrated RTL is RV64IM_Zicsr M-mode. `rv_fpu.v` is tied off, A-ext is absent, C-ext traps as illegal, and MMU/PMP are uninstantiated. | **Confirmed Defect** |
| **FINDING-02** | **High** | Coherence Directory | `memory/l2_snoop_filter/l2_snoop_filter.v:115` | **Directory Eviction Omission:** When all directory ways in a set are allocated, way 0 is overwritten without back-invalidating the corresponding L1 line. | **Confirmed Defect** |
| **FINDING-03** | **High** | Implementation / Tapeout | Repository root / `synth_titan_x.tcl` | **Premature Tapeout Sign-Off Claim:** Synthesis is technology-independent RTL elaboration in Yosys (`hierarchy -check`, `stat`), not gate-level mapped standard cell netlist. No P&R, CTS, STA, or GDSII layout exists. | **Confirmed Discrepancy** |
| **FINDING-04** | **Medium** | Memory PHY | `memory/ddr_phy_if/ddr_phy_if.v:1-35` | **Behavioral DDR PHY:** DDR controller interacts with a behavioral internal memory array. Silicon implementation requires integration of a foundry DFI Hard PHY. | **Confirmed Architecture Limit** |
| **FINDING-05** | **Medium** | Debug Subsystem | `top/titan_x_top/titan_x_top.v:538-545` | **JTAG Pin Disconnection:** `rv_debug.v` has `tck`, `tms`, `tdi` tied to `1'b0` at top-level SoC. No external JTAG boundary pins are exposed on `titan_x_top`. | **Confirmed Defect** |
| **FINDING-06** | **Low** | L2 Cache | `memory/l2_cache_top/l2_cache_top.v:9` | **Standalone L2 Default Discrepancy:** Default parameter in `l2_cache_top.v` is 64 sets (64 KiB), though overridden to 2,048 sets (2 MiB) at top-level SoC. | **Confirmed Parameter Defect** |
| **FINDING-07** | **Informational** | Verification Runner | `scripts/run_regress.py:136` | **Full-Chip Simulation Timeout:** Interpreted Icarus Verilog (`vvp`) exceeds 600s runner timeout during full cryptographic container verification and multicore clocking of `tb_titan_x_top`. | **Confirmed Tool Limitation** |

---

## 5. Verification & Test Audit

- **Executed Test Matrix:** Published in [`docs/qualification/INDEPENDENT_REVIEW_TEST_MATRIX.csv`](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/docs/qualification/INDEPENDENT_REVIEW_TEST_MATRIX.csv).
- **Toolchain Audited:**
  - Yosys 0.33 (git sha1 2584903a060)
  - Icarus Verilog 12.0 (`iverilog` / `vvp`)
  - `yosys-smtbmc -s z3`
- **Formal Verification Provenance:** 5 SVA bounded model checking suites (`axi4_crossbar_formal.sv`, `l2_snoop_filter_formal.sv`, `rv_fetch_formal.sv`, `rv_regfile_formal.sv`, `secure_boot_formal.sv`) bound directly to final RTL modules and proven to depth 20.

---

## 6. Recommendations & Roadmap for Final Qualification

1. **Re-align Documentation to Actual ISA:** Update top-level README, architecture specifications, and memory maps to accurately state that the active processor core is **RV64IM_Zicsr M-mode**, retiring ungrounded RV64GC claims.
2. **Implement Directory Back-Invalidation:** Add an eviction FSM in `l2_snoop_filter.v` that issues `snoop_type = 2'b10 (Inv)` to all current sharers before allocating an occupied directory entry.
3. **Route Top-Level JTAG Pins:** Expose `tck`, `tms`, `tdi`, and `tdo` on `titan_x_top.v` boundary pins.
4. **Transition to Compiled Tag SRAMs for Tapeout:** Replace behavioral flip-flop arrays in `l2_tag_array.v` with compiled 180nm SRAM macros to allow full 2 MiB synthesis without area explosion.
5. **ASIC Physical Design Flow (RTL-to-GDSII):** Proceed to OpenROAD / commercial EDA synthesis with target foundry standard-cell library (`.lib`), followed by Floorplanning, Placement, Clock Tree Synthesis, Routing, Static Timing Analysis at 138.8 MHz, and DRC/LVS.
