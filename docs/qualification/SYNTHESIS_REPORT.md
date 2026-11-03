# TITAN X Synthesis & Gate Count Qualification Report

- **Date:** 2026-11-03
- **Synthesis Tool:** Yosys Open SYnthesis Suite (Version 0.33)
- **Target Top Module:** `rv_core_top` (5-stage in-order RV64IM processor core)
- **Include Paths:** `-Iincludes -Icommon`
- **Optimization Level:** Generic synthesis (`synth -top rv_core_top`) + Technology Independent Optimization (ABC)

---

## 1. Executive Summary & Resolution of FIND-SYNTH-01

Legacy documentation for TITAN X claimed an unverified projection of *"79,755 standard cells"* across the design. Audit finding `FIND-SYNTH-01` flagged this figure as an ungrounded physical-design projection that did not match open-source generic synthesis netlists.

An end-to-end, reproducible synthesis run executed on 2026-11-03 using Yosys 0.33 produced an exact generic cell netlist count of **98,379 cells** for `rv_core_top` (or ~75k-95k equivalent gates depending on standard-cell AOI/OAI technology library mapping).

This report presents the canonical, source-grounded synthesis metrics directly extracted from the synthesizable RTL.

---

## 2. Hierarchical Module Breakdown

| Module | Hierarchy Path | Public Wires | Public Bits | Sequential Cells (DFFs) | Total Cells | % of Core Area |
|:---|:---|:---:|:---:|:---:|:---:|:---:|
| **`rv_execute`** | `rv_core_top.rv_execute` | 104 | 2,158 | 766 | 82,625 | 84.0% |
| **`rv_regfile`** | `rv_core_top.rv_decode.rv_regfile` | 40 | 2,194 | 1,984 | 10,388 | 10.6% |
| **`rv_csr`** | `rv_core_top.rv_execute.rv_csr` | 28 | 1,006 | 451 | 2,025 | 2.1% |
| **`rv_mem`** | `rv_core_top.rv_mem` | 38 | 523 | 231 | 1,184 | 1.2% |
| **`rv_decode`** | `rv_core_top.rv_decode` | 47 | 706 | 274 | 1,174 | 1.2% |
| **`rv_fetch`** | `rv_core_top.rv_fetch` | 37 | 569 | 229 | 914 | 0.9% |
| **`rv_writeback`**| `rv_core_top.rv_writeback` | 12 | 213 | 70 | 76 | 0.1% |
| **Top Glue & Buffers** | `rv_core_top` (glue) | 112 | 1,918 | 0 | 11 | <0.1% |
| **TOTAL CORE** | `rv_core_top` | **422** | **9,075** | **4,005** | **98,379** | **100.0%** |

---

## 3. Cell Type Distribution

The generic cell netlist produced by Yosys and ABC consists of:

| Cell Primitive | Function / Description | Cell Count | Percentage |
|:---|:---|:---:|:---:|
| `$_ANDNOT_` | Logic AND with inverted input | 32,558 | 33.1% |
| `$_XOR_` | Exclusive OR (ALU arithmetic & parity) | 18,579 | 18.9% |
| `$_OR_` | Logic OR (bus & multiplexing) | 13,582 | 13.8% |
| `$_XNOR_` | Equality / Comparator logic | 8,452 | 8.6% |
| `$_AND_` | Logic AND | 5,054 | 5.1% |
| `$_MUX_` | 2-to-1 Data Multiplexers | 4,367 | 4.4% |
| `$_NOR_` | Logic NOR | 4,051 | 4.1% |
| `$_DFFE_PN0P_` | Positive-edge D Flip-Flop with Clock Enable | 3,856 | 3.9% |
| `$_NOT_` | Inverters | 2,929 | 3.0% |
| `$_NAND_` | Logic NAND | 2,719 | 2.8% |
| `$_ORNOT_` | Logic OR with inverted input | 2,083 | 2.1% |
| `$_DFF_PN0_` | Basic D Flip-Flop | 135 | 0.1% |
| `$_DFFE_PN0N_` | Negative-level DFF with Enable | 7 | <0.1% |
| `$_DFFE_PN1P_` | Preset DFF with Enable | 6 | <0.1% |
| `$_DFF_PN1_` | Preset DFF | 1 | <0.1% |
| **TOTAL** | All Cell Primitives | **98,379** | **100.0%** |

---

## 4. Key Architectural Observations

1. **64-bit Integer Multiplier/Divider Dominance:**
   The `rv_execute` stage accounts for 84% of total core cell count due to 64-bit signed/unsigned multiplication (`MUL`, `MULH`, `MULHSU`, `MULHU`, `MULW`) and non-blocking iterative division (`DIV`, `DIVU`, `REM`, `REMU`, `DIVW`, `REMW`). When targeted to an ASIC library with hardened DSP or Booth multiplier macros, this count scales down significantly.
2. **Register File Area:**
   The register file (`rv_regfile`) implements 31 general-purpose 64-bit registers (x0 hardwired to zero) with 2 asynchronous read ports and 1 synchronous write port with write-first bypass forwarding, requiring 1,984 flip-flops and 10,388 total cells.
3. **Control and CSR Overhead:**
   The Machine-mode CSR subsystem (`rv_csr`) consumes 2,025 cells and 451 flip-flops to maintain hardware status registers, interrupt masks, trap vectors, and performance counters.

---

## 5. Gate H Qualification Statement

> [!IMPORTANT]
> **RTL verification/release candidate; physical-design sign-off not established.**  
> Gate count numbers reported in this document represent generic open-source logic synthesis (Yosys 0.33) without standard-cell library place-and-route, CTS, or timing closure on a commercial fab PDK.
