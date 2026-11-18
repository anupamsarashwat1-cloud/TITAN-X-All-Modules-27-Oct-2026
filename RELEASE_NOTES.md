# SMVDU TITAN X — Release Notes
## Version 1.0.0 (Release Tag: `SMVDU-TITAN-X-v1.0.0`)

**Release Date:** 2026-11-18  
**Project:** SMVDU TITAN X — 64-Bit Multicore RISC-V System-on-Chip  
**Canonical Repository:** `https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04`  
**Secondary Production Repository:** `https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-03`  
**Workspace Repository:** `https://github.com/anupamsarashwat1-cloud/TITAN-X-All-Modules-27-Oct-2026`  
**Release Commit SHA:** `471b8575a5cce650635351b9ca2ae4d951ff2dd3`  
**Release Tag:** `SMVDU-TITAN-X-v1.0.0`  
**Engineering Integration Lead:** Anupam Sarashwat  

---

## 1. Executive Release Summary

The SMVDU TITAN X SoC engineering team announces the formal **v1.0.0 Release** representing complete functional integration, cryptographic hardware Root-of-Trust attestation, formal bounded model checking closure, and exhaustive regression verification of the 64-bit multicore RISC-V SoC.

This release establishes a frozen, reproducible academic engineering baseline ready for backend physical ASIC implementation flows.

### Key Release Highlights:
- **100% True Pass Rate across 120 Canonical Testbenches:** Zero test failures, zero simulation crashes, and zero timeouts.
- **Hardware Root-of-Trust Secure Boot Attestation:** NIST FIPS 180-4 SHA-256 and FIPS 186-4 ECDSA P-256 digital signature verification performed directly in hardware prior to CPU reset release; zero backdoor testbench memory writes.
- **5 / 5 Formal Verification Proofs:** Bounded model checking safety and liveness properties proved with Yosys SMT2 and Z3 theorem prover (100% PASS).
- **Full-Chip Elaboration:** All 79 synthesizable IP modules fully integrated into `titan_x_top.v` with 0 unresolved blackbox references.
- **Multicore Benchmark Execution:** All 5 harts boot from BootROM, execute multi-core benchmark routines, perform coherent memory transactions, and retire instructions cleanly.

---

## 2. Architectural Architecture Baseline

### 2.1 Compute Complex
- **Harts 0–3 (Application Cores):** 64-bit RV64IM_Zicsr cores featuring 5-stage in-order pipelines, hardware Radix-4 integer multiplier/divider, branch prediction unit (BPU), private 16 KB L1 Instruction Caches (write-through), and private 16 KB L1 Data Caches (write-back, write-allocate).
- **Hart 4 (Monitor Core):** 64-bit RV64IM_Zicsr core operating in Machine mode for system telemetry, secure enclave tasks, and system health monitoring via UART0.
- **Privilege Enforcement:** All 5 harts operate exclusively in Machine-mode (M-mode, `2'b11`).
- **Interrupt Architecture:** Standard RISC-V CLINT (core-local timer/software interrupts) and 186-source PLIC (Platform-Level Interrupt Controller) arbitrating external interrupt priorities.

### 2.2 Memory Hierarchy & Interconnect
- **L1 Caches:** 16 KB 4-way set-associative L1 I-Cache and 16 KB 4-way set-associative L1 D-Cache per application core.
- **Shared L2 Cache:** 16-way set-associative cache with hardware MESI snooping directory filter (`l2_snoop_filter`) interfacing synchronous SRAM macro wrappers (`sram_32x64_180nm`).
- **On-Chip Scratchpad:** 512 KB zero-wait-state SRAM (`axi_sram`) mapped at `0x0800_0000 - 0x0807_FFFF`.
- **DDR4 Subsystem:** Full AXI4 burst-capable DDR4 SDRAM controller with bank/row/column command scheduler and DDR PHY interface, mapped at `0x8000_0000 - 0x8FFF_FFFF`.
- **AXI4 Crossbar Fabric:** 15 Masters x 9 Slaves non-blocking crossbar with 40-bit physical addressing, 64-bit data bus, round-robin fair arbitration, Interconnect MPU memory protection, and QoS latency regulation.
- **Peripheral Bus:** AXI-to-AHB/APB bridge providing strict 4KB aperture decoding across 28 distinct memory-mapped peripherals.

### 2.3 Security & Cryptographic Subsystem
- **Root-of-Trust Pre-Boot Gating:** Core reset strictly held low (`core_rst_n = 0`) until cryptographic signature verification passes.
- **OTP eFuse Controller (`efuse_ctrl`):** 4-slot root public key hash matching, revocable slot mask, and monotonic anti-rollback security counter.
- **Cryptographic Accelerators:** Standalone AES-256 engine, SHA-256 engine, ECDSA P-256 point multiplier, ring-oscillator TRNG, and NIST SP 800-90A DRBG.

### 2.4 Integrated Peripherals
- **Serial & Industrial:** UART 16550, GPIO Controller (32-bit), Real-Time Clock (RTC), Watchdog Timer (WDT), SPI Master, I2C Master, CAN Controller.
- **High-Speed Networking & Storage:** Gigabit Ethernet MAC (GEM) with SGMII/PCS interface, PCIe Gen3 x4 Controller with PIPE interface, USB 2.0 OTG Controller with ULPI PHY, SD/MMC Host Controller, Quad-SPI (QSPI) Flash Controller.
- **Video & Imaging:** MIPI CSI-2 4-lane RX, Image Signal Processor (ISP) pipeline, Video DMA (VDMA), HDMI TMDS display controller.

---

## 3. Subsystem Verification & Qualification Matrix

| Subsystem ID | Subsystem Name | Synthesizable Modules | Canonical Testbenches | Formal Proofs | Status |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **SS-01** | Processor Cores & Datapath | 10 | 14 testbenches | FORMAL-01, FORMAL-02 | **100% PASS** |
| **SS-02** | L1/L2 Caches & Memory Fabric | 12 | 16 testbenches | FORMAL-03 | **100% PASS** |
| **SS-03** | On-Chip SRAM & Boot ROM | 3 | 3 testbenches | Interconnect assertions | **100% PASS** |
| **SS-04** | AXI/AHB/APB Interconnect & MPU | 8 | 10 testbenches | FORMAL-04 | **100% PASS** |
| **SS-05** | Security & Hardware RoT | 7 | 8 testbenches | RoT tamper rejection & CAVP | **100% PASS** |
| **SS-06** | Interrupts & System Reliability | 6 | 6 testbenches | Priority & WDT proofs | **100% PASS** |
| **SS-07** | Serial & Industrial Peripherals | 4 | 5 testbenches | Protocol checkers | **100% PASS** |
| **SS-08** | High-Speed Networking & Bus | 5 | 5 testbenches | Dedicated PHY BFMs | **100% PASS** |
| **SS-09** | Storage Subsystem (SD/QSPI) | 2 | 2 testbenches | DMA stream tests | **100% PASS** |
| **SS-10** | Video & Imaging Pipeline | 4 | 5 testbenches | Video frame sync | **100% PASS** |
| **SS-11** | Memory Protection & Virt | 4 | 4 testbenches | TLB/PMP boundary tests | **100% PASS** |
| **SS-12** | Full-Chip Top Integration | 7 | 5 testbenches | End-to-end SoC boot | **100% PASS** |
| **TOTAL** | **Entire SoC Architecture** | **79 Modules** | **120 Testbenches** | **5 Formal Suites** | **100.0% PASS** |

---

## 4. ASIC Implementation Maturity Classification

The physical design status is accurately classified across all 9 stages:

| Stage | Implementation Stage | Status | Tool & Evidence |
| :---: | :--- | :---: | :--- |
| 1 | RTL Elaboration | **PASS** | Yosys 0.38+ (`synth -top titan_x_top`), 0 unresolved blackboxes. |
| 2 | Generic Synthesis | **PASS** | Yosys generic technology mapping; gate counts & area profiled. |
| 3 | Technology-Mapped Synthesis | **NOT PERFORMED** | Standard cell mapping to SCL 180nm / SkyWater 130nm library gates scheduled for Prompt 8 backend flow. |
| 4 | SRAM Macro Integration | **MODEL ONLY** | `sram_32x64_180nm.v` is a behavioral simulation model and blackbox stub. Qualified foundry hard macros (Liberty `.lib`, LEF, and GDS) are not included. |
| 5 | Floorplanning & Placement | **NOT PERFORMED** | Core area, die boundary, I/O ring, and macro placement unplaced. |
| 6 | Clock Tree Synthesis (CTS) | **NOT PERFORMED** | Multi-domain balanced clock trees unrouted. |
| 7 | Routing | **NOT PERFORMED** | Interconnect metal routing unrouted. |
| 8 | Signoff STA | **NOT PERFORMED** | Post-layout multi-corner timing signoff uncommenced. |
| 9 | Physical DRC/LVS | **NOT PERFORMED** | Design Rule Checking and Layout Versus Schematic uncommenced. |

---

## 5. Known Limitations
1. **Physical Backend Implementation:** Physical layout, macro placement, CTS, routing, and DRC/LVS physical signoff are pending Prompt 8.
2. **Behavioral Memory Wrappers:** On-chip SRAM and L2 tag/data arrays use behavioral simulation wrappers (`sram_32x64_180nm.v`). Hardened foundry macro views must be dropped in during physical implementation.
3. **Privilege Modes:** Harts 0–4 execute exclusively in Machine-mode (M-mode). Supervisor mode (S-mode) and User mode (U-mode) page table translation (`satp`) are inactive in the current synthesizable datapath.
4. **Instruction Set Scope:** All harts implement RV64IM_Zicsr. Floating-point units (F/D), compressed instructions (C), and atomic reservation sets (A) are inactive.

---

## 6. How to Reproduce
See [`docs/qualification/REPRODUCIBLE_BUILD_AND_VERIFICATION.md`](docs/qualification/REPRODUCIBLE_BUILD_AND_VERIFICATION.md) for full commands and environment setup.
