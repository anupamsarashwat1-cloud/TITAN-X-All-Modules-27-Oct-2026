# SMVDU TITAN X — Known Architectural Boundaries & Implementation Limitations
## Document ID: TITANX-LIMITATIONS-2026-11-18

**Project:** SMVDU TITAN X — 64-Bit Multicore RISC-V SoC  
**Release Tag:** `SMVDU-TITAN-X-v1.0.0`  
**Release Commit:** `471b8575a5cce650635351b9ca2ae4d951ff2dd3`  
**Engineering Release Date:** 2026-11-18  

---

## 1. Overview & Architectural Boundaries

This document provides a rigorous, transparent, and technically accurate specification of the boundaries, architectural scoping, and physical implementation status of the SMVDU TITAN X System-on-Chip (SoC). 

All items listed herein represent **deliberate architectural design boundaries** or **distinctions between the verified RTL baseline and the subsequent physical backend implementation flow**.

---

## 2. Physical Design & ASIC Implementation Status

| Stage Number | Implementation Stage | Actual Achieved Status | Technical Boundary & Verification Scope |
| :---: | :--- | :---: | :--- |
| **1** | **RTL Elaboration** | **PASS** | Completed with Yosys 0.38+ (`hierarchy -check -top titan_x_top`). All 79 synthesizable IP modules elaborate cleanly with 0 unresolved blackbox instances. |
| **2** | **Generic Synthesis** | **PASS** | Completed with Yosys generic technology library mapping (`stat`). Logic gate distributions, cell counts, and operator complexities are fully profiled. |
| **3** | **Technology-Mapped Synthesis** | **NOT PERFORMED** | Standard cell mapping to SCL 180nm or SkyWater 130nm library gates (`.lib`) has not been run. Gate-level netlists with foundry standard cell names are not part of this release. |
| **4** | **SRAM Macro Integration** | **MODEL ONLY** | `sram_32x64_180nm.v` and `sram_512kx8_180nm.v` are behavioral simulation models with `(* blackbox *)` synthesis attributes. Qualified foundry hard macros (Liberty `.lib`, LEF physical layouts, and GDSII mask geometries) are not present in the repository. |
| **5** | **Floorplanning & Placement** | **NOT PERFORMED** | Core area, aspect ratio, I/O pad ring placement, power rings, and memory macro placement are unplaced. |
| **6** | **Clock Tree Synthesis (CTS)** | **NOT PERFORMED** | Multi-corner clock buffer insertion, skew balancing, and insertion delay optimization have not been executed. |
| **7** | **Routing** | **NOT PERFORMED** | Global and detail routing across the 6 interconnect metal layers has not been performed. |
| **8** | **Signoff Static Timing Analysis (STA)** | **NOT PERFORMED** | Multi-corner (PVT: Process, Voltage, Temperature) signoff timing analysis (Setup/Hold, Max Transition, Min Pulse Width) has not been run. |
| **9** | **Physical Verification (DRC / LVS)** | **NOT PERFORMED** | Design Rule Checking (DRC) and Layout Versus Schematic (LVS) physical signoff have not commenced. |

### Technical Clarification on Physical Tape-Out
- **Tape-Out Packaging:** The design is **NOT** taped out and is **NOT** ready for silicon mask fabrication without the completion of physical place-and-route, CTS, signoff STA, and DRC/LVS closure.
- **Accurate Release Scope:** The design is frozen as a **Qualified RTL & Gate-Level Synthesizable Baseline (Ready for Physical Implementation Flow)**. Physical implementation represents the designated scope of Prompt 8.

---

## 3. Processor Core & Instruction Set Architecture Boundaries

### 3.1 Instruction Set Scope: RV64IM_Zicsr
- **Active Extensions:**
  - **RV64I:** 64-bit base integer instruction set (load, store, ALU, branch, jump, system calls).
  - **RV64M:** Standard integer multiplication (MUL, MULH, MULHSU, MULHU, MULW) and division/remainder (DIV, DIVU, REM, REMU, DIVW, DIVUW, REMW, REMUW) executed via hardware Radix-4 multicycle execution units.
  - **Zicsr:** Standard RISC-V Control and Status Register instructions (`csrrw`, `csrrs`, `csrrc`, `csrrwi`, `csrrsi`, `csrrci`, `mret`, `wfi`).
- **Inactive / Uninstantiated Extensions:**
  - **Compressed Instructions ('C'):** Uninstantiated. The instruction fetch stage (`rv_fetch`) and decode stage (`rv_decode`) operate exclusively on 32-bit aligned instructions (`imem_rdata[31:0]`). The PC advances strictly in 4-byte increments.
  - **Atomic Memory Operations ('A'):** Disabled in synthesizable datapath. Reservation controllers (LR/SC) and atomic arithmetic operations (AMOADD, AMOSWAP, etc.) are inactive (`de_is_amo = 1'b0`).
  - **Floating-Point Unit ('F'/'D'):** Disconnected. While modular FPU wrappers exist in the repository, the core execution stage ties `.fpu_result(64'h0), .fpu_valid(1'b0), .fpu_done(1'b1);`.

### 3.2 Privilege Levels: Machine-Mode Only
- All 5 harts (Harts 0–3 and Hart 4) operate exclusively in RISC-V **Machine mode (M-mode, `priv_mode = 2'b11`)**.
- Supervisor mode (S-mode, `2'b01`) and User mode (U-mode, `2'b00`) privilege transitions, exception delegation registers (`medeleg`, `mideleg`), and virtual memory address translation via `satp` (Sv39/Sv48) are not active in the current synthesizable pipeline.

### 3.3 Hart 4 Monitor Core Architectural Scope
- Hart 4 is instantiated as `rv_monitor_core.v`.
- While historical comments and documentation referenced "RV64IMAC (SiFive E51 equivalent)", architectural verification confirms Hart 4 physically implements **RV64IM_Zicsr** in Machine mode. It utilizes a direct single-beat AXI4 master interface without L1 cache or virtual memory management.

---

## 4. Subsystem & Behavioral Model Scope

### 4.1 Memory Models & High-Speed PHYs
- **DDR4 Controller & PHY:** The integrated DDR4 subsystem (`ddr_ctrl_top`) contains a complete synthesizable AXI4 burst scheduler and command sequencer. In simulation, it interfaces a behavioral DDR4 SDRAM BFM (`ddr4_sdram_bfm.v`). Physical implementation requires a hardened foundry DDR PHY macro.
- **Ethernet MAC & SGMII:** The Gigabit Ethernet MAC (`gem_ethernet`) is synthesizable and interfaces a behavioral SGMII PCS transceiver model (`gem_sgmii_pcs.v`) and frame generator (`gmii_frame_gen.v`).
- **PCIe Controller:** The PCIe Gen3 controller (`pcie_top`) implements protocol transaction layer logic and interfaces a PIPE PHY model (`pcie_pipe_if.v`) and Root Port BFM (`pcie_rootport_bfm.v`).
- **USB 2.0 OTG:** Implements UTMI/ULPI link controller logic interfacing a ULPI transceiver simulation model (`ulpi_phy_bfm.v`).
- **MIPI CSI-2 & HDMI:** Video pipelines implement synthesizable packet unpacking and TMDS encoding, verified against behavioral camera/display BFMs.

---

## 5. Security & Root-of-Trust Scoping

- **Cryptographic Implementations:**
  - NIST FIPS 180-4 SHA-256 and FIPS 186-4 ECDSA P-256 point multiplier are verified in full multicycle hardware with `FAST_SIM=0` (iterative Montgomery multiplier) and `FAST_SIM=1`.
  - The OTP eFuse array (`efuse_ctrl.v`) provides 4 key slots with slot revocation masks and monotonic security counter comparison. In simulation, eFuse bits are modeled in registers; in silicon, physical poly-fuse or anti-fuse macros are required.
- **Pre-Boot Isolation:**
  - CPU execution is strictly locked (`core_rst_n = 0`, AXI fetch aperture gated) until Root-of-Trust attestation completes.
  - Multi-hart benchmark execution has been cryptographically signed and verified pre-boot with zero backdoor testbench memory writes.
