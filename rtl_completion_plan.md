# SMVDU Titan-X SoC — RTL Completion Plan for ASIC Tapeout (SCL 180nm)

> **Goal:** Bring the current behavioral skeleton RTL to a complete, specification-compliant, synthesis-clean,  
> physically-implementable SoC delivering all capabilities defined in your specification sheet.

---

## Executive Summary

The existing RTL provides a correct structural skeleton (file hierarchy, bus interfaces, and simulation harness) but fails on **every functional specification** — the cores lack the required ISA extensions, the cache system is undersized by 4,000×, nine peripheral/subsystem modules are entirely absent, and the system interconnect does not scale to the required 15M × 9S. The plan below addresses each gap with concrete engineering actions, new files to be created, and existing files to be refactored.

---

## Phase 0 — Infrastructure & Parameter Updates (Day 1)

These changes must happen first as everything else depends on them.

### [MODIFY] `common/params.vh`
Update all global parameters to match the specification:

```verilog
`define XLEN              64
`define NUM_APP_HARTS     4      // RV64GC application cores
`define NUM_MON_HARTS     1      // RV64IMAC monitor core
`define NUM_HARTS         5

`define AXI_ADDR_WIDTH    40    // 38-bit physical → padded to 40-bit AXI
`define AXI_DATA_WIDTH    64
`define AXI_ID_WIDTH      8     // Wider ID for 15-master crossbar

`define NUM_PLIC_SOURCES  186
`define NUM_PLIC_TARGETS  10

// L1 Cache parameters
`define L1I_WAYS          8
`define L1I_SETS          64    // 8-way × 64-sets × 64B line = 32KB I-Cache
`define L1D_WAYS          8
`define L1D_SETS          64    // 8-way × 64-sets × 64B line = 32KB D-Cache

// L2 Cache parameters
`define L2_WAYS           16
`define L2_SETS           2048  // 16-way × 2048-sets × 64B line = 2MB
`define L2_BANKS          4     // 4 × 512KB SRAM banks for layout distribution

// MMU
`define SV39              1
`define VADDR_WIDTH       39
`define PADDR_WIDTH       38
```

### [NEW] `common/isa_pkg.vh`
Centralized definitions for all RISC-V ISA opcodes, funct3/funct7 encodings for M, A, F, D, C extensions and CSR addresses for Sv39 (satp, stvec, sepc, scause, stval).

---

## Phase 1 — CPU Core Complex (Highest Priority)

### 1.1 Upgrade Application Cores (Harts 0–3) to RV64GC

All four application cores must be upgraded from the current `rv_core_top.v` (RV64I, 5-stage, no cache) to a full **RV64GC** pipeline. This is the largest single body of work.

#### [MODIFY] `backend/rv_execute.v` — Add M-Extension (Multiply/Divide)
The ALU currently only handles the 12 basic integer operations. Add:
- **MUL/MULH/MULHSU/MULHU**: 64×64 → 64-bit multiplier. Implement as a **2-cycle pipelined array multiplier** (combinational on 180nm is too slow for 200MHz timing).
- **DIV/DIVU/REM/REMU**: Use a **non-restoring radix-2 divider** with a 64-cycle iteration counter. Assert a `mul_div_stall` output to the hazard unit while in progress.

#### [MODIFY] `backend/rv_execute.v` — Add A-Extension (Atomics)
RISC-V atomics (LR/SC, AMO-ADD/AND/OR/XOR/SWAP/MIN/MAX) require a **reservation set register** (`lr_addr`, `lr_valid`) in the execute stage and exclusive access signaling on the AXI bus (`AxLOCK`). Extend the memory stage handshake accordingly.

#### [NEW] `backend/rv_fpu.v` — Floating Point Unit (IEEE 754-2008)
This is a separate module, pipelined and instantiated in `rv_core_top.v` alongside the ALU. Required operations per the F and D extensions:
- **FADD/FSUB/FMUL/FDIV** (single and double precision)
- **FMA (Fused Multiply-Add)** — critical for performance
- **FCVT** (float↔int conversions), **FSQRT**, **FCMP**, **FMIN/FMAX**
- **Rounding modes**: RNE, RTZ, RDN, RUP, RMM — controlled by CSR `frm`
- **Exception flags**: NX, UF, OF, DZ, NV — written to CSR `fflags`
- Implement as a **4-stage pipeline** (unpack → compute → normalize → pack)

> **RTL Strategy**: Use a parameterized significand width to share hardware between SP (24-bit mantissa) and DP (53-bit mantissa) paths. The 180nm target makes a shared FPU the right area trade-off.

#### [NEW] `frontend/rv_bpu.v` — Branch Prediction Unit
Replace the current flush-on-execute penalty (2 wasted cycles per branch) with a proper predictor:
- **Local History Table**: 2-bit saturating counter per PC (2K entries, 11-bit index)
- **Global History Register (GHR)**: 12-bit shift register for Gshare
- **Gshare predictor**: XOR of PC[12:1] and GHR → 4K saturating counter table
- **Tournament meta-predictor**: Select between local and global predictions
- **BTB (Branch Target Buffer)**: 512-entry direct-mapped, stores resolved target address
- The BPU operates in the **fetch stage**, providing a predicted PC every cycle
- Misprediction correction path already exists (branch_taken/branch_target from execute)

#### [NEW] `backend/rv_mmu.v` — Sv39 Memory Management Unit
The MMU sits between the pipeline and the L1 caches, performing virtual-to-physical address translation:

```
Architecture: Sv39 — 3-level page table
  VPN[2](9b) → VPN[1](9b) → VPN[0](9b) → PPN(44b) + offset(12b)
  Physical address = {PPN[37:0], VOffset[11:0]}
```

Modules required:
- **`rv_mmu.v`**: Top-level. Manages SATP CSR, mode (Bare/Sv39), ASID
- **`rv_tlb.v`**: 32-entry, 4-way set-associative, ASID-tagged TLB. Shared between I and D, or split 16+16 (preferred)
- **`rv_ptw.v`**: Page Table Walker. AXI4 master on a dedicated low-priority port to the crossbar. Performs 3 sequential memory reads for a page walk. Raises page faults (instruction/load/store) via trap interface

The MMU intercepts all memory requests from the fetch and memory stages and either delivers a translated PPN immediately (TLB hit) or initiates a page walk (TLB miss).

#### [MODIFY] `backend/rv_core_top.v` — Integrate New Units
Wire the FPU, BPU, and MMU into the existing 5-stage pipeline:
- Add `u_fpu` (rv_fpu) instance and FPU scoreboard for WAW/RAW hazards on FP registers
- Add `u_bpu` (rv_bpu) instance driven from fetch stage
- Add `u_immu`/`u_dmmu` (rv_mmu) instances in front of the existing AXI interfaces
- Add CSR file for Sv39 (`satp`, `stvec`, `sepc`, `sscratch`, `scause`, `stval`, `sstatus`)
- Add `u_pmp` (Physical Memory Protection) checker module — 8 PMP entries per hart

### 1.2 Upgrade Monitor Core (Hart 4) to RV64IMAC

The monitor core (`rv_core_top #(.HART_ID(4))`) must be differentiated from the app cores. Options:
- **Preferred approach**: Create `rv_monitor_core.v` — a stripped-down RV64IMAC variant with no FPU, no BPU, and a DTIM (Tightly Integrated Memory) instead of a D-Cache
- **DTIM**: 8 KB SRAM block (`sram_8kx8_180nm.v`) directly connected to the monitor core's data port, mapping to a fixed physical address range (e.g., `0x0180_0000 – 0x0181_FFFF`)
- **I-Cache**: 16 KB, 4-way, for the monitor core (can reuse `rv_icache.v` with smaller parameters)

### 1.3 Add L1 Caches (Per Core)

The cores currently bypass caching entirely — instruction and data memory is driven straight to AXI. Insert caches between each core and the crossbar.

#### [NEW] `frontend/rv_icache.v` — 32KB, 8-Way I-Cache with SECDED ECC
```
- 64-set, 8-way, 64B cache line (cacheline = 8 × 64-bit words)
- VIPT (Virtually-Indexed, Physically-Tagged) — index from VA, tag from PA after MMU
- Replacement: PLRU (Pseudo-LRU) per set
- SECDED: Generate 8 ECC bits per 64-bit word (Hsiao code). On scrub: correct 1-bit, signal 2-bit
- AXI4 refill master: 8-beat burst (ARLEN=7) to L2 on a miss
- Tag SRAM: sram_128x40_180nm (128 sets × 40-bit [valid+ECC+tag])
- Data SRAM: sram_128x512_180nm (128 sets × 8-way × 64B)
```

#### [NEW] `backend/rv_dcache.v` — 32KB, 8-Way D-Cache with SECDED ECC
```
- Same geometry as I-Cache (64-set, 8-way, 64B line)
- Write policy: Write-Back, Write-Allocate
- Coherence interface: Provides snoop request/response ports for L2 directory
- Atomic support: Reserves cache line on LR, cancels on SC miss or snoop
- MSHR (Miss Status Holding Register): 4 entries for non-blocking cache operation
- SECDED: Same Hsiao code as I-Cache
- AXI4 master: 8-beat refill bursts + dirty eviction write bursts
```

### 1.4 Add JTAG Debug Module

#### [NEW] `backend/rv_debug.v` — JTAG Debug Module (Spec 0.13)
```
- 4-pin JTAG TAP (TCK, TMS, TDI, TDO)
- Debug Module Interface (DMI) registers: dmstatus, dmcontrol, hartinfo
- Abstract Commands: Access register, Quick Access, Access memory
- Program Buffer: 16-instruction scratch pad for complex debug sequences
- Hardware triggers: 4 triggers per hart (breakpoint, watchpoint, icount)
- System Bus Access: AXI4 master for direct memory inspection without halting
```

---

## Phase 2 — Memory Subsystem

### 2.1 Rebuild L2 Cache to Specification (2MB, 16-way)

The current L2 is undersized by 4000×. Complete rewrite required.

#### [MODIFY] `memory/l2_cache_top.v` — Restructure with 4 Banks

```
Target: 2MB unified L2
  - 16-way set-associative
  - 2048 sets (64B line × 2048 × 16 = 2MB)
  - Banked: 4 × 512KB SRAM banks (for floorplan distribution in Innovus)
  - Directory-based coherence (respond to snoop requests from L1 D-Caches)
  - LIM mode: Software-reconfigurable; selected ways can be repurposed as flat SRAM
```

Submodule restructure:
- **`l2_cache_ctrl.v`**: Upgrade to handle 16-way PLRU replacement, snoop filter, and LIM allocation
- **`l2_tag_array.v`**: Scale to 2048 sets × 16 ways. Each tag entry: `[valid(1) + dirty(1) + MESI_state(2) + ASID(16) + tag(28)]` = 48 bits
- **`l2_data_array.v`**: Instantiate 4 × `sram_512kx8_180nm.v` (or equivalent banked structure)
- **`l2_snoop_filter.v`** [NEW]: Tracks which L1 holds which cache line for directory-based coherence. Implements MESI state machine.

#### [NEW] `memory/sram_512kx8_180nm.v` — 512KB SRAM Macro
Custom SRAM model for the SCL 180nm node. Will be replaced by the foundry hard macro during physical implementation. RTL model uses synchronous read for simulation accuracy.

### 2.2 Upgrade DDR Controller

The current DDR controller is functionally correct but has no burst capability. For LPDDR4 compatibility and real-world bandwidth, upgrade:

#### [MODIFY] `memory/ddr_ctrl_top.v`
- Support `AWLEN/ARLEN` up to 15 (16-beat bursts) — critical for cache line fills
- Add **refresh timer**: Issue `REF` commands every 7.8µs (standard DDR4 tREFI)
- Add **write leveling** and **read eye training** CSR registers (for DDR PHY bring-up)
- Add LPDDR4 command set support (MR read/write, enter/exit power-down states)

---

## Phase 3 — System Interconnect

### 3.1 Scale Crossbar to 15-Master × 9-Slave

This is a critical structural change. The current 5M × 8S crossbar must be redesigned.

#### [MODIFY] `interconnect/axi4_crossbar.v` — 15M × 9S with Full Arbitration

**New Master list (15 total):**
| Port | Master | Notes |
|------|--------|-------|
| M0–M3 | App Core 0–3 D-Cache | AXI4 with LOCK for atomics |
| M4 | Monitor Core | AXI4-Lite |
| M5–M8 | App Core 0–3 I-Cache refill | Separate read-only ports |
| M9 | Monitor I-Cache refill | Read-only |
| M10 | PCIe DMA | Needs QoS HIGH |
| M11 | GEM0 DMA | Needs QoS MEDIUM |
| M12 | GEM1 DMA | Needs QoS MEDIUM |
| M13 | VDMA (Video) | Needs QoS HIGH for display |
| M14 | USB/eMMC DMA | Needs QoS MEDIUM |

**New Slave list (9 total):**
| Port | Slave | Address Range |
|------|-------|---------------|
| S0 | L2 Cache | `0x0000_0000 – 0x0FFF_FFFF` |
| S1 | DDR4/LPDDR4 | `0x8000_0000 – 0xFFFF_FFFF` |
| S2 | PCIe BAR space | `0x1000_0000 – 0x1FFF_FFFF` |
| S3 | GEM0 CSR | `0x2000_0000 – 0x200F_FFFF` |
| S4 | GEM1 CSR | `0x2010_0000 – 0x201F_FFFF` |
| S5 | Video Pipeline | `0x2020_0000 – 0x202F_FFFF` |
| S6 | High-Speed Storage | `0x2030_0000 – 0x203F_FFFF` |
| S7 | APB Peripheral Bridge | `0x4000_0000 – 0x4FFF_FFFF` |
| S8 | Security Subsystem | `0x5000_0000 – 0x5FFF_FFFF` |

**Arbitration upgrade:**
- Replace the current "last-wins" grant loop with a proper **weighted round-robin (WRR)** arbiter per slave
- Add an **outstanding transaction tracker** (4-entry per slave) to prevent AXI ID collision
- Implement proper **AXI ordering rules**: transactions from same master to same slave must be ordered

#### [NEW] `interconnect/qos_controller.v` — QoS Controller
```
- 4-priority-level traffic classes: CRITICAL, HIGH, MEDIUM, LOW
- Per-master priority assignment register (software-programmable via APB CSR)
- Weighted credit counters: ensure LOW-priority masters never starve beyond 256 cycles
- Integration: QoS tag inserted into AXI AxUSER[3:0] bits
```

#### [NEW] `interconnect/mpu.v` — Memory Protection Unit (for non-CPU masters)
```
- 16 protection regions, each with: base_addr, size, master_mask, permission (R/W)
- Applied to DMA masters (PCIe, GEM, VDMA, USB) to prevent DMA attacks
- Raises AXI SLVERR on unauthorized access
```

---

## Phase 4 — High-Speed I/O Subsystem

### 4.1 PCIe Subsystem — Replace Stub with Full Controller

#### [MODIFY] `peripherals/pcie_top.v` — Gen2 x4 Endpoint

> **Note on Gen2 vs Gen3**: The `pcie_top.v` stub comment says Gen3. The specification requires PCIe Gen2. Fix the status register to advertise Gen2 (5GT/s) speed.

The behavioral skeleton must be replaced with:
- **Transaction Layer (TL)**: TLP assembly/disassembly, completion buffer, tag management (32 tags)
- **Data Link Layer (DL)**: DLLP generation, ACK/NAK protocol, replay buffer (4KB)
- **AXI4 DMA master**: Enable the currently tied-off `m_awvalid`/`m_arvalid` outputs for inbound DMA to system memory
- **BAR decoder**: Configurable Base Address Registers (BAR0 = 64MB, BAR1 = 64KB CSR)
- **MSI/MSI-X interrupt controller**: 32 MSI vectors routed to PLIC

**PHY interface:**
```
[NEW] peripherals/pcie_pipe_if.v
  - Implements the PIPE (PHY Interface for PCIe) standard
  - Controls: PowerDown, TxDetectRx, TxElecIdle
  - Data: TxData[31:0], TxDataK[3:0], RxData[31:0], RxDataK[3:0]
  - Status: PhyStatus, RxValid, RxElecIdle
  - In production: This module wraps the hard PCIe PHY macro from SCL/Synopsys
```

### 4.2 Gigabit Ethernet — Add SGMII PCS and Complete Rx Path

#### [MODIFY] `peripherals/gem_ethernet.v` — Complete MAC + DMA

The current implementation has:
- ❌ No Rx packet reception path
- ❌ No descriptor ring DMA (only a hardcoded `tx_dma_base`)
- ❌ No frame checksum (CRC32) generation/verification
- ❌ No SGMII PCS sublayer

Additions:
```
[NEW] peripherals/gem_sgmii_pcs.v
  - 8b/10b encode/decode for SGMII (1.25 Gbps serial)
  - Auto-negotiation state machine (IEEE 802.3z clause 37)
  - SERDES interface → connects to analog SGMII PHY pad
  
[MODIFY] peripherals/gem_ethernet.v additions:
  - TX descriptor ring: AXI4 master reads 16-byte descriptors from memory
  - RX descriptor ring: AXI4 master writes received frames to memory
  - Frame CRC32: combinational CRC generator (for TX) and checker (for RX)
  - Pause frame handling (IEEE 802.3x flow control)
  - Interrupt coalescing: configurable packet-count and timer thresholds
```

### 4.3 Video Pipeline — New Subsystem (Currently 100% Missing)

The entire video pipeline must be created from scratch. This maps to crossbar slave S5.

#### [NEW] `video/mipi_csi2_rx.v` — MIPI CSI-2 Receiver
```
- D-PHY lane interface: 1/2/4 data lanes, clock lane
- Packet deframer: SOF/EOF markers, ECC error detection
- Data type demultiplexer: RAW8/RAW10/RAW12/YUV422
- VC (Virtual Channel) routing: up to 4 virtual channels
- AXI4 Stream output to ISP pipeline
```

#### [NEW] `video/isp_pipeline.v` — Image Signal Processor
```
- De-Bayer filter: 3×3 bilinear interpolation for RAW→RGB
- Black level correction: per-channel offset subtraction
- Gamma correction: 256-entry LUT (programmable via APB)
- Color space conversion: RGB→YUV (BT.601 coefficients, fixed-point 3×3 matrix)
- Input: AXI4-Stream from CSI-2
- Output: AXI4-Stream to VDMA
```

#### [NEW] `video/vdma.v` — Video DMA Controller
```
- Dual-channel: capture (write to memory) and display (read from memory)
- Frame buffers: software-configurable base address and stride
- AXI4 master: 256-beat write bursts for capture, 256-beat read bursts for display
- Sync generation: Vsync, Hsync signals for HDMI timing
- Flow control: Stalls CSI-2 if memory bandwidth is insufficient
```

#### [NEW] `video/hdmi_ctrl.v` — HDMI 1.4 Display Controller
```
- Pixel timing engine: Horizontal/vertical sync, blanking intervals (VESA modes)
- TMDS encoder: 8b/10b encoding for R, G, B data and control channels
- Audio embedding: I2S audio injected into HDMI AUX data packets
- HDCP 1.4: Handshake state machine (keys pre-loaded via secure boot)
- Output: 4 TMDS differential pairs (Clk, D0, D1, D2)
```

### 4.4 High-Speed Storage — New Subsystem (Currently 100% Missing)

Maps to crossbar slave S6.

#### [NEW] `storage/mmc_controller.v` — MMC 5.1 / SD 3.0 / SDIO Controller
```
- eMMC 5.1: HS400 mode (200MHz DDR, 8-bit data bus → 400 MB/s)
- SD 3.0: UHS-I (104 MB/s) with tuning support
- SDIO: SPI and 4-bit SD modes for WiFi/BT modules
- DMA: AXI4 scatter-gather, 512B block transfers
- Command engine: State machine for MMC/SD command protocol (CMD0–CMD55, ACMD)
- Clock divider: Programmable from sysclk (1/2 to 1/512)
```

#### [NEW] `storage/usb_otg.v` — USB 2.0 OTG Controller with ULPI
```
- USB 2.0 High Speed (480 Mbps) / Full Speed (12 Mbps) / Low Speed (1.5 Mbps)
- OTG: Dual-role device, session request protocol (SRP), host negotiation protocol (HNP)
- ULPI interface: 8-bit bidirectional data, ULPI clock (60 MHz), DIR, NXT, STP
- Endpoint FIFOs: 16KB TX + 16KB RX internal SRAM
- DMA: AXI4 master for descriptor-based transfers
- Interrupts: 12 sources, routed to PLIC
```

#### [NEW] `storage/qspi_controller.v` — Quad-SPI Flash with XIP
```
- Single/Dual/Quad SPI modes (up to 4× data pins)
- XIP (Execute In Place): Transparent AXI4-Lite read-only port → no software driver needed for boot
- DDR mode: Double Data Rate Quad SPI for maximum throughput
- Clock phase and polarity (CPOL/CPHA): All 4 SPI modes
- DMA: AXI4 master for bulk read/write with automatic address increment
- Hardware write protection
```

---

## Phase 5 — Low-Speed Peripherals (APB)

### 5.1 Scale UARTs from 2 to 5 (5× MMUART)

#### [MODIFY] `top/titan_x_top.v` — Add uart2, uart3, uart4
The current APB decoder uses `paddr[19:16]` for 4-bit peripheral select, providing 16 slots. Instantiate 3 additional `uart_16550` instances at slots `0x2`, `0x3`, `0x4` and route their Tx/Rx pairs to top-level pins.

**Also upgrade to MMUART (Multi-Mode):**
#### [MODIFY] `peripherals/uart_16550.v` — Add Multi-Mode Support
- Add **LIN bus mode** (Local Interconnect Network): Break detection, sync field, identifier encoding
- Add **IrDA SIR mode**: Pulse-shaping for infrared transceiver compatibility
- Add **9-bit mode**: For industrial RS-485 multi-drop networks
- These modes are selected via a new `MODE_REG[1:0]` CSR register

### 5.2 Scale SPI from 1 to 2 Controllers

#### [MODIFY] `top/titan_x_top.v` — Add spi1
Instantiate a second `spi_master` at APB slot `0x8`. Add `spi1_clk`, `spi1_mosi`, `spi1_miso`, `spi1_csn[3:0]` to top-level port list.

### 5.3 Scale I2C from 1 to 2 Controllers

Same approach: instantiate `i2c1` at APB slot `0x9`.

### 5.4 CAN 2.0B Controllers — New (Currently 100% Missing)

#### [NEW] `peripherals/can_controller.v` — CAN 2.0B Controller
```
- CAN 2.0B: 11-bit and 29-bit identifier frames (standard and extended)
- Bit timing: Programmable prescaler and segment widths (for 1Mbps operation)
- Acceptance filtering: 2 filter banks with mask register
- TX/RX FIFOs: 64 messages each
- Error handling: Passive error, bus-off recovery, error counters
- APB interface: CiA 301 compatible register map
```
Instantiate 2 instances at APB slots `0xA` (can0) and `0xB` (can1).

### 5.5 Real-Time Counter — New (Currently 100% Missing)

#### [NEW] `peripherals/rtc.v` — Real-Time Counter
```
- 48-bit counter clocked by a slow RTC clock input (32.768 kHz)
- Clock domain crossing: async FIFO between RTC clock and APB clock domains (reuse common/fifo_async.v)
- Alarm register with interrupt on match
- APB CSR: {seconds, minutes, hours, day, month, year}
```

### 5.6 Scale Watchdog from 1 to 5

Instantiate 4 additional `watchdog_timer` instances (`u_wdt1`–`u_wdt4`) at APB slots `0x6`–`0x9`. Each watchdog timer expiry generates an independent interrupt to the PLIC and can be configured to trigger a system reset.

---

## Phase 6 — Security & Boot Subsystem

### 6.1 Boot Logic — New (Currently 100% Missing)

#### [NEW] `security/envm_ctrl.v` — 128KB eNVM Controller
```
- Manages an embedded non-volatile memory (OTP or Flash) macro
- AXI4-Lite read-only interface for boot code (mapped to 0x0002_0000 – 0x0003_FFFF)
- Write interface: Programming mode, page erase, word write
- ECC: SECDED on every 64-bit word
- Lock registers: Permanently lock regions after secure boot key provisioning
```

#### [NEW] `security/secure_boot.v` — Secure Boot Authentication Engine
```
- Boot ROM: 4KB hardwired ROM containing the stage-0 boot loader
- Hash chain verification: Computes SHA-256 over the eNVM boot image
- Signature check: Uses the ECDSA engine to verify against a burned public key
- Boot permit register: Locked once authentication passes; CPU is held in reset until permit is set
- Boot failure path: Triggers a board-level reset after N (configurable) failed attempts
```

### 6.2 Upgrade Crypto Subsystem

#### [MODIFY] `peripherals/aes_engine.v` — Add 256-bit Key Expansion
The current AES engine only handles key-independent SubBytes/ShiftRows. Add:
- Full 128-bit and 256-bit key schedule (Rijndael key expansion)
- ECB, CBC, CTR, GCM operation modes
- Hardware GHASH accelerator for GCM authentication tag

#### [NEW] `security/ecdsa_engine.v` — ECDSA Hardware Accelerator
```
- NIST P-256 and P-384 elliptic curves
- Operations: Point multiplication (scalar × point), ECDSA sign, ECDSA verify
- Implements Montgomery ladder for constant-time operation (side-channel resistance)
- Uses shared multiplier with SHA-256 engine for HMAC-DRBG
- APB interface: Load key/signature → trigger → poll done → read result
```

#### [NEW] `security/drbg.v` — HMAC-DRBG (NIST SP 800-90A)
```
- Seeded from TRNG output
- Uses HMAC-SHA256 as the pseudorandom function
- Reseed counter: Forces reseed from TRNG after 2^48 generate calls
- Provides: Cryptographically secure random numbers for key generation, nonces
```

#### [MODIFY] `peripherals/trng.v` — Qualify Entropy Source
The current TRNG is a conceptual placeholder. For a real 180nm ASIC:
- Add **ring oscillator array**: 32 inverter rings with different lengths → frequency jitter as entropy
- Add **Von Neumann post-processor**: Debiases raw bit stream (XOR of adjacent bits)
- Add **online health tests**: NIST SP 800-90B Repetition Count Test and Adaptive Proportion Test
- Add **entropy estimator**: Monitors min-entropy to detect failure of the analog noise source

---

## Phase 7 — Physical Memory Protection (PMP)

#### [NEW] `backend/rv_pmp.v` — Physical Memory Protection
```
- 8 PMP entries per hart (RISC-V Privileged Spec minimum)
- Modes: TOR (Top Of Range), NA4 (Naturally Aligned 4B), NAPOT (Naturally Aligned Power Of Two)
- Permissions: Read, Write, Execute — checked for every memory access
- Locking: L-bit makes entry immutable even for M-mode software
- Placement: Between MMU output and the L1 cache AXI master interface
- Trap: Raises load/store/instruction access fault on PMP violation
```

---

## Phase 8 — Top-Level Integration Updates

### [MODIFY] `top/titan_x_top.v` — Major Restructure

1. **Replace instruction memory stubs** with proper boot ROM connections: Hart PCs reset to `0x0002_0000` (eNVM base)
2. **Add all new top-level ports**:
   - `hdmi_tmds_p/n[3:0]`, `mipi_csi_dp/dn[3:0]`, `mipi_csi_clkp/clkn`
   - `usb_dp`, `usb_dm`, `usb_vbus`, `usb_id`
   - `mmc_clk`, `mmc_cmd`, `mmc_dat[7:0]`
   - `uart2_txd/rxd`, `uart3_txd/rxd`, `uart4_txd/rxd`
   - `spi1_clk`, `spi1_mosi`, `spi1_miso`, `spi1_csn[3:0]`
   - `i2c1_scl`, `i2c1_sda`
   - `can0_tx`, `can0_rx`, `can1_tx`, `can1_rx`
   - `rtc_clk` (32.768kHz input)
   - `jtag_tck`, `jtag_tms`, `jtag_tdi`, `jtag_tdo`
3. **Connect new crossbar** (15M × 9S) with proper slave addressing
4. **Clock management**: Add dedicated clock dividers for UART baud rate clocks, RTC domain

### [MODIFY] `common/interfaces.sv` — Extend Interface Definitions
Add AXI4 Stream interface (`axi4s_if`) for the video pipeline data path.

---

## Phase 9 — Verification Strategy

### 9.1 Update Existing Testbench

#### [MODIFY] `verification/tb_titan_x_top.sv`
Current testbench only verifies hart boot (10,020 cycles). Extend with:
- **Boot sequence test**: Load a RISC-V ELF into simulated DDR, watch PCs advance through boot ROM → eNVM → DDR jump
- **Memory access test**: Write and read all 9 slave address regions
- **Interrupt delivery test**: Assert each PLIC source, verify corresponding hart handles it
- **Cache coherence test**: Two harts write/read shared memory, verify no stale data

### 9.2 New Targeted Testbenches

| Testbench | Module Under Test | Key Checks |
|---|---|---|
| `tb_rv_fpu.sv` | `rv_fpu.v` | IEEE 754-2008 corner cases: NaN, Inf, subnormals, rounding modes |
| `tb_rv_mmu.sv` | `rv_mmu.v` | Sv39 page walks, TLB flush, page fault generation |
| `tb_l2_coherence.sv` | `l2_snoop_filter.v` | MESI state machine, 4-core shared-exclusive conflict |
| `tb_axi_crossbar.sv` | `axi4_crossbar.v` | All 15 masters simultaneously active, QoS ordering, no deadlock |
| `tb_pcie.sv` | `pcie_top.v` | TLP read/write completions, MSI delivery |
| `tb_crypto.sv` | `aes_engine.v` + `sha256_engine.v` + `ecdsa_engine.v` | NIST CAVS test vectors |
| `tb_secure_boot.sv` | `secure_boot.v` | Good signature pass, bad signature halt |

### 9.3 Formal Verification Targets

Run `symbiyosys` (open-source formal verification) on:
- `rv_pmp.v`: Prove that no access violating a locked PMP entry ever reaches the bus
- `axi4_crossbar.v`: Prove AXI handshake compliance (no spurious VALID, no READY before VALID)
- `rv_tlb.v`: Prove no stale TLB entry is used after an SFENCE.VMA

---

## Recommended Execution Order & Timeline

```
Week 1–2:   Phase 0 (Parameters) + Phase 3.1 (Crossbar rebuild)
Week 3–5:   Phase 1.1 (M-extension, A-extension in execute stage)
Week 6–8:   Phase 1.3 (L1 Caches — critical path for performance)
Week 9–12:  Phase 1.1 (FPU — large, complex, high-risk)
Week 13–15: Phase 1.1 (Branch Predictor + MMU/TLB)
Week 16–17: Phase 2.1 (L2 Cache rebuild to 2MB)
Week 18–19: Phase 4.3 (Video Pipeline — MIPI, ISP, VDMA, HDMI)
Week 20–21: Phase 4.4 (Storage — USB, MMC, QSPI)
Week 22–23: Phase 6 (Security — eNVM, Secure Boot, ECDSA, DRBG)
Week 24:    Phase 5 (Scale remaining APB peripherals: CAN, RTC, WDTs)
Week 25–27: Phase 8 (Top-level integration — all new modules wired up)
Week 28–30: Phase 9 (Full verification pass — all testbenches green)
```

---

## File Inventory (New Files to Create)

| # | File | Purpose |
|---|------|---------|
| 1 | `common/isa_pkg.vh` | ISA constants for all extensions |
| 2 | `backend/rv_fpu.v` | IEEE 754-2008 FPU (F+D extensions) |
| 3 | `backend/rv_mmu.v` | Sv39 MMU top |
| 4 | `backend/rv_tlb.v` | TLB (4-way, ASID-tagged) |
| 5 | `backend/rv_ptw.v` | Page Table Walker |
| 6 | `backend/rv_pmp.v` | Physical Memory Protection |
| 7 | `backend/rv_debug.v` | JTAG Debug Module |
| 8 | `backend/rv_monitor_core.v` | RV64IMAC monitor core top |
| 9 | `frontend/rv_bpu.v` | Bimodal/Gshare Branch Predictor |
| 10 | `frontend/rv_icache.v` | 32KB 8-way I-Cache + SECDED |
| 11 | `backend/rv_dcache.v` | 32KB 8-way D-Cache + SECDED |
| 12 | `memory/sram_512kx8_180nm.v` | 512KB SRAM behavioral model |
| 13 | `memory/l2_snoop_filter.v` | MESI directory coherence |
| 14 | `interconnect/qos_controller.v` | AXI QoS weighted arbiter |
| 15 | `interconnect/mpu.v` | Memory Protection Unit for DMA masters |
| 16 | `peripherals/pcie_pipe_if.v` | PCIe Gen2 PIPE PHY interface |
| 17 | `peripherals/gem_sgmii_pcs.v` | SGMII PCS sublayer |
| 18 | `video/mipi_csi2_rx.v` | MIPI CSI-2 Receiver |
| 19 | `video/isp_pipeline.v` | ISP (de-Bayer, gamma, RGB2YUV) |
| 20 | `video/vdma.v` | Video DMA |
| 21 | `video/hdmi_ctrl.v` | HDMI 1.4 Display Controller |
| 22 | `storage/mmc_controller.v` | eMMC 5.1 / SD 3.0 Controller |
| 23 | `storage/usb_otg.v` | USB 2.0 OTG + ULPI |
| 24 | `storage/qspi_controller.v` | Quad-SPI + XIP |
| 25 | `peripherals/can_controller.v` | CAN 2.0B (instantiated twice) |
| 26 | `peripherals/rtc.v` | Real-Time Counter |
| 27 | `security/envm_ctrl.v` | 128KB eNVM Controller |
| 28 | `security/secure_boot.v` | Secure Boot Authentication |
| 29 | `security/ecdsa_engine.v` | ECDSA P-256/P-384 Hardware |
| 30 | `security/drbg.v` | HMAC-DRBG (NIST SP 800-90A) |
