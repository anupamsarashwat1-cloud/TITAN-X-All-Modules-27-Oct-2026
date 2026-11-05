# SMVDU TITAN X — Independent Architectural Plan Review Report

**Document Identity:** `TITAN_X_PLAN_REVIEW_REPORT.md`  
**Target System:** SMVDU TITAN X Multicore 64-bit RISC-V SoC  
**Reviewed Commit:** `af13cba6bc3bc97b8e0fb4a81badc3f742088821`  
**Repository Branch:** `repository/migration-2026-11-04`  
**Reviewer Role:** Independent Principal Architect & Plan Reviewer (Gemini Architectural Gate)  
**Status:** **APPROVED WITH INTEGRATED CORRECTIONS (3 CYCLES COMPLETED)**  

---

## 1. Executive Summary & Review Scope

In accordance with Phase 3 Section 9 of the engineering audit charter, an independent architectural review was conducted on the proposed remediation roadmap, task register, verification matrix, and architectural decision records. 

The review protocol executed three focused review and replanning cycles to challenge:
1. Root-cause assumptions and task dependencies.
2. Timing feasibility and hardware microarchitecture (specifically ECDSA multicycle execution and SRAM latency).
3. Testbench adequacy, negative testing, and prevention of false passes.

### Review Verdict: **PASSED — ALL CHALLENGES RESOLVED & PLAN UPDATED**

All identified planning concerns, microarchitectural hazards, and timeout dependencies were successfully addressed and integrated into the final task specifications and verification matrix.

---

## 2. Review Cycle 1: Root-Cause Assumptions & Security Boundaries

### Challenge 1.1: Root-of-Trust Coupling Race Condition (`DEF-SEC-01`)
- **Challenge Raised:** If `secure_boot` reads from `axi_rom` while the processor cores are in reset, could an electrical glitch or pre-reset instruction fetch create a bus collision or leak unauthenticated code?
- **Finding:** In `axi_rom.v`, `s_arready` is hardwired to `1'b1` out of reset. If the CPU initiates an AXI transaction while `secure_boot` is actively reading ROM words, data collision or starvation could occur.
- **Remediation Integrated into Plan (`TASK-04-01`):**
  1. Core reset `core_rst_n` must be strictly held low (`0`) during the entire verification window.
  2. The AXI slave port of `axi_rom` must assert `s_arready = 1'b0` until `boot_pass` asserts.
  3. A dedicated internal read port (`s_envm_*`) will be exposed exclusively to `secure_boot`, isolating the verification datapath from the AXI bus fabric.

### Challenge 1.2: APB Decoder Prefix Aliasing Scope (`DEF-ARCH-01`)
- **Challenge Raised:** Did `DEF-ARCH-01` capture all overlapping aperture masks in `titan_x_top.v`?
- **Finding:** Inspection of lines 652 and 667 revealed additional wide apertures:
  - `psel_rtc` has `|| paddr[31:16] == 16'h4002`.
  - `psel_clint` has `paddr[31:16] == 16'h0200 || paddr[31:12] == 20'h40015`.
- **Remediation Integrated into Plan (`TASK-01-01` / `ADR-06`):**
  - Deprecate all 16-bit prefix masks (`paddr[31:16] == ...`) across the entire APB decoder in `titan_x_top.v`. Enforce strict 4KB page decoding on `paddr[31:12]` across all 28 peripheral select lines.
  - Implement a synthesis assertion verifying that `psel_*` is strictly one-hot-zero.

---

## 3. Review Cycle 2: Timing Feasibility, Timeout Budgets & Memory Latency

### Challenge 2.1: ECDSA Multicycle Execution vs Secure Boot Timeout Budget (`DEF-SEC-05`)
- **Challenge Raised:** `TASK-03-02` redesigns the ECDSA engine to use a 256-cycle Montgomery multiplier, increasing verification latency to ~150,000 cycles. Does `secure_boot.v` support this duration?
- **CRITICAL FINDING:** In [secure_boot.v:423](file:///home/anupam-sarashwat/TITAN-X-2026-11-04/Design%20Files%20of%20TITAN%20X/security/secure_boot/secure_boot.v#L423):
  ```verilog
  if (timeout_cnt >= 12'd3500) begin
      auth_fail <= 1'b1;
      state     <= S_HALT;
  end
  ```
  The timeout counter `timeout_cnt` is a 12-bit register with a hardcoded threshold of **3,500 cycles**!
  If ECDSA takes 150,000 cycles, `secure_boot` will **prematurely timeout, assert auth_fail, and lock the system in S_HALT**!
- **Remediation Integrated into Plan (`TASK-03-02` / `TASK-04-01`):**
  - Widen `timeout_cnt` from 12 bits to **18 bits**.
  - Increase the timeout threshold in state `S_WAIT_ECDSA` from `12'd3500` to `18'd200000` cycles (allowing 2 ms at 100 MHz).
  - Explicitly document this dependency in `TITAN_X_TASK_REGISTER.csv`.

### Challenge 2.2: Synchronous SRAM 1-Cycle Latency in L2 Cache (`DEF-ARCH-04`)
- **Challenge Raised:** The existing `l2_cache_ctrl.v` reads behavioral `data_mem` and `tag_mem` combinationally. Replacing them with compiled foundry SRAM macros introduces a mandatory 1-cycle synchronous read latency.
- **Finding:** A direct swap without FSM adjustment would cause the tag-matching logic in `ST_LOOKUP` to sample unlatched, stale SRAM outputs, breaking cache hit detection.
- **Remediation Integrated into Plan (`TASK-05-01` / `ADR-05`):**
  - Restructure `l2_cache_ctrl` state machine to split tag lookup into two phases: `ST_LOOKUP_REQ` (issues address and chip select to SRAM macros) and `ST_LOOKUP_EVAL` (evaluates tag match on registered `dout` 1 cycle later).
  - Verify 1-cycle synchronous latency in `tb_l2_data_array.v` before top-level integration.

---

## 4. Review Cycle 3: Verification Rigor, Negative Testing & False-Pass Elimination

### Challenge 3.1: Prevention of Vacuous Passes in Top-Level Testbench (`DEF-VERIF-01`)
- **Challenge Raised:** How does the updated `tb_titan_x_top.v` guarantee that a simulation cannot report PASS if the core fails to execute software?
- **Finding:** Simple exit codes (e.g. checking `tohost != 0`) can be satisfied if uninitialized memory contains non-zero data.
- **Remediation Integrated into Plan (`TASK-09-01`):**
  - Dual-criteria completion check:
    1. **Architectural Writeback Check:** The testbench monitors `u_core0.u_wb.wr_en` and logs every retired instruction counter.
    2. **Serial Output Verification:** The testbench captures the UART0 TX line (`uart_tx[0]`), deserializes characters into a string buffer, and asserts that the string contains `"TITAN-X BOOT SUCCESS\n"`.
    3. **Exit Code Trapping:** The core writes a 64-bit signature `0x0000_0000_0000_0001` to `tohost` at `0x1000_1000`. Only when both serial match and tohost signature match will `PASS` be emitted.

### Challenge 3.2: Watchdog Reset Pulse Width Across Clock Domains (`DEF-ARCH-02`)
- **Challenge Raised:** If `wdt_reset_n` asserts for only 1 cycle, will it reliably reset state machines in asynchronous clock domains (DDR PHY, HDMI, GMII)?
- **Finding:** A 1-cycle pulse can be swallowed by multi-flop synchronizers in slower clock domains (e.g. RTC 32.768 kHz or HDMI pixel clock).
- **Remediation Integrated into Plan (`TASK-04-02` / `ADR-07`):**
  - The watchdog timer FSM must hold `wdt_reset_n` low for at least **64 clock cycles**.
  - Route `wdt_reset_n` through `reset_sync.v` synchronizer instances for each of the 9 clock domains before clearing internal state.

---

## 5. Review Acceptance & Gate Sign-Off

All critical challenges raised across the three review cycles have been incorporated into the execution artifacts:
- **Baseline Alignment:** All artifacts reference commit `af13cba6bc3bc97b8e0fb4a81badc3f742088821`.
- **Dependency Tracking:** Every task has explicit preconditions and prohibited files.
- **Verification Readiness:** Every task has dedicated normal, boundary, invalid, and reset test plans.
- **Architectural Soundness:** All design decisions are formally approved in `TITAN_X_DECISION_LOG.md`.

**Planning Phase 3 is officially APPROVED. Proceeding to implementation is authorized once user approval is received.**
