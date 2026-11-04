# SMVDU TITAN-X Master Findings Ledger

- **Execution Date:** 2026-11-04  
- **Governing Standard:** IEEE 1364-2001, IEEE 1800-2012, RISC-V Privileged Architecture v1.12  
- **Final Status:** **10 VERIFIED, 6 PARTIALLY VERIFIED, 1 OPEN** (Evidence-backed Remediation Audit)

---

## Summary Status Table

| Finding ID | Subsystem / Scope | Description | Final Status |
|:---|:---|:---|:---:|
| **FIND-TOP-01** | Top-Level Integration | L2 Cache Interface Integration | `PARTIALLY VERIFIED` |
| **FIND-TOP-02** | Top-Level Integration | Cache Coherence and Multicore Behavior | `OPEN` |
| **FIND-SEC-01** | Security | Secure Boot and Cryptographic Integration | `PARTIALLY VERIFIED` |
| **FIND-CORE-01** | Processor Spine | Processor Datapath, ISA and Pipeline Claims | `VERIFIED` |
| **FIND-CORE-02** | Privileged Arch | Exceptions, Traps and MRET Privileged Architecture | `VERIFIED` |
| **FIND-CORE-03** | FPU Coprocessor | Floating-Point Unit Integration and FMINMAX | `VERIFIED` |
| **FIND-MEM-01** | Memory Subsystem | MMU, TLB and PTW Integration | `PARTIALLY VERIFIED` |
| **FIND-PERIPH-01** | Interconnect / APB | Interrupt Controller and Peripheral Bus | `PARTIALLY VERIFIED` |
| **FIND-VIDEO-01** | Video Subsystem | Camera, ISP, DMA, Framebuffer and HDMI | `PARTIALLY VERIFIED` |
| **FIND-IO-01** | High-Speed IO | Ethernet, PCIe and USB High-Speed Interfaces | `PARTIALLY VERIFIED` |
| **FIND-BUS-01** | Crossbar Fabric | AXI Crossbar, Address Map and Bus Adapters | `VERIFIED` |
| **FIND-REG-01** | Verification Framework| Regression Runner Correctness | `VERIFIED` |
| **FIND-REG-02** | Verification Framework| Forensic Investigation of the 12 Suspicious X-Data Tests | `VERIFIED` |
| **FIND-FORMAL-01**| Formal Verification | Formal Verification Quality | `VERIFIED` |
| **FIND-MUT-01** | Verification Quality | Mutation Testing & Test Sensitivity | `VERIFIED` |
| **FIND-SYN-01** | Logic Synthesis | Synthesis & Gate Count Reconciliation | `VERIFIED` |
| **FIND-DOC-01** | Architecture Docs | Documentation Harmonization & Gate H Compliance | `VERIFIED` |

---

## 1. Architectural & Top-Level Integration Findings

### FIND-TOP-01: L2 Cache Interface Integration
- **Severity / Priority:** CRITICAL / P0
- **Source Reference:** `top/titan_x_top/titan_x_top.v`, `memory/l2_cache_top/l2_cache_top.v`
- **Observed Behavior:** In `titan_x_top.v`, `u_l2_cache` is instantiated with only `.clk(clk)` and `.rst_n(rst_n)` connected. None of the memory request/response buses, tag arrays, or data lines connect to the crossbar, cores, or DDR controller.
- **Expected Behavior:** L2 cache arrays properly parameterized and integrated into the primary memory transaction path between crossbar slaves and memory controllers.
- **Root Cause:** Modular IP block was parameterized and validated standalone, but top-level memory bus stitching was omitted in `titan_x_top.v`.
- **Correction Applied:**
  * In `memory/l2_cache_top/l2_cache_top.v`: aligned `SETS = 64` with `IDX_W = 6`, wired internal controller-to-array buses (`ctrl_dat_*`).
  * Validated standalone cache behavior with unit testbench `tb_l2_cache_top.v`.
  * Top-level bus connections remain unstitched in `titan_x_top.v`.
- **Targeted Tests:** `tb_l2_cache_top.v`.
- **Evidence:** `tb_l2_cache_top.v` PASS; structural audit identifies isolated ports in `titan_x_top.v`.
- **Status:** `PARTIALLY VERIFIED`

### FIND-TOP-02: Cache Coherence and Multicore Behavior
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `memory/l2_snoop_filter/l2_snoop_filter.v`, `top/titan_x_top/titan_x_top.v`
- **Observed Behavior:** In `titan_x_top.v`, core snoop ports are tied off (`.snoop_valid(1'b0)`, `.snoop_addr(40'h0)`). Inside `rv_core_top.v`, snoop outputs are tied off (`assign snoop_ack = 1'b0; assign snoop_data_valid = 1'b0; assign snoop_data = 512'h0;`). `l2_snoop_filter` is not instantiated in `titan_x_top.v`. Neither L1 icache nor dcache are instantiated inside `rv_core_top`.
- **Expected Behavior:** Active hardware cache coherency interconnect snooping across core L1 caches and an integrated directory filter.
- **Root Cause:** Full cache coherency infrastructure exists only as standalone modular IP blocks (`l2_snoop_filter.v`, `rv_dcache.v`) and was not integrated into top-level SoC fabric.
- **Correction Applied:**
  * Proved MESI state machine invariants formally on the standalone `l2_snoop_filter.v` module (`FORMAL-03`).
  * Documented absence of hardware cache coherence at top level; multicore communication relies on uncached/direct crossbar physical memory accesses.
- **Targeted Tests:** `FORMAL-03`, `tb_l2_snoop_filter.v`.
- **Evidence:** `FORMAL-03` proves standalone IP; structural audit confirms zero top-level coherence integration.
- **Status:** `OPEN`

### FIND-SEC-01: Secure Boot and Cryptographic Integration
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `security/secure_boot/secure_boot.v`, `top/titan_x_top/titan_x_top.v`
- **Observed Behavior:** Legacy `secure_boot.v` had mock authentication (`ecdsa_valid <= 1'b1`) and `titan_x_top.v` drove constant zeros to `trng_seed` and `envm_rdata`.
- **Expected Behavior:** Hardware verification of firmware header magic, image length, authenticated public key ID, cryptographic hash over payload, timeout handling, and gated core reset release.
- **Root Cause:** Behavioral test mocks left in synthesizable RTL tree.
- **Correction Applied:**
  * Rewrote `security/secure_boot/secure_boot.v` with genuine magic check (`32'h5449544E`), public key check (`32'hCAFE_F00D`), rolling hash digest computation over image payload words, memory read timeout counter, and gated reset control (`boot_pass`/`boot_fail`).
  * Connected authentic signed image descriptor to eNVM bus in `titan_x_top.v` and `tb_integ_security_chain.v`.
  * Verified 5 security scenarios in `tb_secure_boot.v` (authentic pass, payload tampering fail, zero-seed fail, public key mismatch fail, memory hang fail).
  * Note: Dedicated asymmetric ECDSA P-256 curve engine and physical TRNG entropy accelerator remain standalone behavioral models.
- **Targeted Tests:** `tb_secure_boot.v`, `tb_integ_security_chain.v`.
- **Evidence:** `tb_secure_boot.v` (5/5 scenarios PASS), `tb_integ_security_chain.v` PASS.
- **Status:** `PARTIALLY VERIFIED`

### FIND-CORE-01: Processor Datapath, ISA and Pipeline Claims
- **Severity / Priority:** CRITICAL / P0
- **Source Reference:** `backend/rv_core_top/rv_core_top.v`, `README.md`, `ARCHITECTURE_HANDBOOK.md`
- **Observed Behavior:** Historical marketing literature advertised an 8-stage dual-issue superscalar RV64GC core.
- **Expected Behavior:** Truthful documentation reflecting the genuine 5-stage in-order single-issue RV64IM processor core operating in Machine-mode with direct physical addressing.
- **Root Cause:** Documentation drift from RTL implementation.
- **Correction Applied:**
  * Verified pipeline stages (IF, ID, EX, MEM, WB) and native RV64IM ISA in `rv_core_top.v`.
  * Synchronized all architectural specifications, test generators, and documentation.
- **Targeted Tests:** `tb_rv_core_top.v`, `tb_rv_core_compliance.v`, `tb_rv_core_mext.v`, `tb_rv_core_wops.v`.
- **Evidence:** All core regression testbenches pass cleanly (100%).
- **Status:** `VERIFIED`

### FIND-CORE-02: Exceptions, Traps and MRET Privileged Architecture
- **Severity / Priority:** CRITICAL / P0
- **Source Reference:** `backend/rv_csr/rv_csr.v`, `backend/rv_csr/tb_rv_csr.v`
- **Observed Behavior:** `mstatus.MPP` reset to `2'b00` (User mode), and illegal CSR writes could clear `MPP` in a Machine-mode-only processor.
- **Expected Behavior:** In an M-mode exclusive core, `mstatus.MPP = 2'b11` is an invariant preserved across reset (`mstatus = 0x1800`), CSR writes, and trap return (MRET).
- **Root Cause:** Omission of M-mode hardwiring in CSR reset and write decode.
- **Correction Applied:**
  * In `rv_csr.v`: enforced `mstatus_q <= 64'h0000_0000_0000_1800` on reset; preserved `mstatus_q[12:11] <= 2'b11` on CSR writes.
  * Enforced 4-byte trap alignment on `mtvec_out`.
  * Updated test vectors via `scripts/gen_csr_test.py` and `scripts/gen_irq_test.py`.
- **Targeted Tests:** `tb_rv_csr.v`, `tb_fresh_rv_csr.v`, `tb_rv_core_csr.v`, `tb_rv_core_irq.v`, `MUT-04`.
- **Evidence:** `tb_rv_core_csr.v` and `tb_rv_core_irq.v` pass 100%; `MUT-04` killed.
- **Status:** `VERIFIED`

### FIND-CORE-03: Floating-Point Unit Integration and FMINMAX
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `backend/rv_fpu/rv_fpu.v`, `backend/rv_fpu/tb_fresh_rv_fpu.v`
- **Observed Behavior:** Stage-3 FMIN/FMAX calculation used unregistered inputs and lacked IEEE 754 NaN boxing/propagation.
- **Expected Behavior:** Registered operands in stage 3, single-precision NaN-boxing (`{32'hFFFF_FFFF, sp_minmax}`), canonical NaN propagation.
- **Root Cause:** Incomplete pipeline register assignment in FMIN/FMAX calculation path.
- **Correction Applied:**
  * Updated `rv_fpu.v` with registered stage-3 operands, NaN boxing, and IEEE 754 propagation.
  * Verified unit tests T9a/T9b in `tb_fresh_rv_fpu.v`.
- **Targeted Tests:** `tb_fresh_rv_fpu.v`, `tb_rv_fpu.v`, `MUT-06`.
- **Evidence:** `tb_fresh_rv_fpu.v` 14/14 tests pass; `MUT-06` killed.
- **Status:** `VERIFIED`

### FIND-MEM-01: MMU, TLB and PTW Integration
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `backend/rv_mmu/`, `backend/rv_tlb/`, `backend/rv_ptw/`, `backend/rv_pmp/`
- **Observed Behavior:** Core pipeline operates with physical addressing directly to memory buses, while MMU/TLB/PTW/PMP exist as modular standalone blocks.
- **Expected Behavior:** Truthfully document native physical memory addressing at the core pipeline level and qualify MMU/TLB/PTW/PMP as verified standalone IP blocks.
- **Root Cause:** Architectural partition between embedded in-order spine and optional virtual memory translation wrappers.
- **Correction Applied:**
  * Verified MMU, TLB, PTW, and PMP with dedicated unit testbenches.
  * Documented physical addressing reality in `ARCHITECTURE_HANDBOOK.md` and `STRUCTURAL_AUDIT_REPORT.md`.
- **Targeted Tests:** `tb_fresh_rv_mmu.v`, `tb_fresh_rv_tlb.v`, `tb_fresh_rv_ptw.v`, `tb_fresh_rv_pmp.v`.
- **Evidence:** All 4 memory management testbenches pass 100%.
- **Status:** `PARTIALLY VERIFIED`

### FIND-PERIPH-01: Interrupt Controller and Peripheral Bus
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `top/titan_x_top/titan_x_top.v`, `backend/plic/plic.v`, `backend/clint/clint.v`
- **Observed Behavior:** PLIC APB slave interface was connected to APB decoder, but CLINT is not instantiated at top level (`sw_irq` tied to 0, timer taken from RTC).
- **Expected Behavior:** Complete integration of both PLIC (external interrupts) and CLINT (software and timer interrupts).
- **Root Cause:** CLINT omitted from top-level instantiation.
- **Correction Applied:**
  * Connected `u_plic` APB interface to APB decoder for external interrupt routing (`irq_m_ext`).
  * CLINT remains uninstantiated at top-level.
- **Targeted Tests:** `tb_plic.v`, `tb_fresh_plic.v`, `tb_clint.v`, `tb_integ_peripheral_bus.v`.
- **Evidence:** All interrupt and bus testbenches pass cleanly.
- **Status:** `PARTIALLY VERIFIED`

### FIND-VIDEO-01: Camera, ISP, DMA, Framebuffer and HDMI
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `video/mipi_csi2_rx/`, `video/isp_pipeline/`, `video/vdma/`, `video/hdmi_ctrl/`
- **Observed Behavior:** Video pipeline modules exist and pass unit tests, but top-level physical streaming transceivers are stubbed.
- **Expected Behavior:** Functional unit verification of modular streaming video IP blocks.
- **Root Cause:** Standalone streaming architecture without physical off-chip HDMI/camera transceivers.
- **Correction Applied:**
  * Verified all video IP blocks with dedicated unit testbenches.
  * Classified subsystem as modular verified IP cores.
- **Targeted Tests:** `tb_mipi_csi2_rx.v`, `tb_isp_pipeline.v`, `tb_vdma.v`, `tb_hdmi_ctrl.v`, `tb_integ_video_pipeline.v`.
- **Evidence:** All 5 video testbenches pass cleanly.
- **Status:** `PARTIALLY VERIFIED`

### FIND-IO-01: Ethernet, PCIe and USB High-Speed Interfaces
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `top/titan_x_top/titan_x_top.v`, `peripherals/pcie_top/`, `peripherals/gem_ethernet/`
- **Observed Behavior:** Controller logic compiles and passes with protocol BFMs, but multi-gigabit SERDES PHY transceivers are behavioral stubs.
- **Expected Behavior:** High-speed protocol controller verification via simulation BFMs.
- **Root Cause:** Absence of physical transceiver silicon macros.
- **Correction Applied:**
  * Widened PIPE RX tie-offs to 4 lanes in `titan_x_top.v`; aligned AXI-to-AHB data widths.
  * Verified controllers with protocol BFMs (`tb_bfm_pcie.v`, `tb_bfm_gmii.v`, etc.).
- **Targeted Tests:** `tb_gem_ethernet.v`, `tb_bfm_pcie.v`, `tb_pcie_top.v`, `tb_usb_otg.v`, `tb_bfm_gmii.v`.
- **Evidence:** All IO controller testbenches pass cleanly.
- **Status:** `PARTIALLY VERIFIED`

### FIND-BUS-01: AXI Crossbar, Address Map and Bus Adapters
- **Severity / Priority:** MEDIUM / P2
- **Source Reference:** `interconnect/axi4_crossbar/axi4_crossbar.v`, `tb_axi4_crossbar.v`
- **Observed Behavior:** 40-bit address constants in `tb_axi4_crossbar.v` had 12 hex digits (48 bits); Unicode arrow caused subprocess pipe truncation.
- **Expected Behavior:** Correct constant widths and ASCII clean logging; DECERR response on unmapped addresses without deadlock.
- **Root Cause:** Formatting errors in testbench address constants and print statements.
- **Correction Applied:**
  * Corrected 40-bit address constants to `40'h00_8000_0000`.
  * Replaced Unicode arrows with ASCII `->`.
  * Proved crossbar arbitration and mutual exclusion via Yosys + Z3 BMC (`FORMAL-04`).
- **Targeted Tests:** `tb_axi4_crossbar.v`, `tb_integ_xbar_concurrency.v`, `FORMAL-04`.
- **Evidence:** `tb_axi4_crossbar.v` PASS; `FORMAL-04` BMC PASS.
- **Status:** `VERIFIED`

---

## 2. Regression & Test Integrity Findings

### FIND-REG-01: Regression Runner Correctness
- **Severity / Priority:** CRITICAL / P0
- **Source Reference:** `scripts/run_regress.py`
- **Observed Behavior:** Loose globbing pattern previously captured legacy files; runner lacked explicit `-s <top_module>` targeting and full raw log file capture.
- **Expected Behavior:** Runner compiles strictly canonical files from `soc_filelist.f`, targets explicit `-s <top_module>`, writes raw simulation logs to an evidence directory, enforces that non-zero exit codes unconditionally verdict `CRASHED`, and provides adversarial self-tests.
- **Root Cause:** Incomplete compilation flags and missing raw log directory handling.
- **Correction Applied:**
  * Added explicit `-s name` to `iverilog` command line.
  * Saved full raw logs to `artifacts/qualification/logs/{name}.log`.
  * Hardened `judge_verdict` and added 12 adversarial runner test cases (`--adversarial` / `--self-test`).
- **Targeted Tests:** `python3 scripts/run_regress.py --adversarial`.
- **Evidence:** 12/12 adversarial tests PASS; full regression 109/109 PASS (100.0%).
- **Status:** `VERIFIED`

### FIND-REG-02: Forensic Investigation of the 12 Suspicious X-Data Tests
- **Severity / Priority:** HIGH / P1
- **Source Reference:** 12 testbenches flagged in prior audits
- **Observed Behavior:** Runner regex `[01]*x[01]*x` matched hex formatting `0x` and `.hex` filenames in simulation logs.
- **Expected Behavior:** Eliminate detector false positives while retaining strict detection of genuine Verilog uninitialized X states.
- **Root Cause:** Regex over-matching on standard hexadecimal output formatting.
- **Correction Applied:** Refined `XPAT_RE` in `scripts/run_regress.py` to require base literal indicators (`'h`, `'b`) and ignore hex prefixes. Re-ran all 12 testbenches individually.
- **Targeted Tests:** Individual execution of all 12 testbenches.
- **Evidence:** All 12 testbenches pass cleanly without true unknown X states.
- **Status:** `VERIFIED`

---

## 3. Formal, Mutation, Synthesis & Documentation Findings

### FIND-FORMAL-01: Formal Verification Quality
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `formal/sva/`, `formal/proofs/`, `scripts/run_formal.py`
- **Observed Behavior:** Formal proofs required reproducible automation and explicit bounded horizon disclosures.
- **Expected Behavior:** Automated BMC proof suite with Yosys SMT-BMC and Z3, with bounded step depths clearly declared.
- **Root Cause:** Lack of automated runner and explicit horizon reporting.
- **Correction Applied:** Created `scripts/run_formal.py` executing 4 BMC proofs (depths 20, 20, 20, 5) with full logging.
- **Targeted Tests:** `python3 scripts/run_formal.py`.
- **Evidence:** `docs/qualification/FORMAL_VERIFICATION_REPORT.md` (4/4 proofs passed, 100.0%).
- **Status:** `VERIFIED`

### FIND-MUT-01: Mutation Testing & Test Sensitivity
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `scripts/run_mutations.py`
- **Observed Behavior:** Need for automated architectural defect injection to verify testbench sensitivity.
- **Expected Behavior:** Automated mutation suite injecting faults into verified RTL to demonstrate test sensitivity.
- **Root Cause:** No mutation infrastructure existed in the baseline.
- **Correction Applied:** Created `scripts/run_mutations.py` injecting 6 representative faults; all 6 killed.
- **Targeted Tests:** `python3 scripts/run_mutations.py`.
- **Evidence:** `docs/qualification/MUTATION_TESTING_REPORT.md` (6/6 mutants killed, 100.0% sensitivity).
- **Status:** `VERIFIED`

### FIND-SYN-01: Synthesis & Gate Count Reconciliation
- **Severity / Priority:** MEDIUM / P2
- **Source Reference:** `synth_rv_core_direct.tcl`, `docs/qualification/SYNTHESIS_REPORT.md`
- **Observed Behavior:** Discrepancies between historical marketing numbers and open-source generic synthesis.
- **Expected Behavior:** Reproducible Yosys generic synthesis producing verified cell count and breakdown.
- **Root Cause:** Conflation of generic unmapped cells with standard-cell ASIC areas.
- **Correction Applied:** Executed `synth_rv_core_direct.tcl` on `rv_core_top` using Yosys 0.33, producing exactly 79,560 generic cells (4,005 DFFs, 75,555 logic gates) with zero unresolved blackboxes.
- **Targeted Tests:** `yosys -s synth_rv_core_direct.tcl`.
- **Evidence:** `docs/qualification/SYNTHESIS_REPORT.md`.
- **Status:** `VERIFIED`

### FIND-DOC-01: Documentation Harmonization & Gate H Compliance
- **Severity / Priority:** HIGH / P1
- **Source Reference:** `README.md`, `docs/architecture/ARCHITECTURE_HANDBOOK.md`
- **Observed Behavior:** Historical documents contained contradictory claims (RV64GC vs RV64IM, premature tape-out claims).
- **Expected Behavior:** Accurate architecture descriptions, synchronized module/test counts, removal of false tape-out claims, and prominent Gate H qualification notices.
- **Root Cause:** Documentation was not kept in sync with RTL changes.
- **Correction Applied:** Synchronized documentation across repository; removed all false tape-out claims.
- **Targeted Tests:** End-to-end documentation audit.
- **Evidence:** Synchronized documentation suite in target repository.
- **Status:** `VERIFIED`
