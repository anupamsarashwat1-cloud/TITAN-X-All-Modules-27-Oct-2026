# TITAN X Physical Design Readiness & Implementation Assessment

- **Document Version:** 1.0.0
- **Qualification Gate:** Gate H (Pre-Silicon RTL Sign-Off & Physical Design Readiness)
- **Target Fabrication Node:** SCL 180nm CMOS (Semiconductor Complex Limited, 6-Metal 1.8V/3.3V)
- **Alternative Open Target:** SkyWater 130nm / TSMC 28nm HPC+
- **Evaluation Date:** 2026-11-04
- **Physical Design Status:** **RTL VERIFICATION COMPLETE; PHYSICAL IMPLEMENTATION PENDING**

---

## 1. Executive Summary & Readiness Verdict

The TITAN X multi-core SoC has achieved clean functional, formal, and mutation verification at the RTL level. All 111 canonical verification testbenches, 5/5 formal SMT-BMC proofs, and 6/6 architectural fault mutations demonstrate 100% pass rates. 

However, **the design is NOT tape-out ready in its current RTL state**. Physical design readiness requires transforming technology-independent behavioral descriptions into foundry-specific silicon physical layouts.

```
+-----------------------------------------------------------------------------------+
|                        TITAN X PHYSICAL DESIGN STATUS                             |
+------------------------------------+-----------------------+----------------------+
| Assessment Category                | Current RTL State     | Physical Sign-Off    |
+------------------------------------+-----------------------+----------------------+
| 1. Logic Synthesis                 | 81,072 generic cells  | Technology Mapped    |
| 2. Memory Subsystem                | Behavioral arrays     | Hardened SRAM Macros |
| 3. Timing Constraints (SDC)        | Idealized clocks      | Full SDC Sign-Off    |
| 4. Clock Domain Crossing (CDC)     | RTL Synchronizers     | Formal CDC Sign-Off  |
| 5. Design-for-Test (DFT)           | JTAG Debug Module     | Full Scan & MBIST    |
| 6. Power Distribution (PDN)        | Single rail model     | Multi-Domain Mesh    |
| 7. I/O Pad Ring & Packaging        | Top-level logic ports | I/O Ring & FBGA-676  |
+------------------------------------+-----------------------+----------------------+
```

> [!WARNING]
> **GATE H PHYSICAL IMPLEMENTATION BLOCKER**
> 
> Physical design (Place & Route / GDSII generation) requires resolving three primary architectural items:
> 1. Replacing behavioral RAM models (`sram_512kx8_180nm.v`, `l2_data_array.v`) with compiled foundry SRAM macros.
> 2. Establishing signed-off Synopsys Design Constraints (`.sdc`) across all 6 asynchronous clock domains.
> 3. Inserting IEEE 1149.1 boundary scan, internal scan chains, and Memory Built-In Self-Test (MBIST) controllers.

---

## 2. Process Technology & Standard Cell Mapping

### 2.1 Target Process Specification: SCL 180nm CMOS
- **Foundry / Process:** SCL (Semiconductor Complex Limited, Chandigarh, India) 180nm Bulk CMOS.
- **Interconnect Stack:** 1 Poly, 6 Metal Layers (M1–M4 routing, M5–M6 power distribution).
- **Core Operating Voltage:** 1.8V ± 10% (1.62V – 1.98V).
- **I/O Operating Voltage:** 3.3V ± 10% (2.97V – 3.63V).
- **Process Temperature Range:** -40°C to +125°C.
- **Operating PVT Corners for Timing Closure:**
  - **Slow-Slow (Setup Sign-Off):** SS / 1.62V / 125°C
  - **Fast-Fast (Hold Sign-Off):** FF / 1.98V / -40°C
  - **Typical-Typical (Power Sign-Off):** TT / 1.80V / 25°C

### 2.2 Standard Cell Area & Density Projections
- **Standard Cell Library:** 180nm 7-track or 9-track high-density logic library.
- **Average Logic Gate Density:** ~11,000 gates / mm² (at ~70% core target utilization).
- **Estimated SoC Active Logic Footprint:**
  - 4× Application Harts (`rv_core_top`): ~324k cells (~29.5 mm²)
  - 1× Monitor Hart (`rv_monitor_core`): ~81k cells (~7.4 mm²)
  - PLIC + CLINT Interrupt Subsystem: ~75k cells (~6.8 mm²)
  - AXI4 Interconnect, MPU, QoS: ~53k cells (~4.8 mm²)
  - Peripherals, Timers, Crypto, Video Glue: ~140k cells (~12.7 mm²)
  - **Total Active Logic Area:** **~61.2 mm²** (excluding SRAM macros and pad ring).

---

## 3. Memory Subsystem & Macro Compiler Requirements

The current RTL tree utilizes behavioral Verilog registers and arrays. For silicon physical implementation, these must be replaced with hardened foundry-generated SRAM compiler instances:

| Memory Component | Logical Organization | Total Capacity | Implementation Strategy | Macro Count |
|:---|:---|:---:|:---|:---:|
| **Core L1 I-Cache** | 4-way set associative, 32 KB / core | 128 KB (4 cores) | Single-Port / Pseudo-Dual-Port SRAM Macro | 4 |
| **Core L1 D-Cache** | 4-way set associative, 32 KB / core | 128 KB (4 cores) | Two-Port (1R1W) High-Speed SRAM Macro | 4 |
| **L2 Shared Cache** | 8-way set associative, 512 KB | 512 KB | Compiled Dual-Port High-Density SRAM Blocks | 8 × 64 KB |
| **BootROM** | 64-bit wide, non-volatile | 64 KB | Metal-Programmable ROM Macro | 1 |
| **On-Chip Scratchpad** | 64-bit wide, low-latency | 512 KB | Compiled Single-Port High-Density SRAM Blocks | 8 × 64 KB |
| **Total Memory Area** | **~1.34 Megabytes Embedded SRAM** | | **~18.5 – 22.0 mm² in SCL 180nm** | **25 Macros** |

### 3.1 Memory Design Rules for Physical Layout
1. **Aspect Ratio & Orientation:** Place memory macros along the die periphery facing the core logic area, maintaining power grid continuity.
2. **Channel Widths:** Allocate minimum 25 µm halo spacing between adjacent SRAM macros for power routing and substrate tap insertion.
3. **BIST Collar Insertion:** Every compiled memory macro must be wrapped with an IEEE 1500 compliant Memory Built-In Self-Test (MBIST) collar to enable at-speed structural memory testing.

---

## 4. Clocking Architecture & Clock Domain Crossing (CDC)

### 4.1 Clock Domain Definitions

The TITAN X SoC incorporates 6 distinct asynchronous clock domains:

| Clock Domain | Frequency | Source | Target Destination Modules | Synchronization Scheme |
|:---|:---:|:---|:---|:---|
| `clk_core` | 138.8 MHz | On-chip PLL | RV64 Cores, Crossbar, L2 Cache, Interconnect MPU | Primary Synchronous Domain |
| `rtc_clk` | 32.768 kHz | External Crystal | Real-Time Counter, CLINT timer base, Watchdog | `common/cdc_sync.v` (3-flop) |
| `pipe_clk` | 250.0 MHz | PCIe Transceiver | PCIe Endpoint MAC & Controller | `common/fifo_async.v` (Gray) |
| `eth_clk` | 125.0 MHz | RGMII PHY / PLL | Gigabit Ethernet MAC & Packet Buffers | `common/fifo_async.v` (Gray) |
| `ulpi_clk` | 60.0 MHz | USB PHY | USB 2.0 OTG Controller | `common/cdc_sync.v` + Handshake |
| `hdmi_pixel_clk` | 148.5 MHz | Video PLL | Video Display Controller, Pixel DMA | `common/fifo_async.v` (Line buffer) |

### 4.2 Clock Domain Crossing (CDC) Verification
- **Synchronizer Audit:** All crossings between asynchronous domains must strictly utilize the audited primitives:
  - 1-bit control signals: `common/cdc_sync.v` (triple-flip-flop synchronizer with MTBF > 10,000 years).
  - Multi-bit data buses: `common/fifo_async.v` (asynchronous dual-clock FIFO with Gray-code pointers).
  - Asynchronous resets: `common/reset_sync.v` (asynchronous assert, synchronous deassert).
- **Formal CDC Verification:** A formal CDC structural check (using SpyGlass CDC or Questa CDC) must be executed before tape-out to guarantee zero metastability bugs.

---

## 5. Synopsys Design Constraints (SDC) Architecture

An authentic SDC constraint template for physical synthesis and static timing analysis (STA):

```tcl
# ==============================================================================
# TITAN X SoC Timing Constraints (titan_x.sdc)
# Target Clock: 138.88 MHz Core (Period = 7.200 ns)
# ==============================================================================

# 1. Primary Clock Definitions
create_clock -name clk_core  -period 7.200 -waveform {0.000 3.600} [get_ports clk]
create_clock -name rtc_clk   -period 30517.578 -waveform {0.000 15258.789} [get_ports rtc_clk]
create_clock -name pipe_clk  -period 4.000 -waveform {0.000 2.000} [get_ports pipe_clk]
create_clock -name eth_clk   -period 8.000 -waveform {0.000 4.000} [get_ports eth_clk]
create_clock -name ulpi_clk  -period 16.666 -waveform {0.000 8.333} [get_ports ulpi_clk]

# 2. Clock Uncertainty & Jitter
set_clock_uncertainty -setup 0.250 [get_clocks clk_core]
set_clock_uncertainty -hold  0.100 [get_clocks clk_core]
set_clock_transition 0.150 [all_clocks]

# 3. Asynchronous Clock Domain Groups (False Paths across Asynchronous Domains)
set_clock_groups -asynchronous \
    -group [get_clocks clk_core] \
    -group [get_clocks rtc_clk] \
    -group [get_clocks pipe_clk] \
    -group [get_clocks eth_clk] \
    -group [get_clocks ulpi_clk]

# 4. Multi-Cycle Paths (64-bit Multiplier & Multi-cycle Divider)
set_multicycle_path -setup 2 -from [get_pins u_core[*].u_execute.u_alu_mul*] -to [get_pins u_core[*].u_execute.mul_res_reg*]
set_multicycle_path -hold  1 -from [get_pins u_core[*].u_execute.u_alu_mul*] -to [get_pins u_core[*].u_execute.mul_res_reg*]

# 5. I/O Delays (External Bus Constraints)
set_input_delay  -clock clk_core -max 2.500 [get_ports {ext_mem_rdata[*]}]
set_input_delay  -clock clk_core -min 0.500 [get_ports {ext_mem_rdata[*]}]
set_output_delay -clock clk_core -max 2.000 [get_ports {ext_mem_wdata[*] ext_mem_addr[*]}]
set_output_delay -clock clk_core -min 0.200 [get_ports {ext_mem_wdata[*] ext_mem_addr[*]}]

# 6. False Paths (Static Reset and Configuration)
set_false_path -from [get_ports rst_n]
```

---

## 6. Design-for-Test (DFT) Architecture

To guarantee silicon yield and structural fault detection, the following DFT features must be inserted prior to physical routing:

1. **Scan Chain Insertion:**
   - Scan chain architecture: 36 balanced scan chains.
   - Flip-Flop count: ~35,000 flip-flops across core logic.
   - Chain depth: ~980 flip-flops per chain.
   - Scan multiplexer overhead: ~3–5% area increase.
   - Target ATPG Fault Coverage: > 98.5% stuck-at fault coverage; > 92% at-speed transition delay fault coverage.

2. **Boundary Scan (IEEE 1149.1):**
   - JTAG TAP controller connected to `backend/rv_debug/rv_debug.v`.
   - Boundary scan cells inserted on all digital I/O pads for PCB interconnect testing.

3. **Memory BIST (MBIST):**
   - Central MBIST controller orchestrating March C+ algorithms across all 25 SRAM macros.

---

## 7. Power Distribution Network (PDN) & I/O Pad Ring

### 7.1 Power Distribution Architecture
- **VDD_CORE (1.8V):** Powers CPU cores, crossbar, memories, and digital peripherals. Max active current: ~4.2 A.
- **VDD_IO (3.3V):** Powers GPIO, UART, SPI, I2C, JTAG, and board-level interfaces.
- **VDD_DDR (1.2V):** Dedicated supply for external DDR4 PHY interface.
- **VDDA (1.8V):** Low-noise analog supply with guard-ring isolation for PLLs and SERDES transceivers.
- **Power Mesh Target:** Metal 5 (horizontal straps) and Metal 6 (vertical straps) mesh with < 54 mV (3%) maximum dynamic IR drop.

### 7.2 I/O Pad Ring & Packaging Selection
- **Package Selection:** 676-pin Fine-Pitch Ball Grid Array (FBGA-676, 27 mm × 27 mm, 1.0 mm pitch).
- **Pad Ring Pin Allocation:**
  - DDR4 Interface: 128 pins (Data, Address, Control, DQS, VDDQ/VSSQ)
  - Video Subsystem (HDMI + MIPI): 48 pins
  - PCIe 4-lane PIPE: 32 pins
  - Gigabit Ethernet (RGMII): 24 pins
  - Low-Speed Peripherals (UART, SPI, I2C, GPIO, CAN): 64 pins
  - JTAG & Debug: 8 pins
  - Power & Ground (VDD/VSS pad pairs): 280 pins (maintaining 1:2.5 power-to-signal ratio)
  - Dedicated Analog & Clock: 16 pins
  - **Total Pin Count:** ~600 active pins / 676 balls.

---

## 8. Physical Implementation Sign-Off Checklist

```
+-----------------------------------------------------------------------------------+
|               TITAN X GATE H PHYSICAL IMPLEMENTATION SIGN-OFF CHECKLIST           |
+----+-----------------------------------------------------+--------+---------------+
| No | Sign-Off Item                                       | Status | Prerequisite  |
+----+-----------------------------------------------------+--------+---------------+
| 01 | RTL Freeze & Canonical Filelist Consistency         | ✅ PASS| Phase 14-21   |
| 02 | Bounded Formal Verification (Yosys + Z3 BMC)        | ✅ PASS| Phase 22      |
| 03 | Architectural Fault Mutation Sensitivity (100%)     | ✅ PASS| Phase 21      |
| 04 | Generic Technology-Independent Logic Synthesis      | ✅ PASS| Phase 22      |
| 05 | Standard Cell Liberty (.lib) Technology Mapping     | ⏳ OPEN| ASIC Foundry  |
| 06 | Compiled Foundry SRAM Macro Replacement             | ⏳ OPEN| Memory Compiler|
| 07 | SDC Multi-Clock Constraints & Static Timing Analysis| ⏳ OPEN| Design Compiler|
| 08 | Formal Clock Domain Crossing (CDC) Structural Audit | ⏳ OPEN| SpyGlass CDC  |
| 09 | Scan Chain & MBIST Insertion (DFT Sign-Off)         | ⏳ OPEN| TestMax/DFTMAX|
| 10 | Place & Route, Clock Tree Synthesis (CTS)           | ⏳ OPEN| Innovus/ICC2  |
| 11 | DRC / LVS / Antenna Rule Physical Verification       | ⏳ OPEN| Calibre nmDRC |
| 12 | Tape-Out Sign-Off & GDSII Mask Generation           | ⏳ OPEN| Foundry PDK   |
+----+-----------------------------------------------------+--------+---------------+
```

### Conclusion
TITAN X stands fully qualified at **Gate H (RTL Sign-Off)**. The architecture, RTL logic, formal invariants, and behavioral verification suites are complete, integrated, and technically verified. Transition to physical manufacturing requires standard cell library mapping and foundry PDK enablement.
