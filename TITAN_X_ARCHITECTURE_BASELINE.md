# SMVDU TITAN-X SoC — Hardware Architecture Baseline Reconstruction
**Phase 1 Architectural Baseline & Independent Principal SoC Audit**  
**Canonical Repository Baseline:** `TITAN-X-2026-11-04`  
**Design Authority:** Independent Principal SoC Architect & RTL Design Reviewer  
**Audit Timestamp:** 2026-11-05  

---

## 1. Source Baseline & Toolchain Identification

### 1.1 Repository Baseline Manifest
Direct inspection of the repository environment establishes the official primary baseline:

| Baseline Attribute | Recorded Canonical Value | Evidence / Source Reference |
| :--- | :--- | :--- |
| **Canonical Repository Path** | `/home/anupam-sarashwat/TITAN-X-2026-11-04` | Host filesystem directory |
| **Canonical Remote URL (`origin`)** | `https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04.git` | `git remote -v` |
| **Active Production Branch** | `repository/migration-2026-11-04` | `git branch` |
| **Exact HEAD Commit SHA** | `af13cba6bc3bc97b8e0fb4a81badc3f742088821` | `git rev-parse HEAD` |
| **Working-Tree Status** | Clean (`nothing to commit, working tree clean`) | `git status` |
| **Primary Design Directory** | `Design Files of TITAN X/` | Repository directory structure |
| **Actual Top-Level Module** | `titan_x_top` | `Design Files of TITAN X/top/titan_x_top/titan_x_top.v` |
| **Active Build Filelist** | `soc_filelist.f` (71 design files + 1 top testbench) | `Design Files of TITAN X/soc_filelist.f` |
| **Verilator Lint Filelist** | `verilator_files.f` (71 synthesizable RTL files) | `Design Files of TITAN X/verilator_files.f` |
| **Secondary Worktree / Directory**| `/home/anupam-sarashwat/SMVDU_TITAN_X_RTL_to_GDS` (Branch: `remediation/final-engineering-qualification`, Commit: `84f559c61592bc7fc9f6f2c60248f688bd63eabd`) | Secondary host workspace |

### 1.2 Host Toolchain & Environmental Versions
All verification scripts, linters, simulators, and compilers were verified natively on the execution host:

| Tool Category | Executable Path | Version & Build Information | Operational Status |
| :--- | :--- | :--- | :--- |
| **HDL Linter / C++ Simulator** | `/usr/bin/verilator` | `Verilator 5.020 2024-01-01 rev (Debian 5.020-1)` | Operational |
| **RTL Logic Synthesizer** | `/usr/bin/yosys` | `Yosys 0.33 (git sha1 2584903a060)` | Operational |
| **Verilog Simulator (Host)** | `/home/anupam-sarashwat/miniforge3/bin/iverilog` | `Icarus Verilog version 13.0 (devel) (0_8-6897-g58dcf39db-dirty)` | Operational |
| **Verilog Simulator (System)** | `/usr/bin/iverilog` | `Icarus Verilog version 12.0 (stable)` | Operational |
| **RISC-V Cross Compiler** | `/home/anupam-sarashwat/.local/riscv/bin/riscv64-unknown-elf-gcc` | `riscv64-unknown-elf-gcc 13.2.0` | Operational |
| **Python Runtime** | `/home/anupam-sarashwat/miniforge3/bin/python3` | `Python 3.13.13 (Linux x86_64)` | Operational |
| **Waveform Viewer** | `/usr/bin/gtkwave` | `GTKWave 3.3.116` | Operational |
| **Build Automation** | `/usr/bin/make` | `GNU Make 4.3` | Operational |
| **Version Control** | `/usr/bin/git` | `git version 2.43.0` | Operational |
| **Formal Toolchain (SymbiYosys)**| `sby` | `Not Found` on PATH | **BLOCKED** for native SBY formal proofs |

---

## 2. Complete Module Accounting & Hierarchy Reconstruction

### 2.1 Complete HDL File Inventory
Recursive traversal of `Design Files of TITAN X/` reveals **188 total Verilog/SystemVerilog source and header files**:
- **Synthesizable / Behavioral Design Files:** 79 files
- **Unit & Integration Testbenches:** 106 files (`tb_*.v`)
- **Header Include Files:** 3 files (`includes/params.vh`, `includes/isa_pkg.vh`, `includes/isa_constants.vh`)

Across these files, **183 distinct modules** are declared (79 non-testbench hardware modules and 104 testbench modules).

### 2.2 Global Module Categorization
The 79 non-testbench hardware modules are rigorously classified into three distinct architectural categories based on their direct structural integration into `titan_x_top`:

1. **Integrated Modules (53 modules):** Structurally instantiated in the `titan_x_top` elaboration tree (see Section 3).
2. **Unintegrated / Disconnected Hardware Modules (18 modules):** Synthesizable modules present in `Design Files of TITAN X/` that are **not instantiated anywhere in the top-level hierarchy**. They exist only in isolation or standalone testbenches.
3. **Simulation BFMs & Debug Helpers (8 modules):** 6 Bus Functional Models in `bfm/` and 2 debug test helpers in `interconnect/` and `peripherals/`.

```
TOTAL DESIGN MODULES (79 Non-TB Modules)
├── Integrated in titan_x_top (53 Modules)
│   ├── Top-Level Integration: titan_x_top (1)
│   ├── CPU Clusters: rv_core_top, rv_monitor_core (2)
│   ├── Pipeline Stages: rv_fetch, rv_decode, rv_regfile, rv_execute, rv_csr, rv_mem, rv_writeback (7)
│   ├── L1 & L2 Caches: rv_icache, rv_dcache, l2_cache_top, l2_cache_ctrl, l2_snoop_filter (5)
│   ├── Bus & Interconnect: axi4_crossbar, axi4_burst_to_lite, axi4_to_ahb, interconnect_mpu, qos_controller, mmu_arbiter (6)
│   ├── Memory & Storage: ddr_ctrl_top, ddr_scheduler, ddr_phy_if, axi_rom, envm_ctrl, mmc_controller, qspi_controller, usb_otg (8)
│   ├── Security Subsystem: secure_boot, sha256_engine, ecdsa_engine, aes_engine, trng, drbg (6)
│   ├── Video Pipeline: mipi_csi2_rx, isp_pipeline, vdma, hdmi_ctrl (4)
│   ├── Interrupt & Debug: plic, clint, rv_debug (3)
│   ├── Low-Speed Peripherals: uart_16550, can_controller, spi_master, i2c_master, gpio_ctrl, watchdog_timer, rtc (7)
│   ├── High-Speed Peripheral: gem_ethernet, pcie_top, pcie_pipe_if (3)
│   └── Clock & Logic Macro: BUFX4 (1)
│
├── Unintegrated / Disconnected Hardware Modules (18 Modules)
│   ├── Processor Subsystems: rv_bpu, rv_fpu, rv_mmu, rv_pmp, rv_ptw, rv_tlb (6)
│   ├── Interconnect Bridges: ahb_to_apb, apb_bridge (2)
│   ├── SRAM Macro Models: sram_32x64_180nm, sram_512kx8_180nm (2)
│   ├── L2 Array Wrappers: l2_data_array, l2_tag_array (2)
│   ├── Peripheral Transceiver: gem_sgmii_pcs (1)
│   ├── CDC & Sync Utilities: cdc_sync, fifo_sync, fifo_async, reset_sync (4)
│   └── Standard Cell Stub: ICGX4 (1)
│
└── Simulation BFMs & Debug Helpers (8 Modules)
    ├── Bus Functional Models: axi_memory_model, ddr4_sdram_bfm, gmii_frame_gen, mipi_csi2_bfm, pcie_rootport_bfm, ulpi_phy_bfm (6)
    └── Debug Helpers: debug_wdt, debug_xbar (2)
```

---

## 3. Discovered Subsystem Microarchitecture

### 3.1 Processor Core Subsystem
The SoC incorporates 5 processor harts organized in a heterogeneous topology:
- **Harts 0–3 (Application Cores):** 4x RV64IM_Zicsr cores instantiated via `rv_core_top.v` (`gen_cores[0..3].u_core`).
- **Hart 4 (Security Monitor Core):** 1x RV64IMAC monitor core instantiated via `rv_monitor_core.v` (`u_monitor`).

#### 3.1.1 Application Cores Microarchitecture (`rv_core_top.v`)
- **Pipeline Architecture:** In-order, 5-stage classic RISC pipeline:
  1. `rv_fetch`: Single-issue instruction fetch with single-outstanding AXI-Lite transaction FSM (`F_REQ`, `F_WAIT`, `F_FLUSH`).
  2. `rv_decode`: Instruction decoder, control word generator, and 32x 64-bit integer register file (`rv_regfile`).
  3. `rv_execute`: Primary ALU, iterative multi-cycle multiplier/divider state machine, branch evaluator, and Machine-mode CSR unit (`rv_csr`).
  4. `rv_mem`: Load/store alignment, sign-extension, data memory access FSM, and memory fault reporter.
  5. `rv_writeback`: Synchronous writeback retirement to register file with forwarding back to EX and DE.
- **Actual Implemented ISA:** **RV64IM_Zicsr (Machine-mode only)**.
  - **RV64I:** Fully functional base integer instruction set.
  - **M-Extension:** Iterative hardware multiply/divide fully implemented in `rv_execute.v`.
  - **Zicsr:** Machine-mode CSR instructions (`csrrw`, `csrrs`, `csrrc`, `csrrwi`, `csrrsi`, `csrrci`, `ecall`, `ebreak`, `mret`) implemented in `rv_csr.v`.
  - **A-Extension (Atomics):** **NOT IMPLEMENTED**. `rv_decode.v` contains no decode logic for `OP_AMO`. In `rv_core_top.v:382`, atomic controls are explicitly tied low: `.is_amo(1'b0), .amo_funct5(5'h0)`.
  - **F/D-Extensions (Floating Point):** **NOT INTEGRATED**. Module `rv_fpu.v` exists in `backend/rv_fpu/`, but in `rv_core_top.v:400` its interface is tied off: `.fpu_result(64'h0), .fpu_valid(1'b0), .fpu_done(1'b0)`.
  - **C-Extension (Compressed Instructions):** **NOT IMPLEMENTED**. `rv_decode.v:83` explicitly traps any 16-bit instruction: `illegal_comb = (instr_in[1:0] != 2'b11);`.
  - **Privileged Architecture:** Strictly **Machine-mode (M-mode)**. `rv_csr.v:109` hardwires `mstatus.MPP` to `2'b11`. Supervisor (S-mode) and User (U-mode) are absent. `misa` hardcodes `MISA_RV64IM` (`rv_csr.v:71-72`).
- **Branch Prediction:** **STATIC / UNINTEGRATED**. Module `rv_bpu.v` exists in `frontend/rv_bpu/`, but is **not instantiated** in `rv_fetch.v` or `rv_core_top.v`. The fetch stage assumes sequential execution ($PC+4$) until `rv_execute` evaluates a branch and asserts `branch_taken` and `branch_target`, triggering a pipeline redirect.
- **Memory Management (MMU) & PMP:** **NOT INTEGRATED**. Modules `rv_mmu.v`, `rv_ptw.v`, `rv_tlb.v`, and `rv_pmp.v` exist in `backend/`, but are **not instantiated** in `rv_core_top.v`. The core issues physical addresses directly.

#### 3.1.2 Monitor Core Microarchitecture (`rv_monitor_core.v`)
- **Role:** Dedicated telemetry, watchdog, and security monitor (Hart 4).
- **Pipeline:** Simplified 3/5-stage in-order pipeline (custom inline fetch stage + `rv_decode` + `rv_execute`).
- **Memory Interface:** Direct un-cached AXI4 master ports for instruction fetch (Master 8) and data load/store (Master 9).
- **Execution:** M-mode only, no FPU, no MMU, no caches.

---

### 3.2 Cache Hierarchy & Memory Coherence Subsystem

#### 3.2.1 Level 1 Caches (Per Application Core)
- **L1 Instruction Cache (`rv_icache.v`):**
  - **Configured Geometry:** 8-way set-associative, 64 sets, 64-byte line size (`params.vh:41-43`).
  - **Calculated Capacity:** $8 \text{ ways} \times 64 \text{ sets} \times 64 \text{ bytes/line} = 32,768 \text{ bytes} = \mathbf{32\text{ KB}}$.
  - **Integration:** Instantiated conditionally in `rv_core_top.v:180` via `generate if (ENABLE_L1_CACHE)`. Parameter `ENABLE_L1_CACHE=1` is explicitly passed by `titan_x_top.v:398`.
  - **Bus Interface:** Coupled with `axi4_burst_to_lite.v` shim decomposing 8-beat refill bursts into single-beat AXI4 requests.
- **L1 Data Cache (`rv_dcache.v`):**
  - **Configured Geometry:** 8-way set-associative, 64 sets, 64-byte line size (`params.vh:44-46`).
  - **Calculated Capacity:** $8 \text{ ways} \times 64 \text{ sets} \times 64 \text{ bytes/line} = 32,768 \text{ bytes} = \mathbf{32\text{ KB}}$.
  - **Policy:** Write-Back, Write-Allocate with SECDED ECC error signaling.
  - **Coherence Snoop Handling:** Directly implements snoop tag matching and dirty line extraction (`rv_dcache.v:170-330`). Upon snoop hit with `TAG_D` (dirty), returns 512-bit cache line data via `snoop_data` and downgrades/invalidates line.
  - **Bus Interface:** Decomposed through `axi4_burst_to_lite.v` shim for 8-beat writeback and refill bursts.

#### 3.2.2 Shared Level 2 Unified Cache Subsystem (`l2_cache_top.v`)
- **Controller Implementation (`l2_cache_ctrl.v`):**
  - **Configured Parameters:** `WAYS = 16`, `SETS = 64`, `DATA_W = 64`, `ADDR_W = 40`, `OFF_W = 6` (64-byte line).
  - **Calculated Actual Capacity:** $16 \text{ ways} \times 64 \text{ sets} \times 64 \text{ bytes/line} = 65,536 \text{ bytes} = \mathbf{64\text{ KB}}$.
  - **Documentation vs Implementation Discrepancy:** While `params.vh:57` declares `L2_SETS = 2048` (2 MB claimed), `l2_cache_top.v:9` and `l2_cache_ctrl.v:13` default to `SETS = 64`, and `titan_x_top.v:542` instantiates `u_l2_cache` with **no parameter overrides**. The elaborated L2 cache is **64 KB**, not 2 MB or 512 KB.
  - **Storage Architecture:** Uses internal behavioral Verilog 2D/3D register arrays (`reg [TAG_W-1:0] tag_mem [0:SETS-1][0:WAYS-1]`, `reg [DATA_W-1:0] data_mem [0:SETS-1][0:WAYS-1][0:7]`). **Foundry macro wrappers `l2_data_array` and `l2_tag_array` are bypassed**.
- **Coherence Snoop Filter / Directory (`l2_snoop_filter.v`):**
  - **Geometry:** 8-way set-associative, 64 sets, tracking 4 core L1 caches.
  - **Directory Protocol:** MESI state tracking (Modified, Exclusive, Shared, Invalid) with dirty intervention routing.
  - **Data Intervention:** `titan_x_top.v:537-540` implements `l2_snoop_data_mux` selecting modified 512-bit cache line data from the owning core and feeding it directly to `u_l2_cache.snoop_data`.

---

### 3.3 Interconnect Fabric & Bus Architecture

#### 3.3.1 AXI4 Crossbar (`axi4_crossbar.v`)
- **Topology:** 15 Master Ports $\times$ 9 Slave Ports (`NM=15`, `NS=9`).
- **Bus Widths:** 40-bit Physical Address (`AW=40`), 64-bit Data (`DW=64`), 4-bit Master ID (`IDW=4`).
- **Routing Engine:** Queue-based transaction routing replacing legacy self-clearing grant logic:
  - Per-master write tracking FIFO `wr_q[m]` (depth 4) tracking target slave until `WLAST`.
  - Per-master read tracking register `rd_tgt[m]` and count `rd_cnt[m]`.
  - Per-slave response owner FIFOs `b_own[s]` and `r_own[s]` ensuring in-order response steering.
- **Internal Error Handling:** Unmapped address requests decode to `T_UNMAPPED` (`4'd9`), which activates internal DECERR response state machines returning `bresp=2'b11` / `rresp=2'b11` without bus hangs.

#### 3.3.2 AXI Crossbar Master Allocations (M0–M14)
- **M0–M3:** Application Cores 0–3 Instruction Fetch (Read-Only)
- **M4–M7:** Application Cores 0–3 Data Access (Read/Write)
- **M8:** Security Monitor Core (Hart 4) Instruction Fetch (Read-Only)
- **M9:** Security Monitor Core (Hart 4) Data Access (Read/Write)
- **M10:** Gigabit Ethernet MAC DMA (`gem_ethernet`)
- **M11:** PCIe Gen2 x4 Root Complex DMA (`pcie_top`)
- **M12:** USB 2.0 OTG Controller DMA (`usb_otg`)
- **M13:** SD/eMMC Storage Controller DMA (`mmc_controller`)
- **M14:** Video Direct Memory Access Engine (`vdma`)

#### 3.3.3 AXI Crossbar Slave Allocations (S0–S8)
- **S0:** L2 Cache / DDR4 Memory Controller (`0x8000_0000` – `0xFFFF_FFFF`, 2 GB)
- **S1:** AXI4-to-AHB Bridge / APB Subsystem (`0x4000_0000` – `0x4FFF_FFFF`, plus legacy aliases)
- **S2:** Boot ROM (`axi_rom`, `0x1000_0000` – `0x1FFF_FFFF`, mapped to `firmware.hex`)
- **S3:** Low Memory / SRAM Window (`0x0000_0000` – `0x0FFF_FFFF`, tied to DECERR responder)
- **S4–S8:** Unused Peripheral Expansion Slaves (tied to DECERR responders in `titan_x_top.v:301-338`)

#### 3.3.4 Fabric Management & Protection
- **Interconnect MPU (`interconnect_mpu.v`):** 16 configurable address regions filtering AR/AW transactions based on 16-bit master ID masks and permissions (Read/Write). Positioned between Master inputs and Crossbar core.
- **QoS Controller (`qos_controller.v`):** Monitored bandwidth limiting and priority promotion generating 4-bit `m_arqos` and `m_awqos` inputs.

#### 3.3.5 Bridge Hierarchy & APB Architecture
- **AXI-to-AHB Bridge (`axi4_to_ahb.v`):** Translates 64-bit AXI4 transactions from Slave 1 into 32-bit AHB-Lite signals (`haddr`, `hwdata`, `hrdata`, `htrans`, `hwrite`).
- **Inline APB Decoder:** In `titan_x_top.v:637-678`, AHB signals are converted directly into APB protocol signals (`psel`, `penable`, `paddr`, `pwdata`, `prdata_mux`). **Standalone bridge modules `ahb_to_apb` and `apb_bridge` are unintegrated and bypassed**.

---

### 3.4 Security Subsystem & Hardware Root of Trust

#### 3.4.1 Hardware Secure Boot Engine (`secure_boot.v`)
- **Root-of-Trust (RoT) Gating:** Gates core reset release through signal `boot_pass`. Application cores and Crossbar are held in reset via `core_rst_n = rst_n & boot_pass` (`titan_x_top.v:97-98`).
- **Cryptographic Validation Sequence:**
  1. Reads header from eNVM memory (`envm_image` array in `titan_x_top.v`). Validates ASCII magic `5449544E` ("TITN") and Authorized Public Key ID `CAFEF00D`.
  2. Latches expected SHA-256 digest (256-bit), Root Public Key coordinates ($Q_x, Q_y$), and signature components ($r, s$).
  3. Feeds 16-word signed payload sequentially to internal SHA-256 engine (`u_sha256`).
  4. Compares generated payload digest against expected digest.
  5. Programs internal NIST FIPS 186-4 P-256 ECDSA engine (`u_ecdsa`) with digest, public key, and signature.
  6. Upon ECDSA signature verification success, asserts `boot_pass = 1'b1`, releasing `core_rst_n`.
  7. On verification failure or magic mismatch, enters `S_HALT`, permanently asserting `boot_fail = 1'b1` and holding cores in reset.

#### 3.4.2 Embedded eNVM Image Table (`titan_x_top.v:881-950`)
- **Format:** Authentic 59-word table containing:
  - Words 0–2: Magic `5449544E`, Length `00000010` (16 payload words), Key ID `CAFEF00D`.
  - Words 3–10: Expected 256-bit SHA-256 Digest (`47FC49DF...6560B2D1`).
  - Words 11–18: Root Public Key $Q_x$ (`26F4FA43...E6703F52`).
  - Words 19–26: Root Public Key $Q_y$ (`9E9689C9...643D6E4F`).
  - Words 27–34: ECDSA Signature $r$ (`E3077595...BB725C5E`).
  - Words 35–42: ECDSA Signature $s$ (`78D3D87A...1F31B431`).
  - Words 43–58: Signed 16-word executable payload words (`10000000...1000003C`).

#### 3.4.3 Standalone Cryptographic Accelerators (APB Slaves)
- **SHA-256 Engine (`sha256_engine.v`):** NIST FIPS 180-4 compliant iterative hash computation.
- **ECDSA P-256 Engine (`ecdsa_engine.v`):** Complete Point Addition / Point Doubling finite-field cryptographic state machine over secp256r1.
- **AES-256 Engine (`aes_engine.v`):** 128/256-bit symmetric block cipher with AXI-Stream and APB control.
- **True Random Number Generator (`trng.v`):** Ring-oscillator entropy accumulator generating 256-bit entropy seed.
- **Deterministic Random Bit Generator (`drbg.v`):** NIST SP 800-90A Hash-DRBG pseudo-random generator seeded by TRNG.
- **eNVM Controller (`envm_ctrl.v`):** APB controller for embedded non-volatile memory macro.

---

### 3.5 Peripheral & I/O Subsystem

#### 3.5.1 Interrupt Controllers
- **Platform-Level Interrupt Controller (`plic.v`):**
  - **Inputs:** 186 interrupt sources (`NUM_SOURCES=186`).
  - **Targets:** 10 interrupt targets (`NUM_TARGETS=10`, 2 per hart for Harts 0–4).
  - **Active Source Allocations:** Source 8 (TRNG), 9 (ECDSA), 10 (DRBG), 11 (AES), 12 (SHA256), 13 (GPIO), 14 (WDT), 15 (SPI), 16 (I2C), 20–24 (UART0–4), 25–26 (CAN0–1), 27 (GEM), 28 (USB).
- **Core-Local Interruptor (`clint.v`):**
  - **Capacity:** 5 Harts (`NUM_HARTS=5`).
  - **Registers:** 64-bit realtime counter `mtime`, per-hart comparator `mtimecmp[0..4]`, per-hart software interrupt `msip[0..4]`.

#### 3.5.2 High-Speed Communication & Video
- **Gigabit Ethernet MAC (`gem_ethernet.v`):** 10/100/1000 Mbps MAC with DMA engine (AXI Master 10) and direct GMII pinout.
- **PCIe Controller (`pcie_top.v`):** PCI Express Gen2 x4 Root Complex with PIPE 3.0 interface (AXI Master 11).
- **USB 2.0 OTG Controller (`usb_otg.v`):** Full/High-Speed USB OTG controller with ULPI PHY interface (AXI Master 12).
- **SD/eMMC Host Controller (`mmc_controller.v`):** 1/4/8-bit MMC/SD memory card controller with AXI DMA (AXI Master 13).
- **Video DMA (`vdma.v`):** Framebuffer DMA engine reading/writing video rasters (AXI Master 14).
- **MIPI CSI-2 Receiver (`mipi_csi2_rx.v`):** Camera Serial Interface RX with 4 D-PHY lanes generating AXI-Stream video packets.
- **ISP Pipeline (`isp_pipeline.v`):** Image Signal Processor performing Bayer demosaicing, gamma correction, and colour space conversion.
- **HDMI Transmitter (`hdmi_ctrl.v`):** HDMI 1.4 / DVI video generator with TMDS serialization.

#### 3.5.3 Low-Speed Peripherals
- **UARTs (`uart_16550.v`):** 5 independent 16550 UART controllers with 16-byte TX/RX FIFOs.
- **CAN Controllers (`can_controller.v`):** 2 CAN 2.0B active controllers.
- **SPI Master (`spi_master.v`):** Quad/Standard SPI master controller with configurable clock phase/polarity.
- **I2C Master (`i2c_master.v`):** Standard (100 kHz) and Fast (400 kHz) mode 2-wire serial bus controller.
- **GPIO Controller (`gpio_ctrl.v`):** 32-bit general purpose I/O with programmable interrupt generation.
- **Watchdog Timer (`watchdog_timer.v`):** Programmable watchdog timer generating interrupt and `wdt_reset_n`.
- **Real-Time Clock (`rtc.v`):** 32.768 kHz battery-backed calendar timer.

---

## 4. Architectural Inconsistencies & Baseline Hardware Defects

### 4.1 DEF-ARCH-01: APB Peripheral Address Decoder Alias Collision
- **Source Location:** `top/titan_x_top/titan_x_top.v:647-716`
- **Mechanism:** In line 647, `psel_uart0` is decoded with a 16-bit prefix:
  ```verilog
  wire psel_uart0 = psel && (paddr[31:16] == 16'h4001 || paddr[31:12] == 20'h40000 || paddr[31:12] == 20'h10000);
  ```
  However, the subsequent 9 peripherals in the address map are placed in the exact same `0x4001_xxxx` block:
  - `0x4001_0000`: RTC (`psel_rtc`)
  - `0x4001_1000`: GPIO (`psel_gpio`)
  - `0x4001_2000`: Watchdog Timer (`psel_wdt`)
  - `0x4001_3000`: SPI Master (`psel_spi`)
  - `0x4001_4000`: I2C Master (`psel_i2c`)
  - `0x4001_5000`: CLINT Alias (`psel_clint`)
  - `0x4001_6000`: SD/MMC Controller (`psel_mmc`)
  - `0x4001_7000`: QSPI Controller (`psel_qspi`)
  - `0x4001_8000`: Video DMA (`psel_vdma`)
- **Impact:** Any APB read or write to `0x4001_1000` through `0x4001_8000` matches `paddr[31:16] == 16'h4001` and asserts `psel_uart0`. On writes, UART0 registers are corrupted. On reads, `prdata_mux` (lines 686–716) evaluates `psel_uart0` with highest priority, completely masking the intended peripheral's read data and returning UART0 data.
- **Classification:** **CONFIRMED DEFECT**.

### 4.2 DEF-ARCH-02: Watchdog Timer Reset Disconnected from System Reset
- **Source Location:** `top/titan_x_top/titan_x_top.v:1036-1042`
- **Mechanism:** In line 1036, wire `wdt_reset_n` is declared and connected to `u_wdt.wdt_reset_n`. It is not connected to `rst_n`, `core_rst_n`, or any reset synchronizer.
- **Impact:** Watchdog expiration generates interrupt `plic_irq[14]`, but **cannot reset the processor cores or SoC hardware**.
- **Classification:** **CONFIRMED DEFECT**.

### 4.3 DEF-ARCH-03: L2 Cache Capacity Discrepancy (64 KB Actual vs 2 MB Spec)
- **Source Location:** `memory/l2_cache_ctrl/l2_cache_ctrl.v:12-13`, `memory/l2_cache_top/l2_cache_top.v:8-9`, `top/titan_x_top/titan_x_top.v:542`
- **Mechanism:** `params.vh:57` defines `L2_SETS = 2048` (2 MB capacity). However, `l2_cache_top.v` defaults to `SETS = 64`, and `titan_x_top.v` instantiates `u_l2_cache` with no parameter overrides.
- **Impact:** Actual physical L2 cache capacity is $16 \text{ ways} \times 64 \text{ sets} \times 64 \text{ bytes} = \mathbf{64\text{ KB}}$. Software configuring memory tables for 512 KB or 2 MB will experience cache aliasing every 64 KB.
- **Classification:** **CONFIRMED DISCREPANCY**.

### 4.4 DEF-ARCH-04: Foundry SRAM Macros Bypassed by Behavioral Logic
- **Source Location:** `memory/l2_cache_ctrl/l2_cache_ctrl.v:112-118`, `memory/sram_32x64_180nm/sram_32x64_180nm.v`
- **Mechanism:** SCL 180nm foundry SRAM macros `sram_32x64_180nm` and `sram_512kx8_180nm` exist, and wrappers `l2_data_array.v` and `l2_tag_array.v` were designed to use them. However, `l2_cache_ctrl.v` synthesizes the entire L2 tag and data arrays out of behavioral standard-cell register arrays (`reg [63:0] data_mem...`).
- **Impact:** Extreme standard-cell gate bloat during ASIC synthesis (83,402+ flip-flops / logic cells) and failure to leverage dense foundry SRAM macro blocks.
- **Classification:** **CONFIRMED ARCHITECTURAL ISSUE**.

### 4.5 DEF-ARCH-05: Claimed RV64GC vs Actual RV64IM_Zicsr ISA Mismatch
- **Source Location:** `backend/rv_core_top/rv_core_top.v:382,400`, `frontend/rv_decode/rv_decode.v:83`, `backend/rv_csr/rv_csr.v:71-72`
- **Mechanism:** Documentation and header comments repeatedly claim "RV64GC Heterogeneous Multicore". Direct RTL inspection confirms:
  - FPU (`rv_fpu.v`) is tied off (`.fpu_result(64'h0)`).
  - Atomics (A) is tied low (`.is_amo(1'b0)`).
  - Compressed (C) is explicitly faulted (`instr_in[1:0] != 2'b11`).
  - MMU Sv39 (`rv_mmu.v`) and PMP (`rv_pmp.v`) are uninstantiated.
  - S-mode and U-mode are not supported (`mstatus.MPP` hardwired to `2'b11`).
- **Impact:** Processors cannot run Linux, FreeBSD, or standard RV64GC binaries. Only bare-metal RV64IM M-mode firmware is executable.
- **Classification:** **CONFIRMED ARCHITECTURAL DIVERGENCE**.

---

## 5. Disconnected and Unused Modules Inventory

The following 18 hardware RTL modules exist in `Design Files of TITAN X/`, compile cleanly, but are **unconnected to the top-level design**:

| Module Name | Source RTL File | Stated Functional Purpose | Reason for Disconnection / Bypassing in RTL |
| :--- | :--- | :--- | :--- |
| `rv_bpu` | `frontend/rv_bpu/rv_bpu.v` | 2K-entry BHT / 512-entry BTB branch predictor | `rv_fetch.v` uses static sequential fetch; predictor is unintegrated. |
| `rv_fpu` | `backend/rv_fpu/rv_fpu.v` | Single-precision IEEE 754 Floating Point Unit | `rv_core_top.v:400` ties FPU inputs/outputs to zero. |
| `rv_mmu` | `backend/rv_mmu/rv_mmu.v` | Sv39 Page-Based Virtual Memory System | Cores issue physical addresses; `mmu_ptw_arvalid` tied low in top. |
| `rv_pmp` | `backend/rv_pmp/rv_pmp.v` | 8-entry Physical Memory Protection unit | Not instantiated in `rv_core_top.v` or `rv_monitor_core.v`. |
| `rv_ptw` | `backend/rv_ptw/rv_ptw.v` | Multi-level Page Table Walker | Sub-module of unintegrated `rv_mmu.v`. |
| `rv_tlb` | `backend/rv_tlb/rv_tlb.v` | 32-entry Translation Lookaside Buffer | Sub-module of unintegrated `rv_mmu.v`. |
| `ahb_to_apb` | `interconnect/ahb_to_apb/ahb_to_apb.v` | AHB-Lite to APB3 bridge protocol converter | Bypassed by inline combinational APB decoder in `titan_x_top.v:637`. |
| `apb_bridge` | `interconnect/apb_bridge/apb_bridge.v` | 16-slave APB bridge and decoder | Bypassed by inline combinational APB decoder in `titan_x_top.v:647`. |
| `gem_sgmii_pcs` | `peripherals/gem_sgmii_pcs/gem_sgmii_pcs.v`| SGMII Physical Coding Sublayer for Ethernet | `gem_ethernet.v` exposes GMII interface pins directly at top level. |
| `l2_data_array` | `memory/l2_data_array/l2_data_array.v` | SCL 180nm SRAM wrapper for L2 cache data | `l2_cache_ctrl.v:118` implements data storage as behavioral reg arrays. |
| `l2_tag_array` | `memory/l2_tag_array/l2_tag_array.v` | SCL 180nm SRAM wrapper for L2 cache tags | `l2_cache_ctrl.v:112` implements tag storage as behavioral reg arrays. |
| `sram_32x64_180nm` | `memory/sram_32x64_180nm/sram_32x64_180nm.v`| Foundry single-port 32x64 SRAM macro | Only referenced in unused `l2_data_array.v`. |
| `sram_512kx8_180nm`| `memory/sram_512kx8_180nm/sram_512kx8_180nm.v`| Foundry single-port 512Kx8 SRAM macro | Uninstantiated anywhere in the repository. |
| `cdc_sync` | `common/cdc_sync/cdc_sync.v` | 2-flop / 3-flop clock domain crossing synchronizer | Standalone utility; top-level interfaces rely on internal logic. |
| `fifo_sync` | `common/fifo_sync/fifo_sync.v` | Synchronous circular FIFO queue | Standalone utility; crossbar and controllers implement local queues. |
| `fifo_async` | `common/fifo_async/fifo_async.v` | Asynchronous dual-clock pointer FIFO | Standalone utility; peripherals implement internal FIFOs. |
| `reset_sync` | `common/reset_sync/reset_sync.v` | Asynchronous-assert / synchronous-deassert reset | Standalone utility; top uses direct reset nets. |
| `ICGX4` | `includes/stdcell_stubs.v` | Integrated Clock Gating cell stub | Unreferenced across the design. |

---

## 6. Evidence Classification Table

Every architectural claim in this report has been assigned an objective classification:

| Architectural Area / Claim | Classification | Primary Evidence Source |
| :--- | :---: | :--- |
| **Top-Level Module is `titan_x_top`** | `CONFIRMED` | `top/titan_x_top/titan_x_top.v:7` |
| **Application Core Count = 4 (Harts 0–3)** | `CONFIRMED` | `top/titan_x_top/titan_x_top.v:380-428` (`gen_cores[0..3]`) |
| **Security Monitor Core Count = 1 (Hart 4)**| `CONFIRMED` | `top/titan_x_top/titan_x_top.v:446-465` (`u_monitor`) |
| **Actual Implemented ISA is RV64IM_Zicsr** | `CONFIRMED` | `backend/rv_csr/rv_csr.v:71-72`, `frontend/rv_decode/rv_decode.v:83` |
| **Atomics (A) Extension Unimplemented** | `CONFIRMED` | `backend/rv_core_top/rv_core_top.v:382`, `frontend/rv_decode/rv_decode.v` |
| **FPU (F/D) Unintegrated** | `CONFIRMED` | `backend/rv_core_top/rv_core_top.v:400` (`.fpu_result(64'h0)`) |
| **Compressed (C) Extension Flagged Illegal** | `CONFIRMED` | `frontend/rv_decode/rv_decode.v:83` (`instr_in[1:0] != 2'b11`) |
| **MMU Sv39 / PTW / TLB Unintegrated** | `CONFIRMED` | `top/titan_x_top/titan_x_top.v:823` (`mmu_ptw_arvalid = 5'b0`) |
| **Branch Predictor (`rv_bpu`) Unintegrated** | `CONFIRMED` | `frontend/rv_fetch/rv_fetch.v`, `backend/rv_core_top/rv_core_top.v` |
| **L1 I-Cache & D-Cache = 32 KB Each** | `CONFIRMED` | `includes/params.vh:41-46`, `frontend/rv_icache/rv_icache.v` |
| **L2 Unified Cache Capacity = 64 KB Actual**| `CONFIRMED` | `memory/l2_cache_ctrl/l2_cache_ctrl.v:8-13`, `top/titan_x_top/titan_x_top.v:542` |
| **L2 Cache Uses Behavioral Flip-Flop Arrays** | `CONFIRMED` | `memory/l2_cache_ctrl/l2_cache_ctrl.v:112-118` |
| **Hardware Secure Boot Verifies ECDSA/SHA** | `CONFIRMED` | `security/secure_boot/secure_boot.v:32-95`, `top/titan_x_top/titan_x_top.v:97` |
| **Watchdog Reset Signal Disconnected** | `CONFIRMED` | `top/titan_x_top/titan_x_top.v:1036-1042` (`wdt_reset_n` no sink) |
| **APB Address Overlap Corrupts 9 Slaves** | `CONFIRMED` | `top/titan_x_top/titan_x_top.v:647-716` (`psel_uart0` prefix mask) |
| **Bypass of `ahb_to_apb` and `apb_bridge`** | `CONFIRMED` | `top/titan_x_top/titan_x_top.v:637-678` (Direct combinational decode) |

---
