# TITAN X Mutation Testing & Verification Sensitivity Report

- **Date:** 2026-11-04 00:32:04 UTC
- **Total Mutants Evaluated:** 6
- **Mutants Killed:** 6
- **Mutants Survived:** 0
- **Mutation Kill Rate / Sensitivity:** 100.0% (6 of 6 evaluated mutants killed)

> [!NOTE]
> **Scope Disclaimer:** This evaluation tests 6 representative architectural mutations covering register bypassing, bus decoding, ALU arithmetic, trap vector alignment, interrupt routing, and IEEE 754 floating-point min/max selection. It demonstrates testbench sensitivity to specific critical defects, but does **not** constitute an exhaustive or comprehensive mutation campaign across the full RTL codebase.

## Summary Matrix

| ID | Subsystem | Fault Injected | Targeted Testbench | Outcome | Detection Evidence |
|:---|:---|:---|:---|:---:|:---|
| **MUT-01** | `backend/rv_regfile/rv_regfile.v` | Bypasses x0 hardwired-to-zero gate, allowing writes to x0 to leak to read port 1 | `backend/rv_regfile/tb_rv_regfile.v` | ✅ KILLED | `FAIL [18011000] rnd[1789] port1 x0 got=0xcf030c9ef7d28cef exp=0x0000000000000000` |
| **MUT-02** | `interconnect/axi4_crossbar/axi4_crossbar.v` | Misroutes DDR address aperture (0x8000_0000) to APB bridge slave 1 instead of DDR slave 0 | `interconnect/axi4_crossbar/tb_axi4_crossbar.v` | ✅ KILLED | `FAIL [106000] s_araddr=0x0000000000 exp=0x80000000` |
| **MUT-03** | `backend/rv_execute/rv_execute.v` | Inverts ALU ADD operation into subtraction, corrupting integer addition results | `backend/rv_execute/tb_rv_execute.v` | ✅ KILLED | `FAIL [96000]                 ADD: 100+200=300: got=0xffffffffffffff9c exp=0x000000000000012c` |
| **MUT-04** | `backend/rv_csr/rv_csr.v` | Forces unaligned mtvec address output violating RISC-V 4-byte trap handler alignment | `backend/rv_csr/tb_rv_csr.v` | ✅ KILLED | `FAIL [111000] mtvec_out: got=0000000000001043 exp=0000000000001040` |
| **MUT-05** | `backend/plic/plic.v` | Suppresses interrupt target routing, preventing pending interrupts from asserting external interrupt lines | `backend/plic/tb_plic.v` | ✅ KILLED | `FAIL [236000] s[0]=1 when src1 pending+enabled: got=0x0000000000000000 exp=0x0000000000000001` |
| **MUT-06** | `backend/rv_fpu/rv_fpu.v` | Inverts single-precision FMIN.S and FMAX.S IEEE 754 calculation bits, violating minimum/maximum selection | `backend/rv_fpu/tb_fresh_rv_fpu.v` | ✅ KILLED | `ERROR [T9a]: FMIN.S failed: expected FFFFFFFF40000000, got ffffffffbfffffff` |

## Detailed Fault Injection Analysis

### MUT-01: x0 Write Bypass (Register File)
- **Target File:** `backend/rv_regfile/rv_regfile.v`
- **Target Testbench:** `backend/rv_regfile/tb_rv_regfile.v`
- **Baseline Pass:** `PASS [tb_rv_regfile] All register tests pass`
- **Mutant Fail Evidence:** `FAIL [18011000] rnd[1789] port1 x0 got=0xcf030c9ef7d28cef exp=0x0000000000000000`
- **Restored Pass:** `PASS [tb_rv_regfile] Restored original RTL passes 100%`
- **Outcome:** MUTANT KILLED

### MUT-02: AXI Crossbar Slave Decode Misrouting
- **Target File:** `interconnect/axi4_crossbar/axi4_crossbar.v`
- **Target Testbench:** `interconnect/axi4_crossbar/tb_axi4_crossbar.v`
- **Baseline Pass:** `PASS [tb_axi4_crossbar] Crossbar routing valid`
- **Mutant Fail Evidence:** `FAIL [106000] s_araddr=0x0000000000 exp=0x80000000`
- **Restored Pass:** `PASS [tb_axi4_crossbar] Restored original RTL passes 100%`
- **Outcome:** MUTANT KILLED

### MUT-03: ALU Arithmetic Operator Inversion
- **Target File:** `backend/rv_execute/rv_execute.v`
- **Target Testbench:** `backend/rv_execute/tb_rv_execute.v`
- **Baseline Pass:** `PASS [tb_rv_execute] Arithmetic execution valid`
- **Mutant Fail Evidence:** `FAIL [96000]                 ADD: 100+200=300: got=0xffffffffffffff9c exp=0x000000000000012c`
- **Restored Pass:** `PASS [tb_rv_execute] Restored original RTL passes 100%`
- **Outcome:** MUTANT KILLED

### MUT-04: Trap Vector Address Misalignment
- **Target File:** `backend/rv_csr/rv_csr.v`
- **Target Testbench:** `backend/rv_csr/tb_rv_csr.v`
- **Baseline Pass:** `PASS [tb_rv_csr] MTVEC properly 4-byte aligned`
- **Mutant Fail Evidence:** `FAIL [111000] mtvec_out: got=0000000000001043 exp=0000000000001040`
- **Restored Pass:** `PASS [tb_rv_csr] Restored original RTL passes 100%`
- **Outcome:** MUTANT KILLED

### MUT-05: PLIC Interrupt Target Routing Suppression
- **Target File:** `backend/plic/plic.v`
- **Target Testbench:** `backend/plic/tb_plic.v`
- **Baseline Pass:** `PASS [tb_plic] Interrupt targets routed`
- **Mutant Fail Evidence:** `FAIL [236000] s[0]=1 when src1 pending+enabled: got=0x0000000000000000 exp=0x0000000000000001`
- **Restored Pass:** `PASS [tb_plic] Restored original RTL passes 100%`
- **Outcome:** MUTANT KILLED

### MUT-06: FPU FMIN/FMAX IEEE 754 Result Inversion
- **Target File:** `backend/rv_fpu/rv_fpu.v`
- **Target Testbench:** `backend/rv_fpu/tb_fresh_rv_fpu.v`
- **Baseline Pass:** `PASS [tb_fresh_rv_fpu] IEEE 754 operations pass`
- **Mutant Fail Evidence:** `ERROR [T9a]: FMIN.S failed: expected FFFFFFFF40000000, got ffffffffbfffffff`
- **Restored Pass:** `PASS [tb_fresh_rv_fpu] Restored original RTL passes 100%`
- **Outcome:** MUTANT KILLED

## Qualification Statement

All 6 evaluated architectural mutation tests were conclusively detected and killed by their targeted verification suites,
demonstrating **100% test sensitivity (6 of 6 killed)** on the targeted failure modes.
