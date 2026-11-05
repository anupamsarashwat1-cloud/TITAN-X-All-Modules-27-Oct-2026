# SMVDU TITAN X — Comprehensive Verification Gap & Test Quality Audit Report

**Document Identity:** `TITAN_X_VERIFICATION_GAP_REPORT.md`  
**Target System:** SMVDU TITAN X Multicore 64-bit RISC-V SoC  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Repository Branch:** `repository/migration-2026-11-04`  
**Classification:** Independent Principal RTL Verification Audit  

---

## 1. Executive Summary & Verification Baseline

The previous qualification artifacts in the repository (`artifacts/qualification/regression_results.json` and `VERIFICATION_GUIDE.md`) claim:
> *"116 of 116 Testbenches PASS (100% Qualification Success Rate), including Full SoC Integration and Gate Qualification."*

An exhaustive, independent technical audit of the verification suites, simulation logs, and testbench source code reveals that this **"100% PASS" verdict is a dangerous false positive**. 

The existing test suite suffers from severe architectural defects:
1. **Vacuous Top-Level Assertions:** The primary SoC top testbench ([tb_titan_x_top.v](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/tb_titan_x_top.v)) checks only that external pins are driven (i.e. not floating `X`), executes zero software instructions, initiates zero bus transactions, and calls `$display("PASS")` unconditionally.
2. **Mock Interconnects Bypassing Buggy RTL:** Integration testbenches such as [tb_integ_peripheral_bus.v](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/verification/integration/tb_integ_peripheral_bus.v) completely bypass `titan_x_top.v`, instantiating peripherals with handwritten local decoders that concealed a fatal top-level APB address collision (`DEF-ARCH-01`) affecting 9 peripherals.
3. **Decoupled Security Testing:** [tb_secure_boot.v](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/secure_boot/tb_secure_boot.v) tests the crypto FSM against pre-computed test vectors, but never verifies whether the authenticated data is what the CPU executes (`DEF-SEC-01`).
4. **Toolchain Gaps:** Formal verification scripts (`sby`) are completely inoperable on the current host system due to missing tool dependencies (`BLOCKED`).

---

## 2. Anatomy of False Passes & Vacuous Testbenches

### 2.1 Case Study 1: The Vacuous Top-Level Testbench (`tb_titan_x_top.v`)
- **Claim:** "Full SoC boot and peripheral integration verified green."
- **Source Inspection:** [tb_titan_x_top.v:120-172](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/tb_titan_x_top.v#L120-L172)
```verilog
        // 5.3.1: DDR CK_P should be toggling (PHY active)
        if (ddr_ck_p !== 1'bx)
            $display("PASS ddr_ck_p driven (%b) — DDR PHY clock active ✅", ddr_ck_p);
        else begin $display("FAIL ddr_ck_p = X"); errors=errors+1; end

        // 5.3.4: UART TX idle = 1 (line idle high)
        if (uart_tx[0] === 1'b1)
            $display("PASS uart_tx[0]=1 — UART0 TX idle ✅");

        // 5.4: Wait for DDR controller init
        repeat(1000) @(posedge clk);
        if (ddr_cs_n !== 1'bx)
            $display("PASS ddr_cs_n=%b — DDR command bus active ✅", ddr_cs_n);

        if (errors == 0)
            $display("TITAN-X SoC VERDICT: ✅ PASS — All integration checks passed");
        $finish;
```
- **The Reality:**  
  - **No software is executed.** The testbench never checks if the core fetches instructions, advances `pc`, or executes code.
  - **No bus accesses occur.** Not a single read or write is issued to DDR, SRAM, BootROM, or any peripheral.
  - **Result:** Complete false confidence. A broken core or deadlocked interconnect would still pass this testbench.

---

### 2.2 Case Study 2: Mocked Decoder Masking Fatal APB Collision (`tb_integ_peripheral_bus.v`)
- **Claim:** "AXI to AHB to APB peripheral integration verified."
- **Source Inspection:** [verification/integration/tb_integ_peripheral_bus.v:56-60](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/verification/integration/tb_integ_peripheral_bus.v#L56-L60)
```verilog
    // APB address decode (written locally in testbench!)
    wire psel_uart0 = psel && (paddr[31:12] == 20'h10000);
    wire psel_rtc   = psel && (paddr[31:12] == 20'h10010);

    wire [31:0] prdata_mux = psel_uart0 ? prdata_uart0 :
                              psel_rtc   ? prdata_rtc   : 32'h0;
```
- **The Actual Top-Level RTL:** [top/titan_x_top/titan_x_top.v:647](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L647)
```verilog
    wire psel_uart0 = psel && (paddr[31:16] == 16'h4001 || paddr[31:12] == 20'h40000 || paddr[31:12] == 20'h10000);
```
- **The Reality:**  
  - In `titan_x_top.v`, `paddr[31:16] == 16'h4001` matches all addresses `0x4001_0000` to `0x4001_FFFF`, masking 9 peripherals (RTC, GPIO, WDT, SPI, I2C, CLINT alias, SD/MMC, QSPI, VDMA).
  - The integration testbench **did not instantiate `titan_x_top`**. It created a standalone bench with an idealized, correct decoder, completely missing the catastrophic bug present in the actual chip RTL.

---

### 2.3 Case Study 3: Disconnected Watchdog Reset (`watchdog_timer.v`)
- **Claim:** "Watchdog timer verified."
- **The Reality:**  
  - [tb_watchdog_timer.v](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/peripherals/watchdog_timer/tb_watchdog_timer.v) tests the timer standalone and verifies `wdt_reset_n` toggles.
  - In [titan_x_top.v:1036, 1042](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/top/titan_x_top/titan_x_top.v#L1036), `wdt_reset_n` is an internal net with **zero sinks**.
  - No integration testbench checked whether watchdog expiration actually resets the processor cores or system.

---

### 2.4 Case Study 4: Decoupled Secure Boot Authentication
- **Claim:** "Cryptographic Secure Boot fully verified with NIST test vectors."
- **The Reality:**  
  - `tb_secure_boot.v` feeds 59 words into `secure_boot.v` and verifies that `boot_pass` asserts.
  - No testbench verified what happens after `boot_pass` asserts: `u_core0` boots from `u_boot_rom` (`axi_rom.v`), executing `firmware.hex` which was never checked by `secure_boot.v`.

---

## 3. Systematic Verification Gap Analysis Matrix

The table below catalogs critical missing verification scenarios across the SoC subsystems:

| Subsystem | Verified by Unit TB | Verified in SoC Top | Critical Missing Test Scenarios | Impact / Risk |
| :--- | :---: | :---: | :--- | :--- |
| **Interconnect (AXI/AHB/APB)** | Partial | **NO** | 1. Address decoder overlap / collision tests.<br>2. Concurrent multi-master backpressure on AXI crossbar.<br>3. DECERR handling on unmapped spaces. | Peripherals completely unreachable; bus lockup. |
| **CPU Core (RV64)** | Partial (RV64IM) | **NO** | 1. Illegal instruction traps for unsupported extensions (A, F, D, C).<br>2. Pipeline hazard stall/forwarding verification under backpressure.<br>3. MRET privilege state restoration. | Silent execution corruption or undefined trapping. |
| **L2 Cache & Coherence** | Partial (64KB) | **NO** | 1. True 2MB capacity parameter regression.<br>2. Multicore concurrent read/write MESI race conditions.<br>3. Snoop filter invalidation under heavy writeback contention. | Data corruption across cores; stale cache lines. |
| **DDR4 Subsystem** | Standalone BFM | Pin toggle only | 1. Back-to-back read/write burst interleaving.<br>2. Auto-refresh collision with CPU demand misses.<br>3. DFI timing and calibration failure recovery. | DRAM read data corruption; bus hangs during refresh. |
| **Root of Trust / Security** | Unit Vector Only | Pin toggle only | 1. Modified `firmware.hex` rejection test.<br>2. Truncated / malformed SHA message lengths.<br>3. Fault injection / glitch on `boot_pass` wire. | Complete security bypass; execution of malware. |
| **Watchdog & Reset Tree** | Standalone Unit | **NO** | 1. Watchdog timeout forcing core recovery.<br>2. Reset synchronization across 9 clock domains.<br>3. Warm reset vs cold reset state retention. | Permanent lockup requiring power cycling. |

---

## 4. Formal Verification Audit & SVA Assessment

### 4.1 Toolchain Status: BLOCKED
Formal verification via SymbiYosys (`sby`) was evaluated:
- **Command:** `which sby`
- **Result:** Not found on host `PATH`.
- **Status:** **BLOCKED**. No formal properties or bounded model checks can be executed natively in this environment.

### 4.2 SVA Inspection in RTL
- A search for SystemVerilog Assertions (`assert property`, `cover property`, `assume property`) in `Design Files of TITAN X/` indicates that assertions are virtually absent from the design RTL files.
- The existing codebase relies almost exclusively on procedural Verilog `if (...) $display("FAIL");` statements embedded in simulation testbenches.
- Critical safety invariants (e.g. mutual exclusion of AXI write grants, cache line exclusivity in MESI directory, deadlock freedom in crossbar) are not formally specified or proven.

---

## 5. Verification Architecture Recommendations

To transition the SMVDU TITAN X SoC from vacuous testing to genuine tapeout-grade qualification, the following verification infrastructure must be constructed:

1. **True Top-Level End-to-End Testbench:**
   - Replace `tb_titan_x_top.v` with an automated regression harness that loads compiled C/assembly test cases (`riscv-tests`) into `axi_rom`.
   - Monitor instruction retirement via `u_core0.u_wb.wr_en` and `wb_pc`.
   - Implement automated self-checking exit traps (writing `tohost` at `0x1000_1000`).

2. **Automated Interconnect Concurrency & Boundary Suite:**
   - Test every single APB address boundary and verify that no peripheral select (`psel_*`) fires on unauthorized addresses.
   - Inject concurrent DMA traffic from Ethernet, PCIe, and USB while Cores 0–3 execute memory-intensive matrix multiplication.

3. **Cryptographic Fault & Negative Verification Suite:**
   - Implement negative secure boot tests: alter 1 bit in `firmware.hex` and verify `core_rst_n` remains `0` indefinitely.
   - Verify that all DMA masters are held in reset or prevented from crossbar transactions while in `boot_fail` state.

4. **Integration of UVM / Modern Verification Framework:**
   - Upgrade the current procedural testbenches to a structured UVM environment with constrained-random stimulus, functional coverage models, and golden scoreboard predictors.
