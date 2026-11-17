# Reconciliation Test Results

**Date:** 2026-11-17  
**Branch:** `reconciliation/canonical-repository-2026-11-05`  
**Target Repository:** https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04  

---

## 1. Yosys Full-Chip Synthesis (Clean Pass)

- **Tool:** Yosys 0.33 (git sha1 2584903a060)
- **Top Module:** `titan_x_top`
- **Script:** `synth_titan_x.tcl`
- **Execution Date:** 2026-11-17
- **Exit Code:** 0 (SUCCESS)
- **CPU Time:** User 128.46s, System 25.97s (Total: ~154s)
- **Peak Memory:** 1680.37 MB

### Cell Accounting:
| Metric | Count | Details |
|---|---|---|
| **Total Cells** | **30,886** | Synthesizable logic gates & arithmetic operators |
| **SRAM Macros** | **256** | `sram_32x64_180nm` compiled macros |
| **Logic Processes** | **662** | Behavioral always blocks elaborated |
| **Warnings** | **210 unique** (287 total) | Clean elaboration, 0 unresolved blackboxes |

---

## 2. Regression & Simulation Verification

### 2a. Peripheral Bus Integration Test (`tb_integ_peripheral_bus`)
- **Command:** `python3 scripts/run_regress.py --only tb_integ_peripheral_bus`
- **Tool:** Icarus Verilog 12.0 (`iverilog` / `vvp`)
- **Working Directory:** `/home/anupam-sarashwat/TITAN-X-2026-11-04`
- **Source Commit:** `1f7e813f8d1be904fe517be57a20c2046d182511`
- **Exit Code:** 0
- **Verdict:** **PASS** (100.0%)
- **Log Path:** `artifacts/qualification/logs/tb_integ_peripheral_bus.log`
- **Details:** 77 synthesizable modules + BFMs compiled and simulated. De-mocked zero wait-state APB bus cycles for GPIO, RTC, and WDT verified clean.

### 2b. SoC Full Top Simulation (`tb_titan_x_top`)
- **Command:** `python3 scripts/run_regress.py --only tb_titan_x_top`
- **Tool:** Icarus Verilog 12.0 (`iverilog` / `vvp`)
- **Working Directory:** `/home/anupam-sarashwat/TITAN-X-2026-11-04`
- **Source Commit:** `1f7e813f8d1be904fe517be57a20c2046d182511`
- **Exit Code:** 1 (Runner Timeout)
- **Verdict:** **TIMEOUT** (600s wall clock limit exceeded)
- **Log Path:** `artifacts/qualification/logs/tb_titan_x_top.log`
- **Limitation:** In un-optimized event-driven Icarus Verilog (`vvp`), executing multi-round SHA-256 and ECDSA P-256 cryptographic point multiplication concurrently with a 4-core application cluster and L2 cache hierarchy requires >600s simulation time. Compilation succeeded with all 79 synthesizable RTL modules.

### 2c. SVA Formal BMC Verification
- **Tool:** `yosys-smtbmc -s z3`
- **Properties Documented:** `verification/formal/sva_inventory.md`
- **Scope:** 5 formal proof suites (Crossbar, Snoop Filter, RV Fetch, RV Regfile, Secure Boot). All 5 properties verified.
