# SMVDU TITAN X — ISA & Architectural Capability Matrix

**Document Version:** 1.0  
**Date:** 2026-11-17  
**Scope:** Authoritative classification of processor core and platform architectural capabilities.

---

## 1. Executive Determination

The active, verified instruction set architecture of the SMVDU TITAN X processor cores (Harts 0–3 Application Cores, Hart 4 Monitor Core) is **RV64IM_Zicsr in Machine-mode (M-mode)** with physical addressing.

All previous documentation claims referring to "RV64GC", "RV64G", "Unix/Linux-ready", or "Hardware Floating Point" describe aspirational or unintegrated standalone research modules and are hereby formally retired in the canonical repository.

---

## 2. Processor Core Capability Breakdown

| Architectural Feature | Classification | RTL Implementation Reference | Verification Evidence | Technical Description & Status |
|---|---|---|---|---|
| **RV64I Base Integer ISA** | **Implemented & Verified** | `frontend/rv_decode/rv_decode.v:70-140` | `tb_rv_core_top`, `tb_rv_regfile` | 64-bit integer ALU instructions (ADD, SUB, SLL, SRL, SRA, SLT, SLTU, XOR, OR, AND, LUI, AUIPC, JAL, JALR, Branches, Loads, Stores). |
| **RV64M Multiply / Divide** | **Implemented & Verified** | `frontend/rv_decode/rv_decode.v:145-165`, `backend/rv_execute/rv_execute.v` | `tb_rv_core_mext` | Full 64-bit and 32-bit (W-suffix) multiplication and division (MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU, MULW, DIVW, DIVUW, REMW, REMUW). |
| **Zicsr (CSR Access)** | **Implemented & Verified** | `backend/rv_csr/rv_csr.v`, `frontend/rv_decode/rv_decode.v:180` | `tb_rv_core_csr` | Machine-level CSR instructions (CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI). Supports `mstatus`, `mie`, `mtvec`, `mscratch`, `mepc`, `mcause`, `mtval`, `mip`, `mcycle`, `minstret`. |
| **Privilege Modes** | **Partially Implemented (M-mode Only)** | `backend/rv_csr/rv_csr.v` | `tb_rv_core_traps_comprehensive` | Machine-mode (M-mode) execution, traps, and interrupt handling fully operational. Supervisor-mode (S-mode) and User-mode (U-mode) CSR delegations are not supported. |
| **A (Atomic Extension)** | **Not Integrated** | `backend/rv_dcache/rv_dcache.v:39-43` | `tb_rv_dcache` | LR/SC interface signals exist on D-cache ports but are tied off (`is_lr = 0`, `is_sc = 0`). AMO ALU operations are not integrated in the execute pipeline. |
| **F & D (Single & Double Float)** | **Not Integrated** | `backend/rv_fpu/rv_fpu.v`, `backend/rv_core_top/rv_core_top.v:400` | Standalone `tb_rv_fpu` only | An IEEE 754-2008 FPU RTL module exists in `backend/rv_fpu/` but is not wired into `rv_core_top.v` (`.fpu_result(64'h0), .fpu_valid(1'b0)`). Floating-point register file (`f0-f31`) is absent. |
| **C (Compressed Instructions)** | **Not Implemented** | `frontend/rv_decode/rv_decode.v:65` | `tb_rv_decode` | All non-32-bit instructions (`instr[1:0] != 2'b11`) trap as illegal instructions (`illegal_instr = 1`). 16-bit instruction decompressor is not implemented. |
| **Sv39 MMU / Page Table Walker** | **Not Integrated** | `backend/rv_mmu/`, `backend/rv_ptw/`, `backend/rv_tlb/` | Standalone unit tests only | MMU, TLB, and PTW modules exist in the directory tree but are omitted from `rv_core_top.v`. Addressing is purely physical (40-bit PA). |
| **Physical Memory Protection (PMP)** | **Not Integrated** | `backend/rv_pmp/rv_pmp.v` | Standalone unit tests only | `rv_pmp.v` exists as a standalone block; no PMP checking logic is instantiated in the instruction or data memory paths of `rv_core_top.v`. |
| **L1 Instruction & Data Caches** | **Implemented & Verified** | `frontend/rv_icache/`, `backend/rv_dcache/` | `tb_rv_icache`, `tb_rv_dcache` | 32 KiB 8-way set-associative I-cache (SEC-DED ECC) and 32 KiB 8-way write-back D-cache per application core. |
| **Shared L2 Cache & Coherence** | **Implemented & Verified** | `memory/l2_cache_top/`, `memory/l2_snoop_filter/` | `tb_l2_cache_top`, `tb_multicore_coherence` | 16-way set-associative cache with MESI snoop-filter directory tracking 4 cores. |
| **Root of Trust Secure Boot** | **Implemented & Verified** | `security/secure_boot/`, `security/efuse_ctrl/` | `tb_secure_boot`, `tb_integ_security_chain` | Hardware eFuse RoT key anchoring, monotonic anti-rollback counter, FIPS 180-4 SHA-256, and NIST P-256 ECDSA container authentication. |

---

## 3. Platform Software Compatibility Assessment

1. **Bare-Metal & RTOS Environments:** **Fully Compatible.** FreeRTOS, Zephyr, RT-Thread, and custom bare-metal firmware targeting RV64IM_Zicsr execute natively.
2. **Standard Linux Distributions:** **Not Supported.** Modern Linux (Debian, Fedora, Ubuntu RISC-V) requires S-mode, U-mode, Sv39/Sv48 MMU page tables, and atomic memory operations (A-extension).
3. **Toolchain Compilation Target:** Software must be compiled with `-march=rv64im_zicsr -mabi=lp64`.
