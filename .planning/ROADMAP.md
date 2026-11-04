# Roadmap: SMVDU TITAN-X SoC Verification

## Milestones
- **M1: Foundation & Leaf Standard Cells (Phase 1)**
- **M2: CPU Core Subsystem Verification (Phases 2 - 6)**
- **M3: Coherent Memory & Interconnect Fabric (Phases 7 - 8)**
- **M4: Industrial Peripherals, Security & Storage (Phases 9 - 11)**
- **M5: Multimedia Vision Pipeline (Phase 12)**
- **M6: Full SoC Integration, Firmware Bring-Up & Linux Readiness (Phase 13)**

---

## Phase Details

### Phase 1: Foundation & Common Standard Cell Modules (6 Modules)
- **Scope:** `stdcell_stubs`, `buf_macros` (`BUFX4`), `reset_sync`, `cdc_sync`, `fifo_sync`, `fifo_async`.
- **Goals:** Verify clock domain crossings, Gray pointer async FIFO under extreme clock phase skews, sync FIFO full/empty boundaries, reset deassertion synchronizer, and high-drive buffer propagation.
- **Exit Criteria:** 100% assertions pass, zero metastability hazards, waveforms generated, READMEs updated.

### Phase 2: CPU Frontend & Branch Prediction Subsystem (4 Modules)
- **Scope:** `rv_bpu`, `rv_icache`, `rv_fetch`, `rv_decode`.
- **Goals:** Verify Gshare BHT/GHR saturating counters, RAS push/pop recursion, VIPT I-Cache SECDED ECC single-bit correction and multi-bit detection, AXI-Lite 8-beat line refills, PC increment/redirect drain FSM, and full instruction immediate/control decoding.
- **Exit Criteria:** Full decode coverage across RV64GC instructions, BPU accuracy validation, zero stale instruction leaks on branch mispredictions.

### Phase 3: CPU Backend Arithmetic, Registers & Floating-Point Unit (6 Modules)
- **Scope:** `rv_regfile`, `rv_csr`, `rv_execute`, `rv_mem`, `rv_writeback`, `rv_fpu`.
- **Goals:** Verify 64-bit ALU operations, Radix-4 3-cycle multiplier, 64-cycle restoring divider stalls, operand forwarding muxes (MEM➔EX, WB➔EX, WB➔DE), load sign/zero-extensions, store byte-lane enables, CSR trap vectoring, GPR dual-read/single-write (`x0=0`), and IEEE 754 double/single-precision FPU operations (FMADD, FSQRT, conversions).
- **Exit Criteria:** 100% arithmetic accuracy against reference C models, zero pipeline RAW hazard stalls with forwarding.

### Phase 4: CPU Virtual Memory, MMU, TLB, Page Table Walker & PMP (4 Modules)
- **Scope:** `rv_tlb`, `rv_ptw`, `rv_pmp`, `rv_mmu`.
- **Goals:** Verify 64-entry fully-associative TLB ASID filtering, `SFENCE.VMA` line and global invalidations, 3-level hardware Page Table Walk (L2➔L1➔L0) for 4KB, 2MB, and 1GB pages, 16 PMP regions across TOR/NAPOT/NA4 modes in Machine, Supervisor, and User modes.
- **Exit Criteria:** Autonomous PTW refill with zero software intervention, 100% access fault detection on unauthorized accesses.

### Phase 5: Interrupt Architecture, Debug & Security Monitor Subsystem (4 Modules)
- **Scope:** `clint`, `plic`, `rv_debug`, `rv_monitor_core`.
- **Goals:** Verify CLINT 64-bit `mtime` timer comparisons and `msip` software IPIs, PLIC 186-source prioritization and atomic Claim/Complete handshakes across 10 contexts, JTAG DTM TAP FSM and DM run-control registers (halt, resume, single-step), and monitor core telemetry logging.
- **Exit Criteria:** Zero race conditions during concurrent interrupt claims, cycle-accurate debug halting and register inspection.

### Phase 6: Single-Core Full Pipeline Integration & Compliance Suite (Core Top Integration)
- **Scope:** `rv_core_top` executing base RV64I, RISC-V Compliance suite, CSR suite, IRQ handling suite, M-extension suite, and Word Operations suite.
- **Goals:** Run 30 memory test vectors and verify architectural registers, memory addresses, and data against golden `.mem` traces.
- **Exit Criteria:** 100% pass across all 6 test suites, zero register state mismatches.

### Phase 7: Coherent Memory Subsystem & DDR4 SDRAM Controller (10 Modules)
- **Scope:** `sram_32x64_180nm`, `sram_512kx8_180nm`, `l2_tag_array`, `l2_data_array`, `l2_snoop_filter`, `l2_cache_ctrl`, `l2_cache_top`, `ddr_scheduler`, `ddr_phy_if`, `ddr_ctrl_top`.
- **Goals:** Verify 2MB L2 cache hit/miss FSM, 4-bank SRAM interleaving, MOESI/MESI snoop directory tracking and dirty writebacks, DDR4 command scheduler 8-bank state machines ($t_{RCD}$, $t_{RP}$, $t_{RAS}$), and DFI 4.0 PHY leveling.
- **Exit Criteria:** Complete multi-core memory coherence without data corruption under concurrent load/store thrashing.

### Phase 8: Interconnect Fabric, Bridges & Traffic Arbiters (8 Modules)
- **Scope:** `axi4_burst_to_lite`, `mpu`, `mmu_arbiter`, `qos_controller`, `ahb_to_apb`, `apb_bridge`, `axi4_to_ahb`, `axi4_crossbar`.
- **Goals:** Verify 15M×9S concurrent crossbar routing without deadlock, burst-to-lite fragmentation, MPU DECERR firewalls, QoS bandwidth throttling on DMA streams, and two-stage AXI4➔AHB➔APB bridge latency.
- **Exit Criteria:** Zero deadlock under all 15 masters competing, accurate peripheral decoding across all 17 APB addresses.

### Phase 9: Industrial Peripherals & Serial Communication (7 Modules)
- **Scope:** `gpio_ctrl`, `rtc`, `watchdog_timer`, `uart_16550`, `spi_master`, `i2c_master`, `can_controller`.
- **Goals:** Verify 5× UART TX/RX FIFOs and baud divisors, SPI Modes 0–3, I2C 100k/400k bit timings, 32-bit GPIO edge/level interrupts, windowed watchdog lock keys and reset triggers, and CAN 2.0B message filtering.
- **Exit Criteria:** 100% loopback and frame transmission validation across all peripheral interfaces.

### Phase 10: Hardware Security, Cryptography & Root-of-Trust (4 Modules)
- **Scope:** `trng`, `drbg`, `sha256_engine`, `aes_engine`, `ecdsa_engine`, `envm_ctrl`, `secure_boot`.
- **Goals:** Verify TRNG ring-oscillator entropy debiasing, CTR-DRBG NIST SP 800-90A test vectors, AES-128/192/256 cipher modes, SHA-256 64-round compression, ECDSA P-256 point multiplication, and Secure Boot image verification gating `core_rst_n`.
- **Exit Criteria:** 100% cryptographic test vector compliance against NIST CAVP golden vectors, tamper containment verified.

### Phase 11: High-Speed Storage & Communication DMA Subsystem (5 Modules)
- **Scope:** `gem_sgmii_pcs`, `gem_ethernet`, `pcie_pipe_if`, `pcie_top`, `usb_otg`, `mmc_controller`, `qspi_controller`.
- **Goals:** Verify Gigabit Ethernet scatter-gather DMA descriptor parsing, PCIe Gen2 x1 TLP processing, USB 2.0 OTG endpoint transfers, eMMC HS200/HS400 DMA blocks, and QSPI XIP cache fetches.
- **Exit Criteria:** Full DMA packet throughput without memory buffer overflows or descriptor corruption.

### Phase 12: High-Definition Video & Vision Pipeline (4 Modules)
- **Scope:** `mipi_csi2_rx`, `isp_pipeline`, `vdma`, `hdmi_ctrl`.
- **Goals:** Verify 4-lane MIPI D-PHY deserialization, ISP Bayer CFA demosaicing, auto white-balance, gamma LUT, VDMA triple-buffered framebuffer swapping in DDR4, and HDMI 1.4 TMDS 8b/10b 1080p60 serialization.
- **Exit Criteria:** End-to-end pixel flow from MIPI packet input to TMDS differential output without dropped frames.

### Phase 13: Full SoC Integration, Firmware Bring-Up & End-to-End System Boot (2 Modules + Top)
- **Scope:** `axi_rom`, `titan_x_top`, firmware execution (`firmware/main.c`), peripheral bring-up, DDR4 memory test, interrupt servicing.
- **Goals:** Full SoC power-on reset ➔ Secure Boot SHA-256 check ➔ `core_rst_n` release ➔ Boot ROM execution ➔ Stack setup ➔ UART boot banner transmission ➔ DDR4 memory diagnostics ➔ Multi-core OS boot simulation.
- **Exit Criteria:** 100% clean SoC simulation, zero protocol violations, all 71 modules working in seamless harmony.

---

## Milestone M7: Master Engineering Remediation, Integration & Qualification (Phases 14 - 22)

### Phase 14: Architectural Discovery, Hardware Hierarchy & Machine-Readable Connectivity Matrix
- **Scope:** Complete repository audit, `top/titan_x_top/titan_x_top.v`, `docs/qualification/STRUCTURAL_AUDIT_REPORT.md`.
- **Goals:** Generate automated module-instantiation tree from `titan_x_top` down to leaf primitives; produce complete machine-readable connectivity matrix (`CONNECTIVITY_MATRIX.json`); inventory all 20 uninstantiated repo modules vs active top-level modules; definitively document processor pipeline reality (5-stage in-order RV64IM in Machine-mode with direct physical memory addressing).
- **Exit Criteria:** Complete structural audit and connectivity matrix committing 0 unsupported claims.

### Phase 15: Processor Core Execution, Exception Handling & Privileged Architecture
- **Scope:** `backend/rv_core_top/rv_core_top.v`, `backend/rv_csr/rv_csr.v`, `backend/rv_execute/rv_execute.v`, `frontend/rv_decode/rv_decode.v`.
- **Goals:** Eliminate hardwired `exception = 1'b0`; implement end-to-end exception detection unit (illegal instruction, misaligned fetch/load/store, instruction/data access faults); wire exception unit to CSR trap sequencer; implement trap entry and MRET sequencing (`mtvec`, `mepc`, `mcause`, `mtval`, `mstatus`); enforce `mstatus.MPP = 2'b11` invariant; verify pipeline forwarding, hazard stalls, and flush control.
- **Exit Criteria:** 100% compliance on architectural exception and trap tests; zero unhandled fault traps.

### Phase 16: Top-Level L1/L2 Cache Hierarchy & Memory Bus Integration
- **Scope:** `frontend/rv_icache/`, `backend/rv_dcache/`, `memory/l2_cache_top/`, `memory/l2_cache_ctrl/`, `top/titan_x_top/`.
- **Goals:** Integrate L1 instruction cache (`rv_icache`) and L1 data cache (`rv_dcache`) into the processor core memory interface; stitch shared L2 cache (`l2_cache_top`) into the primary system bus between AXI crossbar Slave 0 and `ddr_ctrl_top` (wiring request/response handshakes, miss refill, dirty eviction, and tag/data arrays); eliminate isolated clock/reset tie-offs.
- **Exit Criteria:** L1 and L2 caches actively process transactions with verified hit/miss/eviction dynamics.

### Phase 17: Multicore Snooping, Coherence Protocol & Shared-Memory Integration
- **Scope:** `memory/l2_snoop_filter/`, `backend/rv_core_top/`, `top/titan_x_top/`, `integration/`.
- **Goals:** Instantiate and connect `l2_snoop_filter` at top-level; wire core snoop ports (`snoop_valid`, `snoop_addr`, `snoop_type`, `snoop_ack`, `snoop_data`); implement and verify coherence state machine transitions; build integrated multicore shared-memory testbench (`tb_multicore_coherence.v`) verifying dirty evictions, write-read visibility, and snoop invalidations across cores.
- **Exit Criteria:** Multi-core concurrent shared-memory cache coherency proven in simulation and formal SVA.

### Phase 18: Cryptographic Root of Trust, Secure Boot Chain & Key Management
- **Scope:** `security/secure_boot/`, `peripherals/sha256_engine/`, `security/ecdsa_engine/`, `peripherals/trng/`, `top/titan_x_top/`.
- **Goals:** Integrate standard NIST SHA-256 hardware acceleration and ECDSA P-256 digital signature verification into `secure_boot.v`; implement authenticated public key storage, firmware header validation, and timeout handling; connect real entropy interface for TRNG / DRBG; positive, negative, tampered, truncated, and timeout testbenches gating `core_rst_n`.
- **Exit Criteria:** Boot controller reliably prevents application processor execution prior to cryptographic authentication.

### Phase 19: Interconnect Fabric, Crossbar Addressing & Traffic Arbitration
- **Scope:** `interconnect/axi4_crossbar/`, `interconnect/interconnect_mpu/`, `interconnect/mmu_arbiter/`, `interconnect/qos_controller/`.
- **Goals:** Establish definitive crossbar master/slave port map (active vs unused); integrate MPU memory protection firewall and QoS rate limiter into active data flow; verify starvation freedom, arbitration fairness, backpressure, and unmapped DECERR responses under concurrent multi-master traffic.
- **Exit Criteria:** Zero deadlocks under heavy concurrent multi-master traffic; complete address decoding verified.

### Phase 20: Interrupts, Timers, JTAG Debug & Peripheral Subsystem Integration
- **Scope:** `backend/clint/`, `backend/plic/`, `backend/rv_debug/`, `peripherals/`, `top/titan_x_top/`.
- **Goals:** Integrate CLINT at top level for software IPI interrupts (`sw_irq`) and `mtime`/`mtimecmp` timer interrupts; connect JTAG debug module (`rv_debug`) `halt_req`/`resume_req`/run-control registers; audit external PHY interfaces (GMII, PIPE, ULPI) and connect with realistic BFMs; integrate video streaming pipeline (MIPI CSI-2, ISP, VDMA, HDMI).
- **Exit Criteria:** Complete interrupt servicing, cycle-accurate debug halting, and operational peripheral dataflows.

### Phase 21: Layered Verification Framework (Levels 1–8), Fuzzing & Regression Runner
- **Scope:** `scripts/run_regress.py`, `formal/`, `scripts/run_formal.py`, `scripts/run_mutations.py`.
- **Goals:** 8-level verification framework (Static lint, module unit tests, subsystem integration, RISC-V compliance, full SoC boot, constrained-random stress testing, SVA BMC/induction formal proofs, mutation testing); strict runner exit code and raw log preservation.
- **Exit Criteria:** 100% truthful pass rate across all verification tiers; zero hidden failures.

### Phase 22: Synthesis Accounting, Formal SVA Proofs & Physical Design Readiness Assessment
- **Scope:** `synth_rv_core_direct.tcl`, `scripts/run_synth.py`, `docs/qualification/`.
- **Goals:** Reproducible Yosys generic and mapped synthesis flows; formal proof reports with bounded horizon and scope declarations; physical design readiness gap analysis (SDC constraints, foundry SRAM macros, CTS/UPF, IO pad ring); final Master Findings Ledger reconciliation and clean-clone gate verification.
- **Exit Criteria:** Complete agreement between RTL, architecture documentation, synthesis metrics, and qualification evidence.
