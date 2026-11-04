# SMVDU TITAN-X Structural Audit & Integration Connectivity Report

- **Date:** 2026-11-04  
- **Target Top Module:** `top/titan_x_top/titan_x_top.v` (`titan_x_top`)  
- **Governing Standard:** IEEE 1800-2012 / RISC-V Privileged Architecture v1.12  
- **Classification:** Architectural Integration & Elaboration Audit  

---

## 1. Executive Summary

This structural audit provides an independent, machine-verified examination of the top-level integration in `titan_x_top.v`. It documents the exact signal paths, core boundaries, memory and peripheral interconnects, tie-offs, and module omissions present in the synthesizable RTL.

### Key Structural Findings:
1. **Multicore & Cache Interconnect Reality:**
   - Cores 0–3 (`rv_core_top`) and Core 4 (`rv_monitor_core`) connect directly to the 10-master `axi4_crossbar`.
   - **No L1 instruction or data caches** are instantiated inside `rv_core_top` or in `titan_x_top.v`. `rv_fetch` and `rv_mem` drive single-beat AXI requests directly to the crossbar.
   - **L2 Cache is isolated:** `l2_cache_top` is instantiated in `titan_x_top.v` with only `.clk(clk)` and `.rst_n(rst_n)` connected. None of its memory request/response buses, tag arrays, or data lines connect to the crossbar, cores, or DDR controller.
   - **Snoop filter is omitted:** `l2_snoop_filter` is not instantiated in `titan_x_top.v`. Core snoop ports (`.snoop_valid(1'b0)`, `.snoop_addr(40'h0)`) are tied off at top level, and inside `rv_core_top.v`, snoop outputs are tied to 0 (`assign snoop_ack = 1'b0`).
   - **Coherence disclaimer:** The formal MESI proof (`FORMAL-03` / `l2_snoop_filter.sby`) proves the state machine of the standalone `l2_snoop_filter.v` IP module only; it does **not** prove coherency of the integrated SoC.
2. **Omitted Functional Modules:**
   - 20 peripheral, memory, and security modules implemented in the repository are **never instantiated** in `titan_x_top.v`, including `clint`, `rv_debug`, `trng`, `sha256_engine`, `ecdsa_engine`, `vdma`, `spi_master`, `i2c_master`, `watchdog_timer`, `mmc_controller`, `qspi_controller`, `mpu`, `mmu_arbiter`, and `qos_controller`.
3. **ASIC Physical Design Readiness:**
   - The RTL is **NOT ready for ASIC physical design (P&R)**. It lacks technology standard cell mapping, compiled SRAM macros, CTS/SDC timing constraints, an IO pad ring, and top-level integration closure.

---

## 2. Machine-Verified Core Connectivity Matrix

| Core Instance | Hart ID | Architecture | Instruction Path | Data Memory Path | L1 Cache | L2 Cache Attachment | Snoop Port Status | Interrupts (M-Ext / Timer / Soft) |
|---|---|---|---|---|---|---|---|---|
| `gen_cores[0].u_core` | Hart 0 | RV64IM (5-stage in-order) | Xbar Master 0 (read-only) | Xbar Master 4 (read/write) | None (direct AXI) | None (L2 isolated) | Tied off (`snoop_valid=0`, `ack=0`) | PLIC target 0 / RTC timer / `sw_irq=0` (no CLINT) |
| `gen_cores[1].u_core` | Hart 1 | RV64IM (5-stage in-order) | Xbar Master 1 (read-only) | Xbar Master 5 (read/write) | None (direct AXI) | None (L2 isolated) | Tied off (`snoop_valid=0`, `ack=0`) | PLIC target 2 / RTC timer / `sw_irq=0` (no CLINT) |
| `gen_cores[2].u_core` | Hart 2 | RV64IM (5-stage in-order) | Xbar Master 2 (read-only) | Xbar Master 6 (read/write) | None (direct AXI) | None (L2 isolated) | Tied off (`snoop_valid=0`, `ack=0`) | PLIC target 4 / RTC timer / `sw_irq=0` (no CLINT) |
| `gen_cores[3].u_core` | Hart 3 | RV64IM (5-stage in-order) | Xbar Master 3 (read-only) | Xbar Master 7 (read/write) | None (direct AXI) | None (L2 isolated) | Tied off (`snoop_valid=0`, `ack=0`) | PLIC target 6 / RTC timer / `sw_irq=0` (no CLINT) |
| `u_monitor` | Hart 4 | RV64IMAC Monitor | Xbar Master 8 (read-only) | Xbar Master 9 (read/write) | None (direct AXI) | None (L2 isolated) | N/A (no snoop port) | PLIC target 8 / RTC timer / `sw_irq=0` (no CLINT) |

---

## 3. Top-Level Module Instantiation Inventory

### 3.1 Modules Instantiated in `titan_x_top.v`
- `plic` (`u_plic`): 32-source Platform-Level Interrupt Controller; APB control routed to internal peripheral bus.
- `axi4_crossbar` (`u_crossbar`): 10 Master × 4 Slave interconnect fabric (Slaves: DDR4 controller, APB bridge, Boot ROM, Unmapped DECERR).
- `axi_rom` (`u_boot_rom`): On-chip boot ROM at Slave 2.
- `rv_core_top` (`gen_cores[0..3].u_core`): 4 compute cores.
- `rv_monitor_core` (`u_monitor`): Monitor core.
- `l2_cache_top` (`u_l2_cache`): Dummy clock/reset instantiation only (isolated).
- `ddr_ctrl_top` (`u_ddr_ctrl`): DDR4 memory controller at Slave 0 (`0x8000_0000`).
- `axi4_to_ahb` (`u_axi2ahb`): Crossbar Slave 1 bridge to internal AHB/APB peripheral space (`0x4000_0000`).
- `gem_ethernet` (`u_gem`): Gigabit Ethernet MAC at APB aperture `0x4002_0000`.
- `pcie_top` (`u_pcie`): PCI Express Gen3 controller with 4-lane PIPE interface.
- `usb_otg` (`u_usb`): USB 2.0 OTG controller at APB aperture `0x4003_0000`.
- `secure_boot` (`u_secure_boot`): Hardware boot authenticator and core reset controller at APB aperture `0x400A_0000`.
- `envm_ctrl` (`u_envm`): Embedded NVM controller at APB aperture `0x4009_0000`.
- `drbg` (`u_drbg`): NIST SP 800-90A DRBG at APB aperture `0x4007_0000`.
- `aes_engine` (`u_aes`): AES-128/256 symmetric cipher at APB aperture `0x4008_0000`.
- `rtc` (`u_rtc`): Real-Time Clock & tick timer at APB aperture `0x4001_0000`.
- `uart_16550` (`u_uart0` to `u_uart4`): 5 UART controllers at APB apertures `0x4000_0000` to `0x4000_4000`.
- `can_controller` (`u_can0`, `u_can1`): 2 CAN 2.0B controllers at APB apertures `0x400B_0000`, `0x400C_0000`.
- `mipi_csi2_rx` (`u_mipi`): Camera serial interface receiver at APB aperture `0x4004_0000`.
- `isp_pipeline` (`u_isp`): Image signal processor at APB aperture `0x4005_0000`.
- `hdmi_ctrl` (`u_hdmi`): Video display controller at APB aperture `0x4006_0000`.

### 3.2 Modules Existing in Repository But OMITTED from `titan_x_top.v`
The following synthesizable RTL modules exist in the repository tree and pass standalone unit tests, but are **not connected** in `titan_x_top.v`:
1. `clint` (`backend/clint/clint.v`): Core Local Interruptor (software interrupts `sw_irq` are tied to 0; timer interrupt routed from `rtc`).
2. `rv_debug` (`backend/rv_debug/rv_debug.v`): JTAG RISC-V debug unit (core `halt_req` and `resume_req` are tied to 0).
3. `l2_snoop_filter` (`memory/l2_snoop_filter/l2_snoop_filter.v`): Coherence directory filter (never instantiated).
4. `l2_cache_ctrl` (`memory/l2_cache_ctrl/l2_cache_ctrl.v`): L2 pipeline controller (never instantiated at top).
5. `l2_tag_array` (`memory/l2_tag_array/l2_tag_array.v`): L2 tag memory.
6. `l2_data_array` (`memory/l2_data_array/l2_data_array.v`): L2 data memory.
7. `rv_icache` (`frontend/rv_icache/rv_icache.v`): L1 instruction cache.
8. `rv_dcache` (`backend/rv_dcache/rv_dcache.v`): L1 data cache.
9. `trng` (`peripherals/trng/trng.v`): True Random Number Generator.
10. `sha256_engine` (`peripherals/sha256_engine/sha256_engine.v`): Dedicated SHA-256 accelerator.
11. `ecdsa_engine` (`security/ecdsa_engine/ecdsa_engine.v`): Dedicated ECDSA P-256 accelerator.
12. `vdma` (`video/vdma/vdma.v`): Video Direct Memory Access engine.
13. `spi_master` (`peripherals/spi_master/spi_master.v`): SPI bus master.
14. `i2c_master` (`peripherals/i2c_master/i2c_master.v`): I2C bus master.
15. `watchdog_timer` (`peripherals/watchdog_timer/watchdog_timer.v`): Watchdog timer.
16. `mmc_controller` (`storage/mmc_controller/mmc_controller.v`): SD/eMMC storage controller.
17. `qspi_controller` (`storage/qspi_controller/qspi_controller.v`): Quad-SPI flash controller.
18. `interconnect_mpu` (`interconnect/interconnect_mpu/mpu.v`): Memory Protection Unit on crossbar.
19. `mmu_arbiter` (`interconnect/mmu_arbiter/mmu_arbiter.v`): Virtual memory page-table walk arbiter.
20. `qos_controller` (`interconnect/qos_controller/qos_controller.v`): Quality-of-service bus arbiter.

---

## 4. Boundary Tie-Off and Constant Audit

```
Core Boundary Tie-Offs (Cores 0-3):
  ├── .imem_arlen         -> 8'h0 (single beat)
  ├── .imem_arsize        -> 3'd2 (4 bytes)
  ├── .imem_arburst       -> 2'b00 (FIXED)
  ├── .dmem_awlen/size/burst -> UNCONNECTED
  ├── .dmem_arlen/size/burst -> UNCONNECTED
  ├── .snoop_valid        -> 1'b0 (tied off)
  ├── .snoop_addr         -> 40'h0 (tied off)
  ├── .snoop_type         -> 2'b00 (tied off)
  ├── .snoop_ack          -> hardwired 1'b0 inside core
  ├── .snoop_data_valid   -> hardwired 1'b0 inside core
  ├── .snoop_data         -> hardwired 512'h0 inside core
  ├── .halt_req           -> 1'b0 (tied off)
  ├── .resume_req         -> 1'b0 (tied off)
  └── .irq_m_soft         -> 1'b0 (tied off)
```

---

## 5. ASIC Physical Design (P&R) Readiness Assessment

| ASIC Preparation Area | Current Status | Finding | Readiness |
|---|---|---|---|
| RTL Synthesis | Generic cell netlist (79,560 unmapped cells) | No standard cell library targeted | ❌ Blocked |
| Memory Subsystem | Behavioral 2D Verilog arrays | No compiled foundry SRAM macros | ❌ Blocked |
| Timing Constraints | None | No Synopsys Design Constraints (.sdc) | ❌ Blocked |
| Clock Tree Synthesis | Single idealized clk net | No clock domain crossing (CDC) SDC rules | ❌ Blocked |
| Testability (DFT) | Zero scan chains | No scan flip-flop insertion or ATPG | ❌ Blocked |
| Power Architecture | Hardwired VDD/VSS | No UPF/CPF power intent or retention cells | ❌ Blocked |
| IO & Packaging | Behavioral pin definitions | No IO pad ring, ESD protection, or pin mux | ❌ Blocked |
| Top-Level Integration | Isolated L2, omitted peripherals, tied snoop | Core interconnect incomplete | ❌ Blocked |

**Conclusion:** SMVDU TITAN-X is **NOT ready for ASIC physical design**. It is an early-stage digital architecture design with functional unit-level RTL. Full-chip architectural integration, standard cell technology mapping, and physical design closure are required before any physical tape-out consideration.
