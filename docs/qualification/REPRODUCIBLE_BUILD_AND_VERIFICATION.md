# SMVDU TITAN X — Reproducible Build, Simulation & Verification Guide
## Document ID: TITANX-REPRO-GUIDE-2026-11-18

**Project:** SMVDU TITAN X — 64-Bit Multicore RISC-V SoC  
**Release Tag:** `SMVDU-TITAN-X-v1.0.0`  
**Release Commit:** `471b8575a5cce650635351b9ca2ae4d951ff2dd3`  

---

## 1. Prerequisites & Toolchain Environment

The SMVDU TITAN X SoC verification environment requires the following open-source toolchain:

| Tool | Version Verified | Purpose in Flow | Command to Verify |
| :--- | :--- | :--- | :--- |
| **Python** | 3.10+ (tested on 3.13.13) | Regression runner & test harness | `python3 --version` |
| **Icarus Verilog** | 12.0+ / 13.0 devel | IEEE 1800 SystemVerilog simulation | `iverilog -V` |
| **vvp** | 12.0+ / 13.0 devel | Simulation runtime engine | `vvp -V` |
| **Yosys** | 0.33+ (tested on 0.33 & 0.38) | RTL elaboration & formal synthesis | `yosys -V` |
| **yosys-smtbmc** | Included in Yosys suite | SMT2 Bounded Model Checker | `yosys-smtbmc -h` |
| **Z3 SMT Solver** | 4.8+ (tested on 5.0.0 / 4.12.2)| Formal mathematical solver | `z3 --version` |
| **Git** | 2.30+ | Source version control & tagging | `git --version` |

---

## 2. Clean Checkout Reproduction

To reproduce the exact verified release baseline without relying on stale build artifacts:

```bash
# Clone the canonical repository
git clone https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04.git titan_x_repro
cd titan_x_repro

# Checkout the frozen release tag
git checkout tags/SMVDU-TITAN-X-v1.0.0

# Verify working tree is clean
git status
# Expected: "nothing to commit, working tree clean"

# Verify exact release commit SHA
git rev-parse HEAD
# Expected: 471b8575a5cce650635351b9ca2ae4d951ff2dd3
```

---

## 3. Running Verification Suites

### 3.1 Regression Runner Self-Test
Verify test runner verdict evaluation logic and error interception:
```bash
python3 scripts/run_regress.py --self-test
# Expected: "Result: ALL SELF-TESTS PASSED", Exit code: 0
```

### 3.2 Hardware Root-of-Trust & Security Chain Tests
Verify OTP eFuse controller, FIPS 180-4 SHA-256 padding, FIPS 186-4 ECDSA P-256 point multiplier, and pre-boot bus isolation:
```bash
# 1. OTP eFuse Controller Test (verifies 4 slots, key hashes, and slot revocation)
python3 scripts/run_regress.py --only tb_efuse_ctrl

# 2. Secure Boot Controller Test (verifies pre-boot reset hold and tamper rejection)
python3 scripts/run_regress.py --only tb_secure_boot

# 3. Cryptographic Hardware Engine Test (full multicycle Montgomery multiplier)
python3 scripts/run_regress.py --only tb_secure_boot_crypto

# 4. End-to-End Security Chain Integration Test
python3 scripts/run_regress.py --only tb_integ_security_chain
```

### 3.3 Full SoC Integration & Multi-Core Performance Tests
Verify all 5 harts boot from BootROM, execute benchmark workloads, and retire instructions:
```bash
# 1. End-to-End Full-Chip SoC Integration Test (29 system checks)
python3 scripts/run_regress.py --only tb_fresh_titan_x_top

# 2. Multi-Core Performance & Authentic Firmware Boot Benchmark
python3 scripts/run_regress.py --only tb_titan_x_performance
```

### 3.4 Running the Complete 120-Testbench Regression
To execute the entire SoC regression suite across all 120 canonical testbenches:
```bash
python3 scripts/run_regress.py -j 4 --timeout 180
# Results are logged to: artifacts/qualification/regression_results.json
# Expected Pass Rate: 120 / 120 (100.0% True Pass Rate)
```

---

## 4. Running Formal Verification Proofs (SMT-BMC)

Proofs use Yosys SMT-LIB2 models and the Z3 SMT solver:

```bash
# 1. Register File Invariant (x0 zero invariant, write forwarding bypass)
yosys-smtbmc -s z3 -t 20 verification/formal/proofs/rv_regfile.smt2
# Expected: "Status: PASSED", Exit code: 0

# 2. Instruction Fetch Alignment (PC[1:0] == 0, fetch stability under stall)
yosys-smtbmc -s z3 -t 20 verification/formal/proofs/rv_fetch.smt2
# Expected: "Status: PASSED", Exit code: 0

# 3. L2 Snoop Filter (MESI mutual exclusion, bounded snoop response)
yosys-smtbmc -s z3 -t 20 verification/formal/proofs/l2_snoop_filter.smt2
# Expected: "Status: PASSED", Exit code: 0

# 4. AXI4 Crossbar (Slave grant mutual exclusion, zero write interleaving)
yosys-smtbmc -s z3 -t 5 verification/formal/proofs/axi4_crossbar.smt2
# Expected: "Status: PASSED", Exit code: 0

# 5. Secure Boot (Pre-boot reset lock, negative tamper permanent halt)
yosys-smtbmc -s z3 -t 20 verification/formal/proofs/secure_boot.smt2
# Expected: "Status: PASSED", Exit code: 0
```

---

## 5. Running Full-Chip RTL Elaboration

Elaborate the entire SoC top-level design across all 79 synthesizable IP modules:

```bash
yosys -s scripts/synth_titan_x.tcl
```

Expected Output:
```text
75. Executing CHECK pass (checking for obvious problems).
Checking module titan_x_top...
Found and reported 0 problems.
...
76. Printing statistics.
=== titan_x_top ===
   Number of wires:              ...
   Number of wire bits:          ...
   Number of public wires:       ...
   Number of public wire bits:   ...
   Number of memories:           ...
   Number of memory bits:        ...
   Number of processes:          ...
   Number of cells:              ...
```
Exit code: 0 (Zero unresolved blackboxes, clean hierarchy).
