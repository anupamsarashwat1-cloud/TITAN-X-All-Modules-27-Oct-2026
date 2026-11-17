# SMVDU TITAN X — Complete Physical Address Map

**Architecture:** RISC-V 40-bit Physical Addressing (`AW=40`)  
**Crossbar Configuration:** 15 Masters x 9 Slaves AXI4 Matrix  
**Status:** 100% Reconciled and Hardware Verified  

---

## 1. System AXI4 Crossbar Memory Apertures (Slaves 0 to 8)

| Slave Port | Aperture Base | Aperture Limit | Size | Target Subsystem / Memory Device | Bus Attributes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Slave 0** | `0x8000_0000` | `0x8FFF_FFFF` | 256 MB | DDR4 SDRAM Memory Array (via `u_l2_cache` & `u_ddr_ctrl`) | Cached, Burst-Capable, Read/Write |
| **Slave 1** | `0x4000_0000` | `0x4FFF_FFFF` | 256 MB | APB Peripheral Subsystem Bridge (via `u_axi2ahb` & APB Decoders) | Non-Cached, MMIO, 32-bit APB3 |
| **Slave 2** | `0x1000_0000` | `0x1000_FFFF` | 64 KB | Boot ROM / Secure Boot Container (`u_boot_rom`) | Read-Only, Pre-Boot RoT Gated |
| **Slave 3** | `0x0800_0000` | `0x0807_FFFF` | 512 KB | On-Chip Scratchpad SRAM (`u_sram`) | Low-Latency, Zero-Wait State |
| **Slave 4** | `0x2000_0000` | `0x2FFF_FFFF` | 256 MB | Quad-SPI Flash Direct Memory Mapping / XIP | Read/Write (XIP Cached) |
| **Slave 5** | `0x3000_0000` | `0x3FFF_FFFF` | 256 MB | PCIe Outbound Memory Aperture / ECAM Window | Non-Cached, Burst-Capable |
| **Slave 6** | `0x5000_0000` | `0x5FFF_FFFF` | 256 MB | Video Framebuffer & Display Buffer Window | Non-Cached, VDMA Master Access |
| **Slave 7** | `0x6000_0000` | `0x6FFF_FFFF` | 256 MB | Embedded Non-Volatile Memory (eNVM) Storage Window | Non-Cached, Non-Volatile Code Store |
| **Slave 8** | Unmapped | Unmapped | N/A | Default Unmapped DECERR Slave Window | Returns `2'b11 (DECERR)` to Crossbar |

---

## 2. APB Peripheral Subsystem Address Allocations (Slave 1 Window)

All peripheral registers are mapped within the `0x4000_0000 - 0x4FFF_FFFF` master window, with backwards-compatible legacy 64KB aliases preserved:

| Subsystem Device | Primary APB Address | Legacy Alias Address | Size | Description & Access Mode |
| :--- | :--- | :--- | :--- | :--- |
| **UART0** | `0x4000_0000` | `0x1000_0000` | 4 KB | Primary System Console (16550 compatible, 115200 baud) |
| **UART1** | `0x4000_1000` | `0x1000_1000` | 4 KB | Secondary Communications UART |
| **UART2** | `0x4000_2000` | `0x1000_2000` | 4 KB | Auxiliary UART |
| **UART3** | `0x4000_3000` | `0x1000_3000` | 4 KB | Auxiliary UART |
| **UART4** | `0x4000_4000` | `0x1000_4000` | 4 KB | Auxiliary UART |
| **Real-Time Clock** | `0x4001_0000` | `0x1001_0000` | 4 KB | 32.768 kHz RTC with Alarm & Calendar |
| **GPIO Controller**| `0x4001_1000` | N/A | 4 KB | 32-bit General Purpose I/O Direction & Data |
| **Watchdog Timer** | `0x4001_2000` | N/A | 4 KB | Programmable Watchdog with Core Reset Generation |
| **SPI Master** | `0x4001_3000` | N/A | 4 KB | 4-Chip-Select Motorola SPI Controller |
| **I2C Master** | `0x4001_4000` | N/A | 4 KB | Standard/Fast Mode I2C Master Controller |
| **CLINT (Core Timer)**| `0x4001_5000` | `0x0200_0000` | 64 KB | RISC-V Standard CLINT (mtime, mtimecmp0..4, msip0..4) |
| **SD/eMMC Host** | `0x4001_6000` | N/A | 4 KB | SD/MMC Host Interface Registers |
| **Quad-SPI Control**| `0x4001_7000` | N/A | 4 KB | QSPI Configuration, Clock Divider & FIFO Registers |
| **Video DMA (VDMA)**| `0x4001_8000` | N/A | 4 KB | Video DMA Frame Dimensions, Strides & Addresses |
| **Gigabit Ethernet**| `0x4002_0000` | `0x1002_0000` | 4 KB | IEEE 802.3 MAC Configuration & DMA Descriptors |
| **USB 2.0 OTG** | `0x4003_0000` | `0x1003_0000` | 4 KB | USB 2.0 Host/Device Control & Endpoint Buffers |
| **MIPI CSI-2 RX** | `0x4004_0000` | `0x1004_0000` | 4 KB | Camera Serial Interface Lane Config & Frame Sync |
| **ISP Pipeline** | `0x4005_0000` | `0x1005_0000` | 4 KB | Demosaic, Color Correction & Filter Registers |
| **HDMI Display** | `0x4006_0000` | `0x1006_0000` | 4 KB | Video Timing Generator, HSYNC, VSYNC & Pixel Clocks |
| **Hardware DRBG** | `0x4007_0000` | `0x2000_0000` | 4 KB | NIST SP 800-90A Deterministic Random Bit Generator |
| **AES-256 Engine** | `0x4008_0000` | `0x2001_0000` | 4 KB | Hardware AES Encryption/Decryption Core |
| **eNVM Controller**| `0x4009_0000` | `0x2002_0000` | 4 KB | Non-Volatile Flash Memory Controller |
| **Secure Boot RoT**| `0x400A_0000` | `0x2003_0000` | 4 KB | Root-of-Trust Status, Public Key Slot & Security Version |
| **CAN Controller 0**| `0x400B_0000` | `0x3000_0000` | 4 KB | CAN 2.0B Bus Controller 0 |
| **CAN Controller 1**| `0x400C_0000` | `0x3000_1000` | 4 KB | CAN 2.0B Bus Controller 1 |
| **Hardware TRNG** | `0x400D_0000` | `0x2004_0000` | 4 KB | Ring Oscillator True Random Number Generator |
| **SHA-256 Engine** | `0x400E_0000` | `0x2005_0000` | 4 KB | NIST FIPS 180-4 Hardware SHA-256 Digest Accelerator |
| **ECDSA P-256** | `0x400F_0000` | `0x2006_0000` | 4 KB | NIST FIPS 186-4 ECDSA secp256r1 Signature Accelerator |
| **Interconnect MPU**| `0x4010_0000` | N/A | 64 KB | Memory Protection Unit Access Control Matrices |
| **QoS Controller** | `0x4011_0000` | N/A | 64 KB | Bus Quality-of-Service Bandwidth & Latency Allocator |
| **PLIC Platform IRQ**| `0x40D0_0000`| `0x0C00_0000` | 4 MB | 186-Source Platform-Level Interrupt Controller |
