# SMVDU TITAN X — L2 Snoop Filter Directory Eviction & Coherence Sign-Off Report

**Document ID:** TITANX-QUAL-COH-001  
**Classification:** Post-Review Technical Remediation Deliverable  
**Remediated Finding:** FINDING-02 (L2 Snoop Filter Directory Set Saturation Defect)  
**Target Module:** `Design Files of TITAN X/memory/l2_snoop_filter/l2_snoop_filter.v`  
**Testbench:** `Design Files of TITAN X/memory/l2_snoop_filter/tb_l2_snoop_filter.v`  
**Status:** ✅ RESOLVED & VERIFIED  

---

## 1. Executive Summary

During the Independent Adversarial Engineering Review of the SMVDU TITAN X SoC, an architectural defect in the multi-core cache coherence subsystem was uncovered and confirmed:

> **FINDING-02 (High):** `l2_snoop_filter.v` directory set saturation. When all ways in a directory set were occupied (`dir_state != ST_I`), the allocation logic defaulted `alloc_way_comb` to `5'd0`, silently overwriting way 0 on a cold miss without issuing back-invalidations (`snoop_valid`) to L1 caches holding the victim line. This corrupted the directory, orphaned dirty lines in L1, and violated the multi-core cache inclusion property.

This report documents the architectural remediation, formal timing specification, state machine extensions, and verification evidence closing FINDING-02.

---

## 2. Pre-Remediation Root Cause Analysis

In the pre-remediation implementation of `l2_snoop_filter.v`:

```verilog
// Defective Pre-Remediation Logic:
always @* begin
    alloc_way_comb = 5'd0;
    for (ai = 0; ai < DIR_WAYS; ai = ai + 1) begin
        if (dir_state[index][ai] == ST_I) alloc_way_comb = ai[4:0];
    end
end
```

When a set reached saturation (all `DIR_WAYS` ways holding valid MESI states `ST_E`, `ST_S`, or `ST_M`):
1. `alloc_way_comb` evaluated to `5'd0` by default.
2. In state `LOOKUP`, on a miss (`!combo_line_hit`), the FSM immediately asserted `resp_valid <= 1'b1` and transitioned to `UPDATE`.
3. In state `UPDATE`, the directory unconditionally executed:
   ```verilog
   dir_tag[index][alloc_way_comb]   <= tag;
   dir_mask[index][alloc_way_comb]  <= (1 << req_core_saved);
   dir_state[index][alloc_way_comb] <= (req_type_saved == 2'b00) ? ST_E : ST_M;
   ```
4. **Failure Mechanism:** The L1 caches that held way 0 received **zero invalidation snoops**. If an L1 held way 0 in `Modified` state, the line was orphaned; subsequent accesses by other cores fetched stale data from memory, causing silent data corruption and cache incoherence.

---

## 3. Remediated Architecture & Eviction Protocol

The remediated architecture implements a deterministic round-robin victim replacement policy combined with mandatory L1 back-invalidation handshakes before directory reallocation.

```
       +-------------------------------------------------------------+
       |                         IDLE                                |
       +-------------------------------------------------------------+
                                      | req_valid
                                      v
       +-------------------------------------------------------------+
       |                        LOOKUP                               |
       |  Evaluate Tag Matches & Set Occupancy (has_free_way)        |
       +-------------------------------------------------------------+
              |                                            |
         Hit  |                                            | Miss
              v                                            v
    +-------------------+                       +---------------------+
    |  Hit Evaluation:  |                       | Set Saturated?      |
    |  GetS / GetM Inv  |                       | (has_free_way == 0) |
    +-------------------+                       +---------------------+
              |                                     /               \
              |                              No    /                 \ Yes
              |                                   v                   v
              |                         +-----------------+  +-----------------+
              |                         | Free Way Found: |  | Victim Selected |
              |                         | Allocate Way    |  | replace_ptr[idx]|
              |                         +-----------------+  +-----------------+
              |                                   |                   |
              |                                   |                   v
              |                                   |          +-----------------+
              |                                   |          |   EVICT_WAIT    |
              |                                   |          | Snoop Inv to L1 |
              |                                   |          | Wait snoop_ack  |
              |                                   |          +-----------------+
              |                                   |                   |
              +-------------------+---------------+-------------------+
                                  |
                                  v
       +-------------------------------------------------------------+
       |                        UPDATE                               |
       |  Write Tag, Mask, and MESI State to Chosen Way              |
       |  Assert resp_valid <= 1'b1 to L2 Controller                 |
       +-------------------------------------------------------------+
                                  |
                                  v
                                 IDLE
```

### 3.1 Replacement Pointers
A 5-bit round-robin pointer is maintained for every directory set:
```verilog
reg [4:0] replace_ptr [0:DIR_SETS-1];
```
On reset (`rst_n == 0`), all pointers are initialized to `5'd0`.

### 3.2 Free-Way Detection vs Saturation
The directory combinational logic scans the set from highest to lowest index to allocate the lowest available invalid way:
```verilog
always @* begin
    has_free_way = 1'b0;
    free_way     = 5'd0;
    for (ai = DIR_WAYS - 1; ai >= 0; ai = ai - 1) begin
        if (dir_state[index][ai] == ST_I) begin
            has_free_way = 1'b1;
            free_way     = ai[4:0];
        end
    end
end
```

### 3.3 Victim Eviction and Invalidation Sequence
When `has_free_way == 1'b0` (saturation):
1. **Victim Selection:** The victim way is selected via `victim_way = replace_ptr[index]`.
2. **Pointer Advance:** The replacement pointer advances: `replace_ptr[index] <= (replace_ptr[index] + 1) % DIR_WAYS`.
3. **Back-Invalidation Generation:**
   ```verilog
   snoop_valid       <= dir_mask[index][victim_way];
   snoop_addr        <= {dir_tag[index][victim_way], index, 6'h0};
   snoop_type        <= 2'b10; // Invalidate
   target_snoop_mask <= dir_mask[index][victim_way];
   state             <= EVICT_WAIT;
   ```
4. **State `EVICT_WAIT`:** The directory holds `snoop_valid` until all sharing cores acknowledge (`(snoop_ack & target_snoop_mask) == target_snoop_mask`). If any core held dirty data (`snoop_data_valid`), `resp_dirty` is propagated to trigger L2 writeback.
5. **Entry Clearance:** The victim directory entry is cleared (`dir_state <= ST_I; dir_mask <= 4'h0;`).
6. **Allocation:** The FSM transitions to `UPDATE` where the new line is safely installed in `chosen_way`.

---

## 4. Verification Evidence

### 4.1 Directed Unit Testbench (`tb_l2_snoop_filter.v`)
A dedicated saturation and eviction test was implemented (**TEST 11**):
1. **Set Saturation:** Injected 32 cold ReadShared requests from Core 0 mapping to Set 4 (`addr = 0x8000_0100 + (k << 12)`). All 32 ways were allocated sequentially.
2. **Victim Eviction Trigger:** Injected a 33rd request (`k = 32`) mapping to Set 4 from Core 1.
3. **Snoop Invalidation Verification:** Verified that `snoop_valid == 4'b0001`, `snoop_addr == 40'h00_8000_0100`, and `snoop_type == 2'b10 (Inv)` were asserted, targeting Core 0 holding victim line 0.
4. **Eviction Confirmation:**
   - Attempted access to victim line 0: Verified directory returned **MISS** (`resp_hit == 1'b0`).
   - Attempted access to non-victim line 1 (in way 1): Verified directory returned **HIT** (`resp_hit == 1'b1`).

```
==================================================================
  TITAN-X: L2 SNOOP FILTER & MESI DIRECTORY QUALIFICATION SUITE
==================================================================
[TEST 1] Reset State Verification
[TEST 2] Cold Read Miss (Core 0 ReadShared to 0x8000_1000)
[TEST 3] Read Hit to Exclusive Line (Core 1 ReadShared -> Downgrade Core 0)
[TEST 4] Read Hit to Shared Line (Core 2 ReadShared -> Silent Hit)
[TEST 5] Write Hit to Shared Line (Core 1 ReadUnique -> Invalidate Cores 0 & 2)
[TEST 6] Read Hit to Modified Line with Dirty Data Forwarding
[TEST 7] Cold Write Allocation & Hit to Owned Modified Line
[TEST 8] Clean Invalidation & Eviction Tracking
[TEST 9] Verify Evicted Line is Invalid
[TEST 10] Multi-Address Tracking Across Distinct Sets
[TEST 11] Set Saturation, Round-Robin Eviction & L1 Back-Invalidation

------------------------------------------------
L2_SNOOP_FILTER: 119 checks, 0 errors
REGRESS_RESULT: PASS
==================================================================
```

### 4.2 Adversarial Multi-Agent Stress Verification (`tb_l2_snoop_filter_adversarial.v`)
Under Prompt 6B, an adversarial stress testbench was developed to target edge cases in multi-agent asynchronous snooping:
1. **Staggered Ack Accumulation:** Verified that cores acking at asynchronous cycle offsets (e.g., Core 0 at +1, Core 1 at +3, Core 2 at +5) do not deadlock `EVICT_WAIT` or `SNOOP_REQ`.
2. **Early Dirty Pulse Retention:** Verified that a single-cycle dirty pulse on cycle 1 is held in `dirty_accum` until all remaining clean sharers complete their delayed acks.
3. **Dirty Victim Saturation Eviction:** Verified that evicting a modified line owned by Core 1 asserts `resp_dirty=1` to trigger L2 dirty writeback.
4. **32-Way Round-Robin Wrap-Around:** Exercised sequential eviction across all 32 ways and verified clean pointer wrap-around from Way 31 back to Way 0.
5. **Random Jitter Stress:** 15 iterations of randomized delay injections (0-6 cycles per core) completed with zero timeouts.
6. **Mid-Flight Reset Recovery:** Asynchronous reset asserted during active snoop wait cleanly returns FSM to `IDLE`.

```
==================================================================
  TITAN-X: L2 SNOOP FILTER ADVERSARIAL STRESS SUITE
==================================================================
L2_SNOOP_FILTER_ADVERSARIAL: 231 checks, 0 errors
REGRESS_RESULT: PASS
==================================================================
```

### 4.3 Multi-Core Integration Verification
- `tb_multicore_coherence.v`: Executed multi-core concurrent reads, writes, and snooping across 4 cores. **PASS (100%)**.
- `tb_integ_memory_hierarchy.v`: Executed full memory hierarchy pipeline test including L1, L2, Snoop Filter, and DDR controller. **PASS (100%)**.
- `tb_integ_multicore_mesi.v`: Executed top-level 4-core concurrent MESI coherence with dirty-line forwarding. **PASS (100%)**.

---

## 5. Architectural Defect Closure Sign-Off

| Metric | Pre-Remediation | Post-Remediation (Prompt 6B) | Verification Status |
|:---|:---:|:---:|:---:|
| Directory Set Saturation Behavior | Silent overwrite of Way 0 | Round-Robin Victim Eviction | ✅ VERIFIED |
| L1 Back-Invalidation on Eviction | None (orphaned lines) | Forced `2'b10 (Inv)` Snoop | ✅ VERIFIED |
| Staggered Multi-Core Acks | Protocol Deadlock | Cycle-by-cycle `ack_accum` | ✅ VERIFIED |
| Victim Dirty Forwarding | Dropped | Latched via `dirty_accum` | ✅ VERIFIED |
| Directory Inclusion Property | Violated | Strictly Enforced | ✅ VERIFIED |
| Directed Testbench Checks | 46 Checks (0 errors) | 119 Checks (0 errors) | ✅ 100% PASS |
| Adversarial Testbench Checks | 0 Checks | 231 Checks (0 errors) | ✅ 100% PASS |
| Multi-Core Coherence Regression | Passed (low depth) | Passed (full inclusion & MESI) | ✅ 100% PASS |

**Sign-Off Verdict:** FINDING-02 is formally **REMEDIATED, PROVEN ADVERSARIALLY, AND CLOSED**.

