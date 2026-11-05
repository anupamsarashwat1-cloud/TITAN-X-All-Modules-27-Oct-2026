# Phase 04: Boot Memory, RoT Coupling & Reset Integration

**Phase ID:** `PHASE-04`  
**Target Milestone:** M3 — End-to-End Secure Boot Chain  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Prerequisites:** `PHASE-01`, `PHASE-03` complete  

## 1. Objective
Cryptographically couple `secure_boot` directly to the `axi_rom` boot image (`DEF-SEC-01`) and connect the watchdog reset net to system reset (`DEF-ARCH-02`).

## 2. Tasks
- `TASK-04-01`: Cryptographically couple hardware Root of Trust directly to executed boot ROM image (`DEF-SEC-01`).
- `TASK-04-02`: Integrate watchdog timer reset output net into system and core reset controllers (`DEF-ARCH-02`).

## 3. Architectural Decision Gates
- `ADR-01`: Direct Pre-Boot Read Routing from `axi_rom` to `secure_boot`.
- `ADR-07`: Hard Reset of CPU Core Reset Tree via `wdt_reset_n`.

## 4. Verification Plan
- System test: `tb_titan_x_top.v` with authentic `firmware.hex` and tampered `firmware.hex`.
- Subsystem test: `tb_watchdog_timer.v` injecting software lockup and verifying reboot.

## 5. Acceptance Criteria
- Core reset `core_rst_n` deasserts only after authenticating `firmware.hex`.
- Any single-byte modification to `firmware.hex` locks the core in reset.
- Watchdog expiration pulses `core_rst_n` low, resetting PC to `0x1000_0000`.
