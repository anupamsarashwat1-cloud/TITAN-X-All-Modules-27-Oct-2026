# SMVDU TITAN-X SoC — Memory Map & Addressing Architecture
**Phase 1 Architectural Baseline & Independent Principal SoC Audit**  
**Canonical Repository Baseline:** `TITAN-X-2026-11-04` (`af13cba6bc3bc97b8e0fb4a81badc3f742088821`)  
**Design Authority:** Independent Principal SoC Architect & RTL Design Reviewer  

---

## 1. Addressing Architectural Overview

- **Physical Address Width:** **40 bits** (`AW=40`), representing a 1 Terabyte addressable space ($2^{40}$ bytes).
- **Virtual Addressing Status:** **UNINTEGRATED / UNUSED**. While Sv39 modules (`rv_mmu.v`, `rv_ptw.v`, `rv_tlb.v`) exist in `backend/`, neither `rv_core_top` nor `rv_monitor_core` instantiates them. In `titan_x_top.v:823`, `mmu_ptw_arvalid` is tied to `5'b0`. Cores operate strictly with physical addressing.
- **Data Bus Width:** **64 bits** (`DW=64`) native on the AXI4 Crossbar fabric; 32 bits on the downstream AHB/APB peripheral buses.

---

## 2. Global Physical Memory Map (40-Bit AXI4 Space)

The AXI4 Crossbar (`axi4_crossbar.v:113-127`) decodes the 40-bit address space into 9 slave apertures:

| Slave ID | Address Range (Hexadecimal) | Window Size | Subsystem / Target Destination | Protocol | Access Permissions | Implementation Notes & Evidence |
| :---: | :--- | :--- | :--- | :---: | :---: | :--- |
| **S0** | `0x00_8000_0000` – `0x00_FFFF_FFFF` | 2.0 GB | **DDR4 SDRAM Controller Subsystem** (via L2 Cache) | AXI4-Lite | R / W / X | `top/titan_x_top/titan_x_top.v:546`, `axi4_crossbar.v:116` (`addr[39:31] == 9'h001`) |
| **S1** | `0x00_4000_0000` – `0x00_4FFF_FFFF` | 256 MB | **APB Peripheral Subsystem** (Primary Aperture) | AHB-Lite / APB | R / W | `top/titan_x_top/titan_x_top.v:622`, `axi4_crossbar.v:117` (`addr[39:28] == 12'h004`) |
| **S1** | `0x00_2000_0000` – `0x00_2FFF_FFFF` | 256 MB | **Security Peripherals Alias Window** | AHB-Lite / APB | R / W | `axi4_crossbar.v:118` (`addr[39:28] == 12'h002`) routed to S1 |
| **S1** | `0x00_3000_0000` – `0x00_3FFF_FFFF` | 256 MB | **CAN Peripherals Alias Window** | AHB-Lite / APB | R / W | `axi4_crossbar.v:119` (`addr[39:28] == 12'h003`) routed to S1 |
| **S1** | `0x00_0C00_0000` – `0x00_0CFF_FFFF` | 16 MB | **Platform-Level Interrupt Controller (PLIC)** | AHB-Lite / APB | R / W | Standard RISC-V PLIC aperture (`axi4_crossbar.v:120`) |
| **S1** | `0x00_0200_0000` – `0x00_02FF_FFFF` | 16 MB | **Core-Local Interruptor (CLINT)** | AHB-Lite / APB | R / W | Standard RISC-V CLINT aperture (`axi4_crossbar.v:121`) |
| **S2** | `0x00_1000_0000` – `0x00_1FFF_FFFF` | 256 MB | **Boot ROM (`axi_rom.v`)** | AXI4-Lite | R / X (RO) | `top/titan_x_top/titan_x_top.v:346`, mapped to `firmware.hex` |
| **S3** | `0x00_0000_0000` – `0x00_0FFF_FFFF` | 256 MB | **Low Memory / Internal SRAM Window** | AXI4-Lite | Returns DECERR | `top/titan_x_top/titan_x_top.v:301-338`, tied off to DECERR responder |
| **S4–S8**| Unmapped High Windows | N/A | **Unused Peripheral Expansion Slaves** | AXI4-Lite | Returns DECERR | `top/titan_x_top/titan_x_top.v:301-338`, tied off to DECERR responder |
| **—** | All other unmapped addresses | N/A | **Unmapped Address Space** | AXI4 | Returns DECERR | `axi4_crossbar.v:125` (`T_UNMAPPED`), returns `2'b11` DECERR |

---

## 3. APB Peripheral Subsystem Address Map

Decoded combinationally in `titan_x_top.v:646-678` from the AHB bridge output:

| Peripheral Name | Primary Base Address | Legacy / Secondary Aliases | Aperture Size | Registers & Functionality | Critical Architectural Defect / Finding |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **UART 0** | `0x4000_0000` | `0x4001_0000` (!), `0x1000_0000` | 4 KB | 16550 Serial Console (TX, RX, IER, IIR, FCR, LCR, LSR) | **DEF-ARCH-01:** `paddr[31:16] == 16'h4001` mask collides with all `0x4001_xxxx` slaves! |
| **UART 1** | `0x4000_1000` | `0x1000_1000` | 4 KB | 16550 Serial Port 1 | Normal access via `0x4000_1000` |
| **UART 2** | `0x4000_2000` | `0x1000_2000` | 4 KB | 16550 Serial Port 2 | Normal access via `0x4000_2000` |
| **UART 3** | `0x4000_3000` | `0x1000_3000` | 4 KB | 16550 Serial Port 3 | Normal access via `0x4000_3000` |
| **UART 4** | `0x4000_4000` | `0x1000_4000` | 4 KB | 16550 Serial Port 4 | Normal access via `0x4000_4000` |
| **RTC** | `0x4001_0000` | `0x1001_0000`, `0x4002_0000` | 4 KB | Real-Time Clock counter, alarm, and control | Masked by UART0 at `0x4001_0000`; accessible via `0x4002_0000` |
| **GPIO** | `0x4001_1000` | None | 4 KB | 32-bit Direction, Data, Interrupt Enable/Status | **COLLISION:** Overlapped by UART0. Writes hit both; reads return UART0! |
| **Watchdog Timer**| `0x4001_2000` | None | 4 KB | WDT Counter, Reload, Control, Status | **COLLISION:** Overlapped by UART0. Writes hit both; reads return UART0! |
| **SPI Master** | `0x4001_3000` | None | 4 KB | SPI Control, Status, TX/RX Data, Clock Div | **COLLISION:** Overlapped by UART0. Writes hit both; reads return UART0! |
| **I2C Master** | `0x4001_4000` | None | 4 KB | I2C Prescaler, Control, TX/RX, Command/Status | **COLLISION:** Overlapped by UART0. Writes hit both; reads return UART0! |
| **CLINT (Alias)** | `0x4001_5000` | `0x0200_0000` (Standard) | 64 KB | `mtime`, `mtimecmp[0..4]`, `msip[0..4]` | Overlapped at `0x4001_5000`; accessible via `0x0200_0000` |
| **SD/MMC Host** | `0x4001_6000` | None | 4 KB | MMC Argument, Command, Resp, Buffer, DMA | **COLLISION:** Overlapped by UART0. Writes hit both; reads return UART0! |
| **QSPI Flash** | `0x4001_7000` | None | 4 KB | QSPI Mode, Control, Chip Select, Flash Cmd | **COLLISION:** Overlapped by UART0. Writes hit both; reads return UART0! |
| **Video DMA** | `0x4001_8000` | None | 4 KB | VDMA Control, Framebuffer Addr, Stride, Sync | **COLLISION:** Overlapped by UART0. Writes hit both; reads return UART0! |
| **Ethernet MAC** | `0x4002_0000` | `0x1002_0000` | 4 KB | GEM Network Control, Config, DMA Descriptors | Normal access |
| **USB 2.0 OTG** | `0x4003_0000` | `0x1003_0000` | 4 KB | USB Control, Endpoint Regs, Status, DMA | Normal access |
| **MIPI CSI-2 RX** | `0x4004_0000` | `0x1004_0000` | 4 KB | CSI-2 Lane Enable, Packet Count, Status | Normal access |
| **ISP Pipeline** | `0x4005_0000` | `0x1005_0000` | 4 KB | Gamma, Demosaic, Color Matrix, Exposure | Normal access |
| **HDMI Transmit** | `0x4006_0000` | `0x1006_0000` | 4 KB | Timing Generator, Video Mode, Audio, PHY | Normal access |
| **DRBG** | `0x4007_0000` | `0x2000_0000` | 4 KB | NIST SP 800-90A Entropy, Instantiate, Reseed | Normal access |
| **AES-256** | `0x4008_0000` | `0x2001_0000` | 4 KB | 128/256 Key, IV, Control, Status, Block In/Out | Normal access |
| **eNVM Controller**| `0x4009_0000` | `0x2002_0000` | 4 KB | eNVM Macro Timing, Control, Status | Normal access |
| **Secure Boot** | `0x400A_0000` | `0x2003_0000` | 4 KB | RoT Control, Telemetry, Key Hash, Status | Normal access |
| **CAN 0** | `0x400B_0000` | `0x3000_0000` | 4 KB | CAN Mode, Command, Status, Acceptance Filter | Normal access |
| **CAN 1** | `0x400C_0000` | `0x3000_1000` | 4 KB | CAN Mode, Command, Status, Acceptance Filter | Normal access |
| **TRNG** | `0x400D_0000` | `0x2004_0000` | 4 KB | Ring Oscillator Sample, Entropy Valid, Seed | Normal access |
| **SHA-256** | `0x400E_0000` | `0x2005_0000` | 4 KB | Message Block In, Digest Out, Control, Status | Normal access |
| **ECDSA P-256** | `0x400F_0000` | `0x2006_0000` | 4 KB | Curve Points, Digest, Signature r/s, Status | Normal access |
| **Interconnect MPU**| `0x4010_0000`| None | 64 KB | 16x Region Base, Limit, Master Mask, Perm | `top/titan_x_top/titan_x_top.v:675` (`16'h4010`) |
| **QoS Controller**| `0x4011_0000` | None | 64 KB | Bandwidth Limit, Boost QoS, Time Window | `top/titan_x_top/titan_x_top.v:676` (`16'h4011`) |
| **PLIC** | `0x0C00_0000` | `0x40D0_0000` | 16 MB | Interrupt Priorities, Pending, Enables, Thresholds | Standard RISC-V PLIC register map (`plic.v:152`) |

---

## 4. Cache Geometry & Independent Capacity Calculations

All cache capacities are derived strictly from elaborated RTL parameters and register array dimensions:

### 4.1 L1 Instruction Cache (`rv_icache.v`)
- **Parameter Sources:** `params.vh:41-43`
  - Number of Ways (`WAYS`): $8$
  - Number of Sets (`SETS`): $64$
  - Line Size (`LINE_BYTES`): $64\text{ bytes}$ (8 beats of 64-bit words)
- **Tag / Index / Offset Breakdown (40-bit Address):**
  - Offset Bits: $\log_2(64) = 6\text{ bits}$ (`[5:0]`)
  - Index Bits: $\log_2(64) = 6\text{ bits}$ (`[11:6]`)
  - Tag Bits: $40 - 6 - 6 = 28\text{ bits}$ (`[39:12]`)
- **Capacity Formula:**
  $$\text{Capacity}_{\text{L1-I}} = \text{WAYS} \times \text{SETS} \times \text{LINE\_BYTES} = 8 \times 64 \times 64 = \mathbf{32,768\text{ bytes (32 KB per core)}}$$
- **Total L1-I Capacity Across 4 Application Cores:** $4 \times 32\text{ KB} = \mathbf{128\text{ KB}}$.

### 4.2 L1 Data Cache (`rv_dcache.v`)
- **Parameter Sources:** `params.vh:44-46`
  - Number of Ways (`WAYS`): $8$
  - Number of Sets (`SETS`): $64$
  - Line Size (`LINE_BYTES`): $64\text{ bytes}$ (8 beats of 64-bit words)
- **Tag / Index / Offset Breakdown (40-bit Address):**
  - Offset Bits: $\log_2(64) = 6\text{ bits}$ (`[5:0]`)
  - Index Bits: $\log_2(64) = 6\text{ bits}$ (`[11:6]`)
  - Tag Bits: $40 - 6 - 6 = 28\text{ bits}$ (`[39:12]`)
- **Capacity Formula:**
  $$\text{Capacity}_{\text{L1-D}} = \text{WAYS} \times \text{SETS} \times \text{LINE\_BYTES} = 8 \times 64 \times 64 = \mathbf{32,768\text{ bytes (32 KB per core)}}$$
- **Total L1-D Capacity Across 4 Application Cores:** $4 \times 32\text{ KB} = \mathbf{128\text{ KB}}$.

### 4.3 Shared Level 2 Unified Cache (`l2_cache_ctrl.v`)
- **Parameter Sources:** `l2_cache_ctrl.v:8-13`, `l2_cache_top.v:8-9`
  - Number of Ways (`WAYS`): $16$
  - Number of Sets (`SETS`): $64$ (Default parameter, no override in `titan_x_top.v:542`)
  - Line Size (`OFF_W=6`): $64\text{ bytes}$ (8 beats of 64-bit words)
  - Data Width (`DATA_W`): $64\text{ bits}$
- **Tag / Index / Offset Breakdown (40-bit Address):**
  - Offset Bits: $6\text{ bits}$ (`[5:0]`)
  - Index Bits: $6\text{ bits}$ (`[11:6]`)
  - Tag Bits: $40 - 6 - 6 = 28\text{ bits}$ (`[39:12]`)
- **RTL Storage Verification:**
  - `reg [TAG_W-1:0] tag_mem [0:SETS-1][0:WAYS-1];` $\rightarrow 64 \times 16 \times 28\text{ bits} = 28,672\text{ bits}$.
  - `reg [DATA_W-1:0] data_mem [0:SETS-1][0:WAYS-1][0:7];` $\rightarrow 64 \times 16 \times 8 \times 64\text{ bits} = 524,288\text{ bits} = 65,536\text{ bytes}$.
- **Actual Capacity Formula:**
  $$\text{Capacity}_{\text{L2 Actual}} = \text{WAYS} \times \text{SETS} \times 64\text{ bytes} = 16 \times 64 \times 64 = \mathbf{65,536\text{ bytes (64 KB)}}$$
- **Audit Discrepancy Note:** While `params.vh:57` declares `L2_SETS = 2048` (intended 2 MB), the synthesized hardware implements **64 KB**.

---

## 5. DMA Master Address Paths

Each high-speed DMA master in the SoC drives a dedicated master port on the AXI4 Crossbar:

| DMA Master Module | Crossbar Master Port | Driven Address Range | Target Slaves | Access Purpose | Backpressure & Flow Control |
| :--- | :---: | :--- | :--- | :--- | :--- |
| **`gem_ethernet`** | **M10** | Any within 40-bit space (typically DDR4 `0x8000_0000+`) | S0 (DDR), S1 (Buffers) | Ethernet RX packet DMA into RAM; TX packet streaming from RAM | Standard AXI4 `awready`, `wready`, `arready` |
| **`pcie_top`** | **M11** | Any within 40-bit space (DDR4 / Peripheral windows) | S0 (DDR), S1 (Bridge) | Inbound PCIe DMA Reads/Writes; Outbound Host Memory Access | Standard AXI4 `awready`, `wready`, `arready` |
| **`usb_otg`** | **M12** | Any within 40-bit space (DDR4 `0x8000_0000+`) | S0 (DDR) | USB 2.0 Packet DMA Buffer transfers | Standard AXI4 `awready`, `wready`, `arready` |
| **`mmc_controller`**| **M13** | Any within 40-bit space (DDR4 `0x8000_0000+`) | S0 (DDR) | SD Card Block read/write DMA | Standard AXI4 `awready`, `wready`, `arready` |
| **`vdma`** | **M14** | Framebuffer window (DDR4 `0x8000_0000+`) | S0 (DDR) | Video frame streaming to display or ISP | Standard AXI4 `awready`, `wready`, `arready` |

---
