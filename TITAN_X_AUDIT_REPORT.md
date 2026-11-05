# SMVDU TITAN X — Comprehensive Independent Engineering Audit Report

**Document Identity:** `TITAN_X_AUDIT_REPORT.md`  
**Target System:** SMVDU TITAN X Multicore 64-bit RISC-V SoC  
**Canonical Repository:** `https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04.git`  
**Branch:** `repository/migration-2026-11-04`  
**Exact Reviewed Commit SHA:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Secondary Workspace:** `/home/anupam-sarashwat/SMVDU_TITAN_X_RTL_to_GDS` (commit `84f559c61592bc7fc9f6f2c60248f688bd63eabd`)  
**Design Directory:** `Design Files of TITAN X/`  
**Audit Role:** Independent Principal SoC Architect, RTL Verification Engineer, and Hardware Security Auditor  
**Audit Status:** COMPLETE — 15 Defects Confirmed & Cataloged (Zero Source Modifications Permitted)  

---

## 1. Executive Summary & Audit Baseline

An exhaustive, independent engineering audit was conducted on the complete RTL codebase of the **SMVDU TITAN X** Multicore 64-bit RISC-V System-on-Chip (SoC). The review was performed strictly adhering to the non-negotiable rule that the **actual synthesizable RTL source code is the sole primary source of truth**. All documentation, previous agent assertions, and historical test reports were treated as secondary claims requiring independent source-code verification.

### Audit Verdict: **NOT QUALIFIED FOR FABRICATION / UNACCEPTABLE SILICON RISKS**

While the repository contains an impressive, broad inventory of 79 Verilog modules representing core processor, memory, cryptographic, and peripheral IP, the actual implemented SoC design suffers from **critical architectural defects, complete security bypass vulnerabilities, and a deceptive verification methodology** that reported false 100% pass rates.

### Primary Audit Highlights:
1. **Critical Security Vulnerability (DEF-SEC-01 / CWE-347):** Complete decoupling of the hardware Root of Trust from the executed firmware. The `secure_boot` module cryptographically authenticates a fixed 16-word dummy test payload in internal `envm_image`, while the processor cores boot from `u_boot_rom` (`axi_rom.v` loading external `firmware.hex`), which is **never authenticated**. An attacker can run arbitrary unauthorized bytecode while secure boot reports `PASS`.
2. **Critical Interconnect Defect (DEF-ARCH-01):** The APB address decoder in `titan_x_top.v` uses an erroneous prefix match `paddr[31:16] == 16'h4001` for UART0, colliding with all peripherals located from `0x4001_0000` to `0x4001_FFFF`. This masks read data from **9 critical peripherals** (RTC, GPIO, WDT, SPI, I2C, CLINT alias, SD/MMC, QSPI, VDMA) and corrupts UART0 configuration on any peripheral write.
3. **High Architectural Discrepancy (DEF-ARCH-03 / DEF-ARCH-04):** The L2 cache is elaborated as **64 KB** ($16\text{ ways} \times 64\text{ sets} \times 64\text{ B}$), directly contradicting claims and parameter definitions of **2 MB** ($16 \times 2048 \times 64\text{ B}$). Furthermore, the L2 cache completely bypasses the physical foundry SRAM macros (`sram_32x64_180nm`, `sram_512kx8_180nm`) and is synthesized as over **550,000 flat flip-flops**, causing severe area bloat and timing failures.
4. **Specification Divergence (DEF-ARCH-05):** The processor cores do not implement the claimed RV64GC Linux-capable ISA. FPU (`rv_fpu.v`) is tied off, Atomics (A) is tied low, Compressed (C) traps as illegal, Privileged modes are restricted to Machine-mode only (`mstatus.MPP` hardwired to `2'b11`), and the Sv39 MMU is unintegrated. The core cannot boot Linux.
5. **Disconnected Reliability Logic (DEF-ARCH-02):** The watchdog reset output `wdt_reset_n` is left floating with zero sinks in `titan_x_top.v`, preventing watchdog recovery on software or bus hang.
6. **Vacuous Verification Methodology (DEF-VERIF-01 / DEF-VERIF-02):** The claimed "116/116 PASS" qualification suite is heavily compromised by vacuous testbenches. The top-level testbench `tb_titan_x_top.v` checks only that clock/reset pins are non-floating without executing a single instruction, while integration testbenches mocked internal decoders to bypass top-level RTL bugs.

---

## 2. Source Identity & Toolchain Environment

| Parameter | Recorded Value / Identity | Evidence / Source |
| :--- | :--- | :--- |
| **Canonical Repository URL** | `https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04.git` | `git remote get-url origin` |
| **Active Branch** | `repository/migration-2026-11-04` | `git branch --show-current` |
| **Exact HEAD Commit SHA** | `af13cba6bc3bc97b8e0fb4a81badc3f742088821` | `git rev-parse HEAD` |
| **Working Tree Status** | Clean (untracked Phase 1/2 canonical reports added) | `git status --porcelain` |
| **Primary Design Directory** | `Design Files of TITAN X/` | Repository filesystem |
| **Top-Level Module** | `titan_x_top` (`Design Files of TITAN X/top/titan_x_top/titan_x_top.v`) | Module declaration |
| **Host Tool: Verilator** | Verilator 5.020 | `verilator --version` |
| **Host Tool: Yosys** | Yosys 0.33 | `yosys -V` |
| **Host Tool: Icarus Verilog** | Icarus Verilog 13.0 / 12.0 | `iverilog -V` |
| **Host Tool: GCC** | GCC 13.2.0 (Native x86_64 and riscv64-unknown-elf) | `gcc -v` |
| **Host Tool: SymbiYosys** | **UNAVAILABLE / BLOCKED** (`which sby` not found) | System PATH inspection |

---

## 3. Subsystem Audit: Security & Root of Trust

### 3.1 Authenticated Payload vs Execution Decoupling (DEF-SEC-01)
- **Source Code Evidence:**
  - [titan_x_top.v:881-956](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L881-L956): `secure_boot` is connected to internal array `envm_image [0:58]`. The verified payload consists of 16 dummy words (`0x10000000` to `0x1000003C`).
  - [titan_x_top.v:97-98](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L97-L98): `assign core_rst_n = rst_n & boot_pass;`
  - [titan_x_top.v:397-400](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L397-L400): Core 0 resets to `RESET_PC = 64'h0000_0000_1000_0000`.
  - [titan_x_top.v:340-356](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L340-L356): Address `0x1000_0000` maps to `u_boot_rom` (`axi_rom.v`), which loads `firmware.hex`.
- **Architectural Analysis:** The hardware Root of Trust and the processor execution datapath are completely disconnected. `secure_boot` authenticates an immutable internal test vector in eNVM. Once verified, it releases `core_rst_n`. The core then boots from `axi_rom`, which executes unauthenticated external instructions. This represents a complete failure of the secure boot promise (CWE-347).

### 3.2 Root Public Key Immutability (DEF-SEC-02)
- In [secure_boot.v:38-40](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/secure_boot/secure_boot.v#L38-L40), the NIST P-256 public key coordinates (`ROT_PUBKEY_QX`, `ROT_PUBKEY_QY`) are hardcoded as local parameters in standard-cell gates.
- While the design prevents an attacker from supplying an arbitrary public key in the image header ([secure_boot.v:238-249](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/secure_boot/secure_boot.v#L238-L249)), there is zero provision for key rotation, key revocation, or secondary root keys via OTP eFuses (CWE-1393).

### 3.3 Cryptographic Standards Compliance (DEF-SEC-04 / DEF-SEC-05)
- **SHA-256 Padding Omission:** Neither [secure_boot.v](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/secure_boot/secure_boot.v) nor [sha256_engine.v](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/peripherals/sha256_engine/sha256_engine.v) implements FIPS 180-4 message padding (`0x80`, zero padding, and 64-bit length). The hardware executes raw Davies-Meyer block compression. Any standard FIPS-compliant signature computed by OpenSSL or Python hashlib will fail verification in hardware.
- **ECDSA Timing Violation:** In [ecdsa_engine.v:108-115, 312-338](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/ecdsa_engine/ecdsa_engine.v#L108-L115), 256x256-bit modular multiplication and 512-bit modulo reduction are modeled as combinational functions chained up to 26 times in a single clock cycle, making physical synthesis and timing closure impossible.

---

## 4. Subsystem Audit: Processor Core & Pipeline

### 4.1 Implemented vs Claimed Architecture (DEF-ARCH-05)
The project claims a multicore RV64GC processor with Linux capability and Sv39 MMU. Inspection of the core RTL reveals:
- **RV64I / RV64M:** Implemented. Base 64-bit integer instructions and M-extension (MUL, MULH, DIV, REM) decode and execute properly.
- **RV64A (Atomics):** **Not implemented.** In [rv_core_top.v:382](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/backend/rv_core_top/rv_core_top.v#L382), `.is_amo(1'b0), .amo_funct5(5'h0)` are tied off. `OP_AMO` opcodes default to illegal instruction traps.
- **RV64F / RV64D (Floating Point):** **Not integrated.** In [rv_core_top.v:400](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/backend/rv_core_top/rv_core_top.v#L400), `.fpu_result(64'h0), .fpu_valid(1'b0)` are tied off.
- **RV64C (Compressed Instructions):** **Trapped as illegal.** In [rv_decode.v:83](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/frontend/rv_decode/rv_decode.v#L83), `illegal_comb = (instr_in[1:0] != 2'b11);`.
- **Privileged Architecture:** **M-Mode Only.** In [rv_csr.v:109](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/backend/rv_csr/rv_csr.v#L109), `mstatus_q <= 64'h0000_0000_0000_1800` (MPP hardwired to `2'b11`). Supervisor (S-mode) and User (U-mode) CSRs do not exist.
- **Virtual Memory / MMU Sv39:** **Disconnected.** In [titan_x_top.v:823](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L823), `mmu_ptw_arvalid = 5'b0`.

**Conclusion:** The core is an **RV64IM_Zicsr Machine-Mode Only** processor. It cannot boot Linux or execute general-purpose operating systems requiring virtual memory.

---

## 5. Subsystem Audit: Memory Hierarchy & Cache Geometry

### 5.1 L2 Cache Capacity Discrepancy (DEF-ARCH-03)
- **Claimed Specification:** 2 MB Shared L2 Cache ($16\text{ ways} \times 2048\text{ sets} \times 64\text{ B}$).
- **params.vh Definition:** [params.vh:57](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/includes/params.vh#L57) specifies `` `define L2_SETS 2048 ``.
- **Module Default Parameters:** [l2_cache_top.v:8-9](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/memory/l2_cache_top/l2_cache_top.v#L8-L9) specifies:
  ```verilog
  parameter WAYS = 16,
  parameter SETS = 64
  ```
- **Top-Level Instantiation:** In [titan_x_top.v:542](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L542):
  ```verilog
  l2_cache_top u_l2_cache ( ... );
  ```
  No parameters are passed. The instance elaborates with `SETS=64`.
- **Actual Elaborated Geometry:**
  $$	ext{Actual Capacity} = 16\text{ ways} \times 64\text{ sets} \times 64\text{ bytes/line} = \mathbf{65,536\text{ bytes (64 KB)}}$$
- **Defect Impact:** The actual cache is **32 times smaller** than claimed, resulting in massive cache thrashing under multi-threaded execution.

### 5.2 Bypass of Foundry SRAM Macros (DEF-ARCH-04)
- In [l2_cache_ctrl.v:112-118](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/memory/l2_cache_ctrl/l2_cache_ctrl.v#L112-L118):
  ```verilog
  reg [TAG_W-1:0]  tag_mem     [0:SETS-1][0:WAYS-1];
  reg              valid_mem   [0:SETS-1][0:WAYS-1];
  reg              dirty_mem   [0:SETS-1][0:WAYS-1];
  reg [DATA_W-1:0] data_mem    [0:SETS-1][0:WAYS-1][0:7];
  ```
- The entire L2 cache data and tag storage is implemented as **behavioral register flip-flops**.
- For 64 KB, this instantiates **550,000+ flip-flops**.
- If scaled to the claimed 2 MB, it would require **16.7 million flip-flops**.
- The hardened foundry SRAM macros (`sram_32x64_180nm`, `sram_512kx8_180nm`) and wrapper `l2_data_array` are completely unintegrated in `titan_x_top.v`.

---

## 6. Subsystem Audit: Interconnect & Peripheral Integration

### 6.1 APB Address Collision Masking 9 Peripherals (DEF-ARCH-01)
- **Source Code Evidence:** In [titan_x_top.v:647](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L647):
  ```verilog
  wire psel_uart0 = psel && (paddr[31:16] == 16'h4001 || paddr[31:12] == 20'h40000 || paddr[31:12] == 20'h10000);
  ```
- **Collision Scope:** The prefix `paddr[31:16] == 16'h4001` matches all addresses `0x4001_0000` to `0x4001_FFFF`.
- **Colliding Peripherals:**
  1. RTC (`0x4001_0000`)
  2. GPIO (`0x4001_1000`)
  3. Watchdog Timer (`0x4001_2000`)
  4. SPI Master (`0x4001_3000`)
  5. I2C Master (`0x4001_4000`)
  6. CLINT Alias (`0x4001_5000`)
  7. SD/MMC Storage (`0x4001_6000`)
  8. QSPI Controller (`0x4001_7000`)
  9. Video DMA (`0x4001_8000`)
- **Functional Consequence:**
  - **On Writes:** Both UART0 and the addressed peripheral capture the write data.
  - **On Reads:** In [titan_x_top.v:686-716](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L686-L716), `prdata_mux` evaluates `psel_uart0` first. Any read to these 9 peripherals returns UART0 data instead.

### 6.2 Floating Watchdog Reset (DEF-ARCH-02)
- In [titan_x_top.v:1036, 1042](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L1036):
  ```verilog
  wire wdt_reset_n;
  watchdog_timer u_wdt ( ... .wdt_reset_n(wdt_reset_n), ... );
  ```
- `wdt_reset_n` connects to no sink. If software hangs with interrupts disabled, the watchdog timer times out without resetting the system.

### 6.3 Disconnected Crossbar Slave 3 (DEF-ARCH-07)
- In [axi4_crossbar.v:124](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/interconnect/axi4_crossbar/axi4_crossbar.v#L124), addresses `0x0000_0000` to `0x0FFF_FFFF` map to Slave 3 (Low Memory / SRAM).
- In [titan_x_top.v:301-338](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L301-L338), Slave 3 is tied to a dummy DECERR generator returning `0xDEAD_DEAD_DEAD_DEAD` and `2'b11`. The documented on-chip scratchpad SRAM does not exist in the top level.

---

## 7. Complete Defect Register Cross-Reference

| Defect ID | Subsystem | Severity | Evidence Class | Summary of Failure |
| :--- | :--- | :---: | :---: | :--- |
| **DEF-SEC-01** | Security / RoT | **CRITICAL** | `CONFIRMED` | Hardware Root of Trust verifies dummy eNVM payload; executed `firmware.hex` is completely unauthenticated. |
| **DEF-SEC-02** | Security / Keys | **HIGH** | `CONFIRMED` | Immutable Root Public Key hardcoded in RTL gates; zero OTP/eFuse rotation or revocation. |
| **DEF-SEC-03** | Security / RoT | **MEDIUM** | `CONFIRMED` | Boot image header lacks monotonic counter, exposing chip to firmware rollback attacks. |
| **DEF-SEC-04** | Security / Crypto | **HIGH** | `CONFIRMED` | SHA-256 engine omits FIPS 180-4 padding and length encoding; standard signatures fail in hardware. |
| **DEF-SEC-05** | Security / Crypto | **HIGH** | `CONFIRMED` | ECDSA P-256 engine chains 26 256-bit mult/div ops in a single cycle, failing synthesis timing. |
| **DEF-ARCH-01** | Interconnect | **CRITICAL** | `CONFIRMED` | APB decoder collision (`16'h4001`) blinds CPU reads and corrupts writes across 9 peripherals. |
| **DEF-ARCH-02** | Reset / Reliability | **HIGH** | `CONFIRMED` | Watchdog reset wire `wdt_reset_n` is floating with zero sinks; watchdog cannot reset system. |
| **DEF-ARCH-03** | Memory / L2 Cache | **HIGH** | `CONFIRMED` | L2 Cache elaborates as 64 KB instead of the 2 MB claimed due to unpropagated parameters. |
| **DEF-ARCH-04** | Physical Design | **HIGH** | `CONFIRMED` | L2 cache synthesized as 550,000+ behavioral DFFs, bypassing foundry SRAM macros. |
| **DEF-ARCH-05** | Processor Core | **HIGH** | `CONFIRMED` | Core implements RV64IM M-mode only; FPU, Atomics, S-mode, and MMU are unintegrated or stubbed. |
| **DEF-ARCH-06** | SoC Integration | **MEDIUM** | `CONFIRMED` | 18 synthesizable RTL modules (35% of codebase) are dead code, disconnected from top level. |
| **DEF-ARCH-07** | Interconnect | **MEDIUM** | `CONFIRMED` | Crossbar Slave 3 (Low Memory) connected to hardwired DECERR; on-chip SRAM is missing. |
| **DEF-VERIF-01** | Verification | **HIGH** | `CONFIRMED` | Top-level testbench `tb_titan_x_top.v` verifies only pin toggles; executes zero instructions. |
| **DEF-VERIF-02** | Verification | **HIGH** | `CONFIRMED` | Integration testbench mocked the APB decoder, concealing the critical DEF-ARCH-01 bug. |
| **DEF-VERIF-03** | Verification | **MEDIUM** | `BLOCKED` | Formal verification toolchain (`sby`) is missing on host; formal proofs cannot be executed. |

---

## 8. Final Audit Conclusion & Next Steps

The SMVDU TITAN X SoC architecture represents a substantial engineering endeavor with high modular ambition. However, in its current state at commit `af13cba6bc3bc97b8e0fb4a81badc3f742088821`, **it cannot be qualified for tapeout or silicon fabrication**.

Immediate remediation must focus on:
1. Applying the recommended Phase A patches to fix the APB decoder collision and couple secure boot to the real execution image.
2. Integrating physical SRAM macros for the L2 cache.
3. Implementing true end-to-end CPU instruction regression testbenches.
