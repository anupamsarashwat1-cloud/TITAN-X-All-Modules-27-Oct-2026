# Phase 01: Interconnect & Bus Fabric Correctness

**Phase ID:** `PHASE-01`  
**Target Milestone:** M1 — Interconnect Fabric Integrity  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** `PHASE-00` complete  

## 1. Objective
Remediate the critical APB address collision (`DEF-ARCH-01`) in `titan_x_top.v` that blinds 9 peripherals, and connect on-chip SRAM to crossbar Slave 3 (`DEF-ARCH-07`).

## 2. Tasks
- `TASK-01-01`: Correct APB address decoder to eliminate 16-bit aperture overlap in UART0 selection (`DEF-ARCH-01`).
- `TASK-01-02`: Map on-chip scratchpad SRAM to AXI Crossbar Slave 3 and isolate DECERR generator (`DEF-ARCH-07`).

## 3. Architectural Decision Gate
- `ADR-06`: Strict 4KB page APB decoding on `paddr[31:12]`.

## 4. Verification Plan
- Unit test: `tb_unit_apb_bridge.v`.
- Subsystem test: `tb_integ_peripheral_bus.v` using top-level APB decoder.
- Address boundary sweep: verify independent read/write to RTC, GPIO, WDT, SPI, I2C, MMC, QSPI, VDMA without UART0 crosstalk.

## 5. Acceptance Criteria
- Zero address collision across `0x4000_0000` to `0x4011_FFFF`.
- Reads and writes to on-chip SRAM at `0x0000_0000` return OKAY (`2'b00`).
