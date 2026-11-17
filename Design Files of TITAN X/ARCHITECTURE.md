# SMVDU TITAN-X Multi-Core RISC-V SoC Architecture Specification

## 1. System Overview
The **SMVDU TITAN-X** is an advanced 64-bit multi-core heterogeneous System-on-Chip (SoC) implementing the RISC-V RV64IM_Zicsr instruction set architecture (with integrated IEEE 754 FPU coprocessor pipeline). It integrates a coherent processor cluster, multi-tier cache subsystem, high-bandwidth AXI4 crossbar interconnect, hardware Root-of-Trust security enclave, high-performance video and imaging pipelines, storage controllers, and full industrial peripheral interfaces.

---

## 2. Processor Core Organization
The CPU cluster integrates five RISC-V harts:
- **Four High-Performance Application Cores (Harts 0–3)**:
  - Architecture: RV64IM_Zicsr in-order 5-stage pipeline (`rv_fetch` -> `rv_decode` -> `rv_execute` -> `rv_mem` -> `rv_writeback`).
  - L1 Instruction Cache: 32 KB 8-way set-associative (`rv_icache`).
  - L1 Data Cache: 32 KB 8-way set-associative write-back, write-allocate (`rv_dcache`).
  - Memory Protection & Addressing: Physical Memory Protection (`rv_pmp`) with Bare physical addressing; SV39 paging structures (`rv_ptw`, `rv_tlb`) available for virtual memory extensions.
  - Branch Prediction: Two-level branch prediction unit with branch target buffer and return address stack (`rv_bpu`).
  - Floating Point: IEEE 754-2008 single/double-precision FPU coprocessor datapath (`rv_fpu`).
  - Traps & CSRs: Standard RISC-V Machine-mode privilege architecture with WARL CSR validation (`mtvec`, `mepc`, `mcause`, `mstatus`, `misa`, `mip`, `mie`) handling (`rv_csr`).
- **One Real-Time Secure Service Monitor Core (Hart 4)**:
  - Architecture: RV64IM_Zicsr deterministic core (`rv_monitor_core`).
  - Purpose: Platform telemetry, secure enclave monitoring, safety watchdog, and auxiliary system supervision.

---

## 3. Coherent Memory Subsystem
The multi-tier memory hierarchy balances high bandwidth, low latency, and multi-core data coherence:

- **Level 1 Caches**:
  - $4 \times 32\text{ KB}$ L1 I-Cache ($64\text{ sets} \times 8\text{ ways} \times 64\text{B}$).
  - $4 \times 32\text{ KB}$ L1 D-Cache ($64\text{ sets} \times 8\text{ ways} \times 64\text{B}$) with AXI4 8-beat burst refill and writeback.
- **Level 2 Shared Cache (`l2_cache_top`)**:
  - Implementation: 16-way set-associative, 64-byte cache line architecture (`l2_cache_ctrl`).
  - Tag Arrays: `l2_tag_array` with valid, dirty, and MESI state tracking.
  - Data Arrays: 4 banks of SRAM macros (`sram_512kx8_180nm` / `sram_32x64_180nm`).
  - Elaborated Geometry: 64 sets $\times$ 16 ways $\times$ 64 bytes = 64 KB (scalable via parameters to 512 KB / 2 MB).
  - External Memory Refill Engine: 8-beat INCR burst read/write transactions (`axi4_burst_to_lite`).
- **Coherence & Snoop Filter (`l2_snoop_filter`)**:
  - Directory: Tracks L1 cache line states across all 4 application cores using the MESI protocol.
  - Operations: Snoops L1 tags on ReadShared (`GetS`), ReadUnique (`GetM`), CleanInvalidate, and MakeInvalid.
  - Dirty Intervention: Intercepts read misses targeting lines modified in peer L1 caches, extracting dirty lines directly from core snoop ports and updating L2/DDR.
- **DDR4 SDRAM Controller (`ddr_ctrl_top`)**:
  - Components: High-throughput request scheduler (`ddr_scheduler`), DFI PHY interface (`ddr_phy_if`), and timing engine supporting standard DDR4 DRAM timings.

---

## 4. Interconnect Matrix
The central interconnect fabric connects 10 AXI4 bus masters to 8 slave targets:
- **Core Interconnect (`axi4_crossbar`)**:
  - 10 Master Ports: Hart 0–3 Instruction (M0–M3), Hart 0–3 Data (M4–M7), Hart 4 Monitor Instruction (M8), Hart 4 Monitor Data (M9).
  - 8 Slave Ports:
    - S0: L2 Cache Subsystem / DDR4 Main Memory (`0x8000_0000`–`0xFFFF_FFFF`)
    - S1: AHB/APB Peripheral Subsystem Bridge (`0x1000_0000`–`0x1FFF_FFFF`)
    - S2: DMA & High-Speed Video Subsystem
    - S3: PCIe Gen3 x4 Controller
    - S4: Gigabit Ethernet MAC (GEM)
    - S5: Embedded Non-Volatile Memory (eNVM) (`0x0000_0000`–`0x0001_FFFF`)
    - S6: AXI Boot ROM (`0x0002_0000`–`0x0002_FFFF`)
    - S7: Reserved / On-Chip Scratchpad SRAM
- **Interconnect Quality-of-Service (`qos_controller`)**:
  - Dynamic priority arbitration, latency guarantees for real-time video/ethernet streams, and starvation prevention.
- **Memory Protection Unit (`interconnect_mpu`)**:
  - Enforces domain isolation and prevents unauthorized peripheral/memory accesses across master ports.

---

## 5. Security & Hardware Root-of-Trust
The platform integrates an isolated security subsystem ensuring boot integrity and cryptographic acceleration:
- **Hardware Secure Boot Engine (`secure_boot`)**:
  - Enforces cryptographic verification of firmware images stored in eNVM prior to releasing core reset.
  - Integrity Verification: NIST FIPS 180-4 SHA-256 hash calculation over the entire firmware binary.
  - Digital Signature Authentication: NIST FIPS 186-4 ECDSA P-256 curve verification ($y^2 \equiv x^3 - 3x + b \pmod p$).
  - Trust Model: Hardware immutable Root-of-Trust public key coordinates stored in on-chip silicon constants/OTP, strictly rejecting unauthenticated keys.
  - Reset Gating: `core_rst_n` remains asserted low until cryptographic authentication succeeds.
- **Cryptographic Engines**:
  - `sha256_engine`: Full 64-round iterative SHA-256 engine with multi-block digest accumulation.
  - `ecdsa_engine`: Hardware elliptic-curve engine with Jacobian projective point doubling/addition and binary Extended Euclidean Algorithm modular inversion.
  - `aes_engine`: Hardware AES-128/256 cipher engine supporting ECB/CBC/CTR modes.
  - `trng` & `drbg`: True Random Number Generator ring-oscillator entropy source paired with a NIST SP 800-90A Deterministic Random Bit Generator.

---

## 6. Interrupt Architecture
- **Core Local Interruptor (`clint`)**:
  - Implements RISC-V privileged specification timer (`mtime`, `mtimecmp`) and inter-processor software interrupts (`msip`).
- **Platform-Level Interrupt Controller (`plic`)**:
  - Supports 186 external interrupt sources mapped across 10 target contexts (M-mode / S-mode per hart).
  - Individual source priority registers, threshold gating, and interrupt completion handshaking.

---

## 7. Storage, Video, and Industrial Peripherals
- **Storage Subsystem**:
  - `usb_otg`: USB 2.0 High-Speed On-The-Go controller with ULPI transceiver interface.
  - `mmc_controller`: SD/eMMC 5.1 host controller supporting 1-bit, 4-bit, and 8-bit bus widths.
  - `qspi_controller`: Quad-SPI flash memory controller for external NOR flash execution.
- **Video & Imaging Subsystem**:
  - `mipi_csi2_rx`: 4-lane MIPI CSI-2 camera receiver with D-PHY interface.
  - `isp_pipeline`: Image Signal Processing pipeline with demosaicing, gamma correction, white balance, and colorspace conversion.
  - `vdma`: Video Direct Memory Access engine for circular frame buffering.
  - `hdmi_ctrl`: HDMI/DVI transmitter with TMDS encoder and video timing generator.
- **Industrial Peripherals**:
  - `uart_16550`: 5x standard 16550-compatible UARTs with 16-byte FIFO buffers.
  - `spi_master`: High-speed serial peripheral interface master.
  - `i2c_master`: Standard/Fast-mode I2C bus controller.
  - `can_controller`: 2x CAN 2.0B / CAN-FD automotive controllers.
  - `gpio_ctrl`: 32-bit configurable General Purpose Input/Output with interrupt masking.
  - `watchdog_timer`: Windowed safety watchdog timer with programmable timeout reset.
  - `rtc`: Real-Time Clock with millisecond resolution and alarm wakeup.
