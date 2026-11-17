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
- **Status:** **PASS** (100.0%)
- **Tool:** Icarus Verilog (`iverilog` / `vvp`)
- **Modules Compiled:** 77 synthesizable modules + BFMs
- **Result:** De-mocked zero wait-state APB bus cycles for GPIO, RTC, WDT verified clean.

### 2b. SoC Full Top Simulation (`tb_titan_x_top`)
- **Status:** **PASS**
- **Tool:** Icarus Verilog (`iverilog` / `vvp`)
- **Modules Compiled:** 79 synthesizable modules
- **Result:** RoT secure boot verification passes, CPU instruction retirement verified on Hart 0.

### 2c. SVA Formal BMC Verification
- **Tool:** `yosys-smtbmc -s z3`
- **Properties Documented:** `verification/formal/sva_inventory.md`
- **Scope:** 5 formal proof suites (Crossbar, Snoop Filter, RV Fetch, RV Regfile, Secure Boot).
