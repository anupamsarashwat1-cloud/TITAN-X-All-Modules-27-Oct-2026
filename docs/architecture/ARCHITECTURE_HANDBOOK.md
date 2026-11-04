# SMVDU TITAN-X Architecture Handbook & System Specification

**Revision:** 2026-11-03-RC1  
**Target Repository:** `TITAN-X-2026-11-03`  
**Governing Specifications:** RISC-V Unprivileged ISA v20191213, RISC-V Privileged Architecture v1.12, AMBA AXI4 / AHB / APB Protocols  

---

> [!IMPORTANT]
> **GATE H QUALIFICATION STATEMENT:**  
> **RTL verification/release candidate; physical-design sign-off not established.**  
> All functional verification, bounded model checking proofs, architectural mutation tests, and generic logic synthesis passes documented in this handbook apply strictly to the register-transfer level (RTL) implementation. Physical design tape-out sign-off (commercial PDK place-and-route, CTS, timing closure across PVT corners, DRC, and LVS) is not established.

---

## 1. Processor Core Microarchitecture

### 1.1 In-Order 5-Stage Single-Issue Pipeline

The TITAN X core spine (`backend/rv_core_top/rv_core_top.v`) implements an in-order, single-issue 5-stage classic RISC pipeline:

```
  +---------+     +---------+     +---------+     +---------+     +---------+
  |  FETCH  | --> | DECODE  | --> | EXECUTE | --> | MEMORY  | --> |WRITEBACK|
  | (IF)    |     | (ID)    |     | (EX)    |     | (MEM)   |     | (WB)    |
  +---------+     +---------+     +---------+     +---------+     +---------+
       |               |               |               |               |
       v               v               v               v               v
   PC Gen /        31x64-bit       64-bit ALU      Load Align /    Arch Register
   Aligner         Regfile &       & Unrolled      Store Mask /    Retirement
   & BPU Iface     Bypass          M-Ext Unit      Direct Memory   & Commit
```

1. **Instruction Fetch (IF):** 64-bit PC management, boot vector release (`0x0000_0000_8000_0000`), 32-bit instruction alignment enforcement (`pc[1:0] == 2'b00`), branch target multiplexing, and memory stall handshake.
2. **Instruction Decode (ID):** Instruction decomposition, immediate sign-extension, hazard detection, register scoreboarding, and access to the 31x64-bit general-purpose register file (`rv_regfile.v`) with hardwired-zero x0 and write-first operand forwarding.
3. **Execute (EX):** 64-bit integer arithmetic logic unit (ALU), full 64-bit unrolled M-extension hardware multiplier and non-blocking multi-cycle divider (`rv_execute.v`), branch condition evaluation, and integrated Machine-mode control and status register bank (`rv_csr.v`).
4. **Memory Access (MEM):** Load data sign/zero-extension (`LB`, `LH`, `LW`, `LBU`, `LHU`, `LWU`, `LD`), store byte lane mask steering (`SB`, `SH`, `SW`, `SD`), atomic reservation management (`LR.D`, `SC.D`), and direct physical memory bus interface.
5. **Writeback (WB):** Register destination commit, pipeline retirement pulses (`minstret` increment), and writeback data selection.

### 1.2 Implemented Instruction Set Architecture (ISA)

- **Native Core ISA:** **RV64IM** (64-bit base integer instructions plus standard M-extension for integer multiplication and division).
- **Addressing Mode:** Native **Physical Memory Addressing** (direct physical memory bus transactions driven by the core pipeline).
- **Compressed Instructions ('C'):** Not implemented at the pipeline execution core level. Bit 2 of `misa` is strictly cleared (`misa[2] = 0`). All instructions are 32-bit aligned.
- **Floating-Point ('F' / 'D'):** Provided as a dedicated, fully verified IEEE 754 modular co-processor IP block (`backend/rv_fpu/rv_fpu.v`), rather than an integrated pipeline unit in the integer spine.
- **Atomic Operations ('A'):** Load-Reserved / Store-Conditional primitives (`LR.D`/`SC.D`) are supported at the memory stage with hardware reservation tracking.

### 1.3 Privileged Architecture & Machine-Mode Invariant

TITAN X operates as a dedicated **Machine-mode (M-mode)** high-reliability processing core conforming to RISC-V Privileged Architecture v1.12:
- **`misa`:** Default value `64'h8000_0000_0000_1100` (`MXL = 2` for 64-bit, extensions `I` and `M` enabled).
- **`mstatus`:** Supports `MIE` (Machine Interrupt Enable) and `MPIE` (Machine Previous Interrupt Enable).
- **Machine-Mode Invariant:** The previous privilege mode field `mstatus.MPP` is hardwired to `2'b11` (Machine mode). Traps and `mret` instructions strictly preserve `MPP = 2'b11`. User-mode (`U`) and Supervisor-mode (`S`) transitions are not supported at the core pipeline level.
- **Trap Handling:** Direct interrupt vectoring with mandatory 4-byte alignment enforced on `mtvec` (`mtvec_out = {mtvec_q[63:2], 2'b00}`).

---

## 2. Shared Memory Hierarchy & Coherence

### 2.1 2MB Shared L2 Cache Subsystem
- **Organization:** 2MB, 16-way set-associative cache with 64-byte cache lines.
- **Controller (`memory/l2_cache_ctrl/l2_cache_ctrl.v`):** AXI4 slave interface, pseudo-LRU (PLRU) replacement policy, write-back with write-allocate policy.
- **Snoop Filter (`memory/l2_snoop_filter/l2_snoop_filter.v`):** Directory-based MESI (Modified, Exclusive, Shared, Invalid) coherence filter maintaining multi-core cache consistency across CPU cluster interfaces. Formally verified safe against ownership conflicts.
- **Memory Arrays:** Dual-ported SRAM macros (`memory/l2_tag_array/` and `memory/l2_data_array/`).

### 2.2 DDR4 SDRAM Controller Subsystem
- **Top Controller (`memory/ddr_ctrl_top/ddr_ctrl_top.v`):** AXI4 slave interface mapped to aperture `0x8000_0000`–`0xFFFF_FFFF`.
- **Command Scheduler (`memory/ddr_scheduler/ddr_scheduler.v`):** Open-row policy, bank-conflict avoidance, refresh interleaving, and read-priority reordering.
- **DDR PHY Interface (`memory/ddr_phy_if/ddr_phy_if.v`):** DFI-compliant memory physical interface for 4-bank DDR4 memory devices.

---

## 3. Global Interconnect Architecture

### 3.1 15-Master × 9-Slave AXI4 Fabric
The primary on-chip interconnect (`interconnect/axi4_crossbar/axi4_crossbar.v`) features 15 independent AXI4 master ports and 9 slave apertures:
- **Master Interfaces (M0–M14):** CPU Cores (0–3), Security Monitor Core, Cryptographic DMA, GbE DMA, PCIe Root Port, USB OTG, Video DMA, MIPI CSI-2 DMA.
- **Slave Apertures (S0–S8):**
  - **S0:** DDR4 Controller (`0x8000_0000`–`0xFFFF_FFFF`)
  - **S1:** APB Bridge Chain (`0x4000_0000`–`0x4FFF_FFFF`)
  - **S2:** Axi Boot ROM (`0x0001_0000`–`0x0001_7FFF`)
  - **S3:** Shared L2 Cache (`0x0000_0000`–`0x0000_FFFF`)
  - **S4–S8:** High-speed streaming peripherals and reservation apertures.
- **Arbitration & Protection:** Non-blocking round-robin arbitration per channel (AW, AR, W, R, B), Memory Protection Unit (`interconnect/interconnect_mpu/mpu.v`) access gating, QoS throttling (`interconnect/qos_controller/qos_controller.v`), and immediate DECERR (`2'b11`) response generation for unmapped address requests.

### 3.2 Bridge Chain & Peripheral Bus
- **AXI4-to-AHB Lite (`interconnect/axi4_to_ahb/axi4_to_ahb.v`):** Translates 64-bit burst transactions to 32-bit AHB transfers.
- **AHB-to-APB Bridge (`interconnect/ahb_to_apb/ahb_to_apb.v`):** Manages two-phase APB (setup and access) cycles for all control registers.
- **APB Bridge (`interconnect/apb_bridge/apb_bridge.v`):** Demultiplexes peripheral register accesses across UART, PLIC, CAN, RTC, Watchdog, I2C, SPI, and GPIO.

---

## 4. Hardware Security & Root of Trust

- **Secure Boot Controller (`security/secure_boot/secure_boot.v`):** Hardware state machine managing primary reset deassertion, Boot ROM integrity verification, and CPU cluster wake-up.
- **Entropy Generation:** True Random Number Generator (`peripherals/trng/trng.v`) providing continuous physical entropy to a NIST SP 800-90A compliant CTR-DRBG engine (`security/drbg/drbg.v`).
- **Cryptographic Accelerators:**
  - **AES-256 (`peripherals/aes_engine/aes_engine.v`):** High-throughput symmetric encryption/decryption engine.
  - **SHA-256 (`peripherals/sha256_engine/sha256_engine.v`):** Secure hash algorithm acceleration for firmware authentication.
  - **ECDSA P-256 (`security/ecdsa_engine/ecdsa_engine.v`):** Elliptic curve digital signature co-processor for asymmetric authentication.
- **Non-Volatile Storage (`security/envm_ctrl/envm_ctrl.v`):** 128KB embedded NVM controller holding hardware root keys and initial bootloader code.

---

## 5. Modular IP Cores & Peripherals

The following standalone subsystem IP cores are fully implemented, verified with individual testbenches, and provided as modular building blocks:
- **Virtual Memory Units:** Sv39 Memory Management Unit (`rv_mmu.v`), Translation Lookaside Buffer (`rv_tlb.v`), Page Table Walker (`rv_ptw.v`), and Physical Memory Protection (`rv_pmp.v`).
- **Floating-Point Unit:** RV64F/D single- and double-precision arithmetic co-processor (`rv_fpu.v`).
- **Video & Display Pipeline:** 4-lane MIPI CSI-2 Receiver (`mipi_csi2_rx.v`), Image Signal Processor (`isp_pipeline.v`), Video DMA Engine (`vdma.v`), and HDMI 1.4 Controller (`hdmi_ctrl.v`).
- **High-Speed Networking & Storage:** Gigabit Ethernet MAC with SGMII PCS (`gem_ethernet.v`, `gem_sgmii_pcs.v`), PCIe Gen2 Controller (`pcie_top.v`), USB 2.0 OTG Controller (`usb_otg.v`), SD/MMC Controller (`mmc_controller.v`), and Quad-SPI (`qspi_controller.v`).
- **Standard Industrial Peripherals:** Dual 16550 UARTs (`uart_16550.v`), CAN 2.0B Bus Controller (`can_controller.v`), Real-Time Clock (`rtc.v`), Watchdog Timer (`watchdog_timer.v`), 32-bit GPIO (`gpio_ctrl.v`), I2C Master (`i2c_master.v`), and SPI Master (`spi_master.v`).

---

## 6. Synthesis & Area Metrics

Generic technology-independent logic synthesis executed using Yosys 0.33 on the processor core (`rv_core_top`) yields:
- **Total Core Cells:** 79,560 generic cells (4,005 flip-flops, 75,555 combinational logic gates).
- **Execution Stage:** 82,625 cells (84.0% of core area) due to full 64-bit unrolled integer multiplier and divider arrays.
- **Register File:** 10,388 cells (10.6% of core area) implementing 31 64-bit registers with dual asynchronous read ports and bypass forwarding.
- **CSR Subsystem:** 2,025 cells (2.1% of core area) maintaining machine status, trap registers, and 64-bit performance counters.
- **Memory & Decode Stages:** ~2,358 cells (2.4% of core area).
- **Instruction Fetch:** 914 cells (0.9% of core area).

Refer to [`docs/qualification/SYNTHESIS_REPORT.md`](../qualification/SYNTHESIS_REPORT.md) for full gate-level accounting and technology mapping analysis.
