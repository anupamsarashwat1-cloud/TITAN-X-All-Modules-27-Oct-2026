# TITAN X Formal Verification Prerequisites & Toolchain Setup

## Overview

Formal property verification in the SMVDU TITAN X SoC project validates safety invariants and bounded model checking (BMC) properties across core hardware modules without relying on proprietary EDA tools or wrappers.

While high-level wrappers like SymbiYosys (`sby`) may be absent from standard host distributions (`DEF-VERIF-03`), the canonical verification environment leverages **Yosys SMT-LIB2 generation** and **`yosys-smtbmc`** backed directly by the **Z3 Theorem Prover**.

---

## 1. Toolchain Components & Versions

| Component | Path / Location | Minimum Version | Purpose |
| :--- | :--- | :--- | :--- |
| **Yosys** | `/usr/bin/yosys` or host PATH | 0.33+ | Synthesizes RTL and SVA assumptions/assertions into SMT-LIB2 format |
| **yosys-smtbmc** | `/usr/bin/yosys-smtbmc` | Bundled with Yosys | Drives bounded model checking (BMC) and temporal induction proofs |
| **Z3 Theorem Prover** | `z3` on host PATH / conda | 4.8.12+ | SMT-LIB2 bit-vector theory solver engine |
| **Python** | `/usr/bin/python3` | 3.8+ | Test runner script orchestration (`scripts/run_formal.py`) |

---

## 2. Environment Configuration

To ensure the Z3 solver and Yosys SMT toolchain are discovered properly:

```bash
# Verify Yosys installation
yosys -V

# Verify yosys-smtbmc is present
which yosys-smtbmc

# Ensure z3 is discoverable on PATH
export PATH="/home/anupam-sarashwat/miniforge3/bin:$PATH"
z3 --version
```

---

## 3. Automated Formal Regression Execution

The formal regression suite executes bounded model checking over all 5 formal properties in parallel or sequentially using `scripts/run_formal.py`:

```bash
cd /home/anupam-sarashwat/TITAN-X-2026-11-04
python3 scripts/run_formal.py
```

### Expected Output Summary:
```
================================================================================
  SMVDU TITAN-X FORMAL VERIFICATION SUITE (yosys-smtbmc + z3)
================================================================================
  [1/5] Running FORMAL-01 (rv_regfile, bound=20)...  ✓ PASSED (4.26s)
  [2/5] Running FORMAL-02 (rv_fetch, bound=20)...    ✓ PASSED (1.21s)
  [3/5] Running FORMAL-03 (l2_snoop, bound=20)...    ✓ PASSED (0.50s)
  [4/5] Running FORMAL-04 (axi4_xbar, bound=5)...    ✓ PASSED (13.33s)
  [5/5] Running FORMAL-05 (secure_boot, bound=20)... ✓ PASSED (0.40s)
================================================================================
  FORMAL VERIFICATION PASS RATE: 5/5 (100.0%)
================================================================================
```

---

## 4. Manual Reproduction per Module

To inspect or reproduce an individual formal proof directly from the command line:

```bash
# Example: Prove Register File x0 read-zero and writeback bypass invariants
yosys -p "read_verilog -sv verification/formal/sva/rv_regfile_formal.sv 'Design Files of TITAN X/backend/rv_regfile/rv_regfile.v'; prep -top rv_regfile_formal; write_smt2 -wires /tmp/rv_regfile.smt2"

yosys-smtbmc -s z3 -t 20 --dump-vcd /tmp/rv_regfile_bmc.vcd /tmp/rv_regfile.smt2
```
