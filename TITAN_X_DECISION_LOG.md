# SMVDU TITAN X — Architectural Decision Log (ADR)

**Document Identity:** `TITAN_X_DECISION_LOG.md`  
**Target System:** SMVDU TITAN X Multicore 64-bit RISC-V SoC  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Repository Branch:** `repository/migration-2026-11-04`  
**Classification:** Engineering Architecture Decision Records  

---

## Index of Architectural Decision Records

- [ADR-01: Root-of-Trust Coupling & Boot ROM Authentication](#adr-01-root-of-trust-coupling--boot-rom-authentication)
- [ADR-02: Trust Anchor & Public Key Provisioning Architecture](#adr-02-trust-anchor--public-key-provisioning-architecture)
- [ADR-03: Secure Boot Image Header Format & Monotonic Anti-Rollback Counters](#adr-03-secure-boot-image-header-format--monotonic-anti-rollback-counters)
- [ADR-04: ECDSA P-256 Engine Microarchitecture & Timing Closure](#adr-04-ecdsa-p-256-engine-microarchitecture--timing-closure)
- [ADR-05: L2 Cache Physical Realization & SRAM Macro Banking](#adr-05-l2-cache-physical-realization--sram-macro-banking)
- [ADR-06: APB Peripheral Address Space Decoding & Aperture Strictness](#adr-06-apb-peripheral-address-space-decoding--aperture-strictness)
- [ADR-07: Watchdog Timer Hardware Reset Tree Integration](#adr-07-watchdog-timer-hardware-reset-tree-integration)
- [ADR-08: Processor Core Privileged Architecture & MMU Evolution Roadmap](#adr-08-processor-core-privileged-architecture--mmu-evolution-roadmap)

---

## ADR-01: Root-of-Trust Coupling & Boot ROM Authentication

### Status
**APPROVED / MANDATORY FOR IMPLEMENTATION**

### Context & Problem Statement
In the baseline RTL at commit `af13cba6bc3bc97b8e0fb4a81badc3f742088821`, `secure_boot.v` authenticates a 59-word hardcoded test array `envm_image` in `titan_x_top.v`. Upon verification, `boot_pass` asserts, releasing `core_rst_n`. However, Core 0 vectors to `RESET_PC = 0x1000_0000`, fetching from `u_boot_rom` (`axi_rom.v` loading external `firmware.hex`), which is never checked by `secure_boot` (`DEF-SEC-01` / CWE-347).

### Decision
1. `secure_boot` must directly read and hash the binary image stored in the boot memory before asserting `boot_pass`.
2. The boot ROM interface will be enhanced with a dedicated pre-boot read port routed exclusively to `secure_boot`.
3. The CPU core reset `core_rst_n` remains asserted low (`0`) while `secure_boot` reads the header, computes the hash over `axi_rom`, and verifies the ECDSA signature.
4. Only upon signature verification match and hash integrity confirmation will `boot_pass` assert, unlocking the AXI slave interface of `axi_rom` for CPU instruction fetching.

### Alternatives Considered & Rejected
- *Alternative A: Shadowing to on-chip SRAM.* Copying firmware to SRAM before hashing. Rejected for Phase 4 because it introduces additional DMA/copy FSM complexity; direct read of ROM is simpler and eliminates race conditions.
- *Alternative B: Runtime cryptographic hashing during instruction fetch.* Rejected due to unacceptable latency on instruction cache misses.

### Consequences
- **Positive:** Mathematically eliminates CWE-347. An attacker modifying `firmware.hex` cannot boot the system.
- **Negative:** Boot time increases by the time taken to hash `axi_rom` depth (approx. 1024 cycles at 50 MHz = 20.48 µs).

---

## ADR-02: Trust Anchor & Public Key Provisioning Architecture

### Status
**APPROVED / MANDATORY FOR IMPLEMENTATION**

### Context & Problem Statement
The root NIST P-256 public key is hardcoded as an immutable `localparam` in silicon logic gates (`DEF-SEC-02` / CWE-1393). If the private key is compromised, every manufactured chip is permanently compromised with zero remediation path.

### Decision
1. Implement a dedicated 1024-bit One-Time Programmable (OTP) eFuse controller model (`efuse_ctrl.v`).
2. Store the SHA-256 digest of up to 4 authorized Root Public Keys in eFuse registers (Key Slots 0–3).
3. Implement a 4-bit revocation bitmask in eFuses. A blown revocation bit permanently disables the corresponding key slot.
4. The incoming firmware header supplies the active Root Public Key. `secure_boot` hashes the supplied public key, verifies that its hash matches an unrevoked eFuse slot, and then uses that public key to verify the firmware signature.

### Consequences
- **Positive:** Enables in-field key rotation and revocation without requiring physical silicon re-spins.
- **Negative:** Adds a small hardware eFuse macro interface and state machine to `secure_boot.v`.

---

## ADR-03: Secure Boot Image Header Format & Monotonic Anti-Rollback Counters

### Status
**APPROVED / MANDATORY FOR IMPLEMENTATION**

### Context & Problem Statement
The baseline boot header has no security version or counter field (`DEF-SEC-03` / CWE-1037), exposing the SoC to firmware downgrade attacks where an attacker flashes older, signed, vulnerable firmware.

### Decision
Define a standardized 64-word (256-byte) Boot Image Header:
- Word 0: Magic Number (`0x5449544E` — "TITN")
- Word 1: Header Version (`0x00010000`)
- Word 2: Security Version / Monotonic Counter (32-bit unsigned integer)
- Word 3: Key Slot Index (0–3)
- Word 4: Payload Length in Bytes
- Word 5: Execution Entry Point Address (`0x1000_0100`)
- Words 6–7: Reserved (zero-padded)
- Words 8–15: SHA-256 Digest of Payload (256-bit)
- Words 16–23: Root Public Key $Q_x$ (256-bit)
- Words 24–31: Root Public Key $Q_y$ (256-bit)
- Words 32–39: Signature $r$ (256-bit)
- Words 40–47: Signature $s$ (256-bit)
- Words 48–63: Header HMAC / Integrity Padding

`secure_boot` compares Word 2 against the hardware monotonic counter in eFuses. If `Header.SecurityVersion < eFuse.SecurityVersion`, `secure_boot` halts and locks the core in reset.

---

## ADR-04: ECDSA P-256 Engine Microarchitecture & Timing Closure

### Status
**APPROVED / MANDATORY FOR IMPLEMENTATION**

### Context & Problem Statement
The baseline `ecdsa_engine.v` executes 256-bit modular multiplication and 512-bit modulo reduction combinatorially in single-cycle functions, cascading up to 26 multiplications per cycle (`DEF-SEC-05`). This causes logic synthesis tools (Yosys) to stall and fails physical timing closure completely.

### Decision
1. Deprecate the combinational `mod_mul_p` and `mod_mul_n` functions.
2. Implement a multicycle iterative Montgomery multiplier (`mont_mul_256`) that computes $A 	imes B 	imes R^-1 \pmod P$ in 258 clock cycles.
3. Restructure `jac_double` and `jac_add_aff` into sequential micro-coded operations scheduled over multiple clock cycles.
4. Total signature verification time will increase to ~150,000 clock cycles (~1.5 ms at 100 MHz), which is well within acceptable secure boot latency budgets (< 50 ms).

### Consequences
- **Positive:** Enables clean Yosys synthesis, reasonable standard-cell gate count (< 45,000 gates), and timing closure at 100+ MHz.
- **Negative:** Point addition and doubling are multicycle; verification requires tracking multicycle completion handshakes.

---

## ADR-05: L2 Cache Physical Realization & SRAM Macro Banking

### Status
**APPROVED / MANDATORY FOR IMPLEMENTATION**

### Context & Problem Statement
`l2_cache_ctrl.v` implements cache arrays as behavioral flip-flop registers (`reg [63:0] data_mem ...`), creating over 550,000 DFFs for 64 KB and requiring 16.7 million DFFs if scaled to 2 MB (`DEF-ARCH-04`). Furthermore, `u_l2_cache` falls back to 64 KB because parameters are not propagated (`DEF-ARCH-03`).

### Decision
1. Scale the architectural cache parameters cleanly:
   - For ASIC 180nm tapeout feasibility: Target a banked **256 KB or 512 KB** cache configuration (using 4 banks of compiled synchronous SRAM macros).
   - If 2 MB is required, integrate 4 banks of $512	ext{ KB} 	imes 8$ SRAM macros.
2. Replace behavioral `data_mem` and `tag_mem` in `l2_cache_ctrl.v` with instantiated `l2_data_array` modules wrapping foundry macros (`sram_32x64_180nm` / compiled SRAM blocks).
3. The cache controller FSM must account for synchronous 1-cycle SRAM read latency (read request in cycle $N$, valid read data sampled in cycle $N+1$).
4. Explicitly propagate parameters in `titan_x_top.v`:
   ```verilog
   l2_cache_top #(.WAYS(`L2_WAYS), .SETS(`L2_SETS)) u_l2_cache (...);
   ```

---

## ADR-06: APB Address Space Decoding & Aperture Strictness

### Status
**APPROVED / MANDATORY FOR IMPLEMENTATION**

### Context & Problem Statement
In `titan_x_top.v:647`, `psel_uart0` matches `paddr[31:16] == 16'h4001`, colliding with all peripherals located between `0x4001_0000` and `0x4001_FFFF`, corrupting writes and blinding reads across 9 peripherals (`DEF-ARCH-01`).

### Decision
1. Eliminate all 16-bit wide prefix apertures from the APB address decoder in `titan_x_top.v`.
2. Enforce strict 4KB page decoding on `paddr[31:12]` for all 28 APB peripherals:
   - UART0: `paddr[31:12] == 20'h40000 || paddr[31:12] == 20'h10000`
   - RTC: `paddr[31:12] == 20'h40010 || paddr[31:12] == 20'h10010`
   - GPIO: `paddr[31:12] == 20'h40011`
   - WDT: `paddr[31:12] == 20'h40012`
   - SPI: `paddr[31:12] == 20'h40013`
   - I2C: `paddr[31:12] == 20'h40014`
   - CLINT Alias: `paddr[31:12] == 20'h40015`
   - SD/MMC: `paddr[31:12] == 20'h40016`
   - QSPI: `paddr[31:12] == 20'h40017`
   - VDMA: `paddr[31:12] == 20'h40018`
3. Add a default assertion ensuring that for any `paddr`, at most one `psel_*` signal is asserted simultaneously.

---

## ADR-07: Watchdog Timer Hardware Reset Tree Integration

### Status
**APPROVED / MANDATORY FOR IMPLEMENTATION**

### Context & Problem Statement
In `titan_x_top.v:1036, 1042`, the watchdog reset wire `wdt_reset_n` is floating with zero sinks (`DEF-ARCH-02`). Timeout cannot reset the CPU cores.

### Decision
1. Connect `wdt_reset_n` directly to the reset generation logic in `titan_x_top.v`:
   ```verilog
   assign core_rst_n = rst_n & boot_pass & wdt_reset_n;
   ```
2. Integrate `wdt_reset_n` into `reset_sync` to ensure clean asynchronous assertion and synchronous deassertion across all 9 clock domains.
3. Configure the watchdog timer register map so that timeout first asserts an interrupt (`plic_irq[14]`) for 1024 cycles; if unserviced, it asserts `wdt_reset_n = 0` for 64 cycles to force full system recovery.

---

## ADR-08: Processor Core Privileged Architecture & MMU Evolution Roadmap

### Status
**APPROVED / MANDATORY FOR IMPLEMENTATION**

### Context & Problem Statement
The core implements RV64IM_Zicsr Machine-Mode Only. FPU, Atomics, S/U-modes, and MMU are unintegrated or stubbed (`DEF-ARCH-05`). It cannot run Linux.

### Decision
Adopt a phased core capability roadmap:
- **Milestone 1 (Immediate Tapeout Baseline):** Formally document the core as **RV64IM_Zicsr Machine-Mode Only**. Fully qualify integer execution, CSR operations, timer interrupts, and hardware traps. Stabilize pipeline hazard forwarding and verify all `riscv-tests/rv64ui` and `rv64um` suites.
- **Milestone 2 (OS-Capable Evolution):** Integrate atomic instructions (RV64A), Supervisor mode CSRs (`sstatus`, `stvec`, `satp`, `sepc`, `scause`), and connect the Sv39 Page Table Walker (`rv_ptw.v`) to the memory arbiter to support FreeBSD / Linux boot.
