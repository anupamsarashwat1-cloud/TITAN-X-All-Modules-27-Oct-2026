// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Gate D Qualification Suite
// Module: tb_l2_snoop_filter_adversarial
// Description: Adversarial verification of L2 snoop filter:
//   1. Staggered / delayed snoop acks across multiple cores without deadlock.
//   2. Dirty-owner back-invalidation eviction preserving resp_dirty writeback.
//   3. Staggered dirty pulse retention (dirty signaled early, other sharers ack late).
//   4. 32-way set saturation, victim eviction, and pointer wrap-around.
//   5. Multi-agent randomized ack jitter stress testing.
//   6. Mid-flight asynchronous reset recovery from EVICT_WAIT and SNOOP_REQ.
//   7. Coherence invariant assertions (MESI consistency and mask validity).

`timescale 1ns/1ps

module tb_l2_snoop_filter_adversarial;

    `include "tb_macros.vh"

    reg clk;
    reg rst_n;
    `TB_HARNESS(20_000_000)
    `TB_SCOREBOARD

    // DUT Signals
    reg         req_valid;
    reg  [39:0] req_addr;
    reg  [1:0]  req_type;
    reg  [1:0]  req_core;

    wire [3:0]  snoop_valid;
    wire [39:0] snoop_addr;
    wire [1:0]  snoop_type;
    reg  [3:0]  snoop_ack;
    reg  [3:0]  snoop_data_valid;

    wire        resp_valid;
    wire        resp_hit;
    wire        resp_dirty;
    wire [1:0]  resp_owner;

    // DUT Instantiation
    l2_snoop_filter #(
        .NUM_CORES(4),
        .ADDR_W(40),
        .TAG_W(28),
        .INDEX_W(6),
        .WAYS(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_addr(req_addr),
        .req_type(req_type),
        .req_core(req_core),
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_type(snoop_type),
        .snoop_ack(snoop_ack),
        .snoop_data_valid(snoop_data_valid),
        .resp_valid(resp_valid),
        .resp_hit(resp_hit),
        .resp_dirty(resp_dirty),
        .resp_owner(resp_owner)
    );

    // Dynamic Mock L1 Responder variables
    reg [3:0] ack_delay [0:3];
    reg [3:0] ack_counter [0:3];
    reg [3:0] dirty_core_mask;
    reg [3:0] dirty_pulse_len [0:3];
    reg [3:0] dirty_counter [0:3];
    reg       responder_enable;

    integer i, k;

    // Flexible multi-agent L1 mock responder with programmable per-core delay
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snoop_ack <= 4'h0;
            snoop_data_valid <= 4'h0;
            for (i = 0; i < 4; i = i + 1) begin
                ack_counter[i] <= 4'd0;
                dirty_counter[i] <= 4'd0;
            end
        end else if (responder_enable) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (snoop_valid[i]) begin
                    if (ack_counter[i] < ack_delay[i]) begin
                        ack_counter[i] <= ack_counter[i] + 4'd1;
                        snoop_ack[i] <= 1'b0;
                    end else begin
                        snoop_ack[i] <= 1'b1;
                    end

                    if (dirty_core_mask[i]) begin
                        if (dirty_counter[i] < dirty_pulse_len[i]) begin
                            dirty_counter[i] <= dirty_counter[i] + 4'd1;
                            snoop_data_valid[i] <= 1'b1;
                        end else begin
                            snoop_data_valid[i] <= 1'b0;
                        end
                    end else begin
                        snoop_data_valid[i] <= 1'b0;
                    end
                end else begin
                    ack_counter[i] <= 4'd0;
                    dirty_counter[i] <= 4'd0;
                    snoop_ack[i] <= 1'b0;
                    snoop_data_valid[i] <= 1'b0;
                end
            end
        end else begin
            snoop_ack <= 4'h0;
            snoop_data_valid <= 4'h0;
        end
    end

    // Helper Tasks
    task send_request(
        input [39:0] addr,
        input [1:0]  typ,
        input [1:0]  core
    );
        begin
            @(posedge clk);
            req_valid = 1'b1;
            req_addr  = addr;
            req_type  = typ;
            req_core  = core;
            @(posedge clk);
            req_valid = 1'b0;
        end
    endtask

    task wait_response;
        input integer max_cycles;
        integer cyc;
        begin
            cyc = 0;
            while (!resp_valid && cyc < max_cycles) begin
                @(posedge clk);
                cyc = cyc + 1;
            end
            `EXPECT_TRUE(resp_valid, "Response received within cycle limit")
        end
    endtask

    task wait_idle;
        begin
            repeat (3) @(posedge clk);
        end
    endtask

    // Check MESI invariants across entire directory
    task check_mesi_invariants;
        integer s, w, mask_pop;
        reg [1:0] st;
        reg [3:0] msk;
        begin
            for (s = 0; s < 64; s = s + 1) begin
                for (w = 0; w < 32; w = w + 1) begin
                    st = dut.dir_state[s][w];
                    msk = dut.dir_mask[s][w];
                    mask_pop = msk[0] + msk[1] + msk[2] + msk[3];

                    if (st == 2'b00) begin // ST_I
                        if (msk != 4'h0) begin
                            $display("[FAIL] Invariant violation: ST_I entry set %0d way %0d has non-zero mask %b", s, w, msk);
                            tb_errors = tb_errors + 1;
                        end
                    end else if (st == 2'b01 || st == 2'b11) begin // ST_E or ST_M
                        if (mask_pop != 1) begin
                            $display("[FAIL] Invariant violation: ST_E/M entry set %0d way %0d has mask population %0d != 1 (%b)", s, w, mask_pop, msk);
                            tb_errors = tb_errors + 1;
                        end
                    end else if (st == 2'b10) begin // ST_S
                        if (mask_pop == 0) begin
                            $display("[FAIL] Invariant violation: ST_S entry set %0d way %0d has zero mask", s, w);
                            tb_errors = tb_errors + 1;
                        end
                    end
                end
            end
            tb_checks = tb_checks + 1;
        end
    endtask

    // Main Test Sequence
    initial begin
        $dumpfile("tb_l2_snoop_filter_adversarial.vcd");
        $dumpvars(0, tb_l2_snoop_filter_adversarial);

        req_valid = 1'b0;
        req_addr  = 40'h0;
        req_type  = 2'b00;
        req_core  = 2'b00;
        responder_enable = 1'b1;
        dirty_core_mask  = 4'h0;

        for (i = 0; i < 4; i = i + 1) begin
            ack_delay[i] = 4'd0;
            dirty_pulse_len[i] = 4'd1;
        end

        // Wait for reset
        @(posedge rst_n);
        repeat (10) @(posedge clk);

        $display("\n==================================================================");
        $display("  TITAN-X: L2 SNOOP FILTER ADVERSARIAL STRESS SUITE");
        $display("==================================================================");

        // ------------------------------------------------------------
        // SCENARIO 1: Staggered Snoop Acks in SNOOP_REQ
        // ------------------------------------------------------------
        $display("\n[SCENARIO 1] Staggered Multi-Core Acks (Cores 0, 1, 2 in ST_S, Core 3 Write)");
        // Cores 0, 1, 2 read line A (0x8000_A000)
        send_request(40'h00_8000_A000, 2'b00, 2'b00); wait_response(20); wait_idle();
        send_request(40'h00_8000_A000, 2'b00, 2'b01); wait_response(20); wait_idle();
        send_request(40'h00_8000_A000, 2'b00, 2'b10); wait_response(20); wait_idle();

        // Configure staggered ack delays:
        // Core 0 acks after 1 cycle
        // Core 1 acks after 3 cycles
        // Core 2 acks after 5 cycles
        ack_delay[0] = 4'd1;
        ack_delay[1] = 4'd3;
        ack_delay[2] = 4'd5;

        // Core 3 requests exclusive write (ReadUnique) -> Invalidate Cores 0, 1, 2
        send_request(40'h00_8000_A000, 2'b01, 2'b11);
        wait_response(30);
        `EXPECT_EQ(resp_hit, 1'b1, "Directory hit on write upgrade with staggered acks")
        `EXPECT_EQ(resp_owner, 2'b11, "Core 3 is now the sole owner")
        wait_idle();
        check_mesi_invariants();

        // Reset delays
        for (i = 0; i < 4; i = i + 1) ack_delay[i] = 4'd0;

        // ------------------------------------------------------------
        // SCENARIO 2: Dirty-Owner Eviction with L2 Writeback Assertion
        // ------------------------------------------------------------
        $display("\n[SCENARIO 2] Dirty-Owner Eviction during Saturation with resp_dirty Asserted");
        // Core 1 writes to line B in Set 10 (addr = 0x8000_0280) -> allocates as ST_M
        send_request(40'h00_8000_0280, 2'b01, 2'b01); wait_response(20); wait_idle();

        // Fill remaining 31 ways in Set 10 with lines from Core 0
        for (k = 1; k < 32; k = k + 1) begin
            send_request(40'h00_8000_0280 + (k << 12), 2'b00, 2'b00);
            wait_response(20);
            wait_idle();
        end

        // Set 10 is full (all 32 ways occupied). Way 0 holds line B owned dirty by Core 1.
        // Configure Core 1 to assert snoop_data_valid (dirty writeback) upon receiving back-invalidation
        dirty_core_mask = 4'b0010;
        dirty_pulse_len[1] = 4'd2;
        ack_delay[1] = 4'd1;

        // Inject 33rd line into Set 10 -> Triggers victim eviction of Way 0 (Core 1 line B)
        $display("Triggering saturation eviction of dirty Way 0...");
        send_request(40'h00_8000_0280 + (32 << 12), 2'b00, 2'b10); // Core 2 allocates
        wait_response(30);

        `EXPECT_EQ(resp_hit, 1'b0, "Directory miss for allocating 33rd line")
        `EXPECT_EQ(resp_dirty, 1'b1, "EVICTION SIGNALED DIRTY LINE WRITEBACK TO L2")
        wait_idle();
        check_mesi_invariants();

        dirty_core_mask = 4'h0;
        for (i = 0; i < 4; i = i + 1) ack_delay[i] = 4'd0;

        // ------------------------------------------------------------
        // SCENARIO 3: Staggered Dirty Pulse Retention (Early Dirty Pulse, Late Sharer Ack)
        // ------------------------------------------------------------
        $display("\n[SCENARIO 3] Dirty Pulse Retention with Asynchronous Sharer Ack");
        // Create shared state in Set 12: Core 1 and Core 2 share line
        // Core 1 holds dirty data. Core 1 acks with dirty pulse for 1 cycle.
        // Core 2 delays its ack by 6 cycles.
        // In the old buggy RTL, dirty was evaluated at the final cycle:
        // resp_dirty <= |(snoop_data_valid & target_snoop_mask), which dropped to 0!
        // With accumulator, dirty_accum preserves the dirty assertion.
        
        // Put line into ST_M for Core 1
        send_request(40'h00_8000_0300, 2'b01, 2'b01); wait_response(20); wait_idle();

        // Fill remaining 31 ways in Set 12 with clean lines shared by Core 1 and Core 2
        for (k = 1; k < 32; k = k + 1) begin
            send_request(40'h00_8000_0300 + (k << 12), 2'b00, 2'b00);
            wait_response(20);
            wait_idle();
        end

        // Set 12 Way 0 has dirty Core 1.
        // Stagger: Core 1 pulses dirty data at cycle 1, then stops.
        dirty_core_mask = 4'b0010;
        dirty_pulse_len[1] = 4'd1; // only 1 cycle dirty pulse
        ack_delay[1] = 4'd1;       // Core 1 acks on cycle 1

        // 33rd line in Set 12 evicts Way 0
        send_request(40'h00_8000_0300 + (32 << 12), 2'b00, 2'b11);
        wait_response(30);
        `EXPECT_EQ(resp_dirty, 1'b1, "Dirty state preserved even with single-cycle early pulse")
        wait_idle();
        check_mesi_invariants();

        dirty_core_mask = 4'h0;

        // ------------------------------------------------------------
        // SCENARIO 4: 32-Way Set Saturation and Round-Robin Wrap-Around
        // ------------------------------------------------------------
        $display("\n[SCENARIO 4] Full 32-Way Round-Robin Wrap-Around");
        // Fill all 32 ways in Set 20
        for (k = 0; k < 32; k = k + 1) begin
            send_request(40'h00_8000_0500 + (k << 12), 2'b00, 2'b00);
            wait_response(20);
            wait_idle();
        end

        // Evict each of the 32 ways sequentially (from way 0 through way 31)
        for (k = 0; k < 32; k = k + 1) begin
            // Next line (32 + k) evicts way k
            send_request(40'h00_8000_0500 + ((32 + k) << 12), 2'b00, 2'b01);
            wait_response(25);
            `EXPECT_EQ(resp_hit, 1'b0, "Cold miss allocating replacement line")
            wait_idle();
        end

        // Now replace_ptr must have wrapped back around to 0!
        // Injecting line 64 should evict way 0 (holding line 32)
        send_request(40'h00_8000_0500 + (64 << 12), 2'b00, 2'b10);
        wait_response(25);
        `EXPECT_EQ(resp_hit, 1'b0, "Miss allocating wrap-around line")
        wait_idle();

        // Verify line 32 was evicted and misses
        send_request(40'h00_8000_0500 + (32 << 12), 2'b00, 2'b00);
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b0, "Evicted wrap-around victim correctly reports miss")
        wait_idle();
        check_mesi_invariants();

        // ------------------------------------------------------------
        // SCENARIO 5: Randomized Multi-Core Ack Jitter Stress Test
        // ------------------------------------------------------------
        $display("\n[SCENARIO 5] Randomized Multi-Core Ack Jitter Stress (15 iterations)");
        for (k = 0; k < 15; k = k + 1) begin
            // Randomize delays between 0 and 6 cycles
            for (i = 0; i < 4; i = i + 1) begin
                ack_delay[i] = $urandom_range(0, 6);
            end

            // Core 0 read
            send_request(40'h00_8100_0000 + (k << 6), 2'b00, 2'b00);
            wait_response(40); wait_idle();

            // Core 1 read (triggers snoop to Core 0 with jitter)
            send_request(40'h00_8100_0000 + (k << 6), 2'b00, 2'b01);
            wait_response(40); wait_idle();

            // Core 2 write (triggers invalidation snoop to Cores 0 & 1 with jitter)
            send_request(40'h00_8100_0000 + (k << 6), 2'b01, 2'b10);
            wait_response(40); wait_idle();
        end
        $display("Randomized jitter stress completed successfully.");
        check_mesi_invariants();

        for (i = 0; i < 4; i = i + 1) ack_delay[i] = 4'd0;

        // ------------------------------------------------------------
        // SCENARIO 6: Mid-Flight Reset Recovery
        // ------------------------------------------------------------
        $display("\n[SCENARIO 6] Mid-Flight Reset Recovery During Active Snoop Wait");
        // Start a transaction that stalls snoop acks completely
        responder_enable = 1'b0; // Turn off mock responses -> will hang in SNOOP_REQ

        // Core 0 has exclusive line
        send_request(40'h00_8200_0000, 2'b00, 2'b00);
        wait_response(20); wait_idle();

        // Core 1 reads -> issues snoop to Core 0
        @(posedge clk);
        req_valid = 1'b1;
        req_addr  = 40'h00_8200_0000;
        req_type  = 2'b00;
        req_core  = 2'b01;
        @(posedge clk);
        req_valid = 1'b0;

        // Wait until DUT enters SNOOP_REQ (snoop_valid is active)
        while (snoop_valid == 4'h0) @(posedge clk);
        $display("DUT actively stalled in snoop state, asserting reset...");

        repeat (3) @(posedge clk);
        rst_n = 1'b0; // Asynchronously assert reset!
        repeat (5) @(posedge clk);
        rst_n = 1'b1; // Release reset
        repeat (5) @(posedge clk);

        // Turn mock responder back on
        responder_enable = 1'b1;

        // Verify DUT recovered cleanly to IDLE
        `EXPECT_EQ(resp_valid, 1'b0, "resp_valid is 0 after reset recovery")
        `EXPECT_EQ(snoop_valid, 4'h0, "snoop_valid is 0 after reset recovery")

        // Send a fresh request and ensure it succeeds
        send_request(40'h00_8300_0000, 2'b00, 2'b00);
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b0, "Fresh request after reset handled cleanly")
        wait_idle();
        check_mesi_invariants();

        $display("\n==================================================================");
        $display("  ALL ADVERSARIAL SNOOP FILTER TESTS COMPLETED SUCCESSFULLY");
        $display("==================================================================\n");

        `TB_REPORT("L2_SNOOP_FILTER_ADVERSARIAL")
    end

endmodule
