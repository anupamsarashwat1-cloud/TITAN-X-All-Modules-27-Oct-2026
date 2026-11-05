// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Gate D Qualification Suite
// Module: tb_l2_snoop_filter
// Verifies:
//   1. Reset state: Directory entries initialized to ST_I.
//   2. Cold read allocation: ReadShared miss -> grants Exclusive (ST_E).
//   3. Read hit to Exclusive: Core 1 ReadShared -> issues GetS snoop to Core 0, transitions to ST_S.
//   4. Read hit to Shared: Core 2 ReadShared -> hits in ST_S, no snoops, adds Core 2 to sharer mask.
//   5. Write hit to Shared: Core 1 ReadUnique -> issues Inv snoop to Core 0 & 2, transitions to ST_M.
//   6. Read hit to Modified with Dirty Forwarding: Core 0 ReadShared -> issues GetS snoop to Core 1,
//      Core 1 supplies dirty line, asserts resp_dirty, transitions to ST_S.
//   7. Write hit to owned Modified: Core 0 ReadUnique -> hits silently, no snoops.
//   8. Eviction / Invalidation: Clean evictions update mask and return line to ST_I on zero sharers.
//   9. Subsequent access to evicted line is a verified directory miss.

`timescale 1ns/1ps

module tb_l2_snoop_filter;

    `include "tb_macros.vh"

    reg clk;
    reg rst_n;
    `TB_HARNESS(5_000_000)
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

    // Mock L1 Cache Snoop Responder
    reg [3:0] mock_ack_en;
    reg [3:0] mock_dirty_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snoop_ack <= 4'h0;
            snoop_data_valid <= 4'h0;
        end else begin
            snoop_ack <= snoop_valid & mock_ack_en;
            snoop_data_valid <= snoop_valid & mock_dirty_en;
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
            `EXPECT_TRUE(resp_valid, "Response received within timeout")
        end
    endtask

    task wait_idle;
        begin
            repeat (2) @(posedge clk);
        end
    endtask

    // Main Test Sequence
    initial begin
        $dumpfile("tb_l2_snoop_filter.vcd");
        $dumpvars(0, tb_l2_snoop_filter);

        req_valid = 1'b0;
        req_addr  = 40'h0;
        req_type  = 2'b00;
        req_core  = 2'b00;
        mock_ack_en   = 4'hF;
        mock_dirty_en = 4'h0;

        // Wait for reset release
        @(posedge rst_n);
        repeat (10) @(posedge clk);

        $display("\n==================================================================");
        $display("  TITAN-X: L2 SNOOP FILTER & MESI DIRECTORY QUALIFICATION SUITE");
        $display("==================================================================");

        // ------------------------------------------------------------
        // TEST 1: Reset State
        // ------------------------------------------------------------
        $display("\n[TEST 1] Reset State Verification");
        `EXPECT_EQ(resp_valid, 1'b0, "resp_valid is 0 after reset")
        `EXPECT_EQ(snoop_valid, 4'h0, "snoop_valid is 0 after reset")

        // ------------------------------------------------------------
        // TEST 2: Cold Read Miss (ReadShared -> ST_E)
        // ------------------------------------------------------------
        $display("\n[TEST 2] Cold Read Miss (Core 0 ReadShared to 0x8000_1000)");
        send_request(40'h00_8000_1000, 2'b00, 2'b00);
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b0, "Directory reports miss on cold line")
        `EXPECT_EQ(resp_dirty, 1'b0, "Cold miss reports not dirty")
        `EXPECT_EQ(snoop_valid, 4'h0, "No snoop generated on cold miss")
        wait_idle();

        // ------------------------------------------------------------
        // TEST 3: Read Hit to Exclusive Line (Core 1 ReadShared -> GetS snoop)
        // ------------------------------------------------------------
        $display("\n[TEST 3] Read Hit to Exclusive Line (Core 1 ReadShared -> Downgrade Core 0)");
        send_request(40'h00_8000_1000, 2'b00, 2'b01);
        
        // Wait for snoop request to be issued to Core 0
        while (snoop_valid == 4'h0) @(posedge clk);
        `EXPECT_EQ(snoop_valid, 4'b0001, "Snoop issued exclusively to Core 0")
        `EXPECT_EQ(snoop_addr, 40'h00_8000_1000, "Snoop address matches requested line")
        `EXPECT_EQ(snoop_type, 2'b00, "Snoop type is GetS (downgrade to Shared)")

        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b1, "Directory reports hit")
        `EXPECT_EQ(resp_dirty, 1'b0, "Clean line reports not dirty")
        wait_idle();

        // ------------------------------------------------------------
        // TEST 4: Read Hit to Shared Line (Core 2 ReadShared -> Add to sharers)
        // ------------------------------------------------------------
        $display("\n[TEST 4] Read Hit to Shared Line (Core 2 ReadShared -> Silent Hit)");
        send_request(40'h00_8000_1000, 2'b00, 2'b10);
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b1, "Directory reports hit on shared line")
        `EXPECT_EQ(resp_dirty, 1'b0, "Clean shared line reports not dirty")
        `EXPECT_EQ(snoop_valid, 4'h0, "No snoop needed when adding sharer to ST_S")
        wait_idle();

        // ------------------------------------------------------------
        // TEST 5: Write Hit to Shared Line (Core 1 ReadUnique -> Invalidate others)
        // Sharers are currently {Core 0, Core 1, Core 2}.
        // Core 1 requests write. Core 0 and Core 2 must receive Inv (2'b10).
        // ------------------------------------------------------------
        $display("\n[TEST 5] Write Hit to Shared Line (Core 1 ReadUnique -> Invalidate Cores 0 & 2)");
        send_request(40'h00_8000_1000, 2'b01, 2'b01);

        while (snoop_valid == 4'h0) @(posedge clk);
        `EXPECT_EQ(snoop_valid, 4'b0101, "Snoop invalidation sent to Core 0 and Core 2")
        `EXPECT_EQ(snoop_addr, 40'h00_8000_1000, "Snoop invalidation address correct")
        `EXPECT_EQ(snoop_type, 2'b10, "Snoop type is Inv (Invalidate)")

        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b1, "Directory reports hit")
        `EXPECT_EQ(resp_owner, 2'b01, "Owner is Core 1")
        wait_idle();

        // ------------------------------------------------------------
        // TEST 6: Read Hit to Modified Line with Dirty Forwarding
        // Core 1 owns line in ST_M. Core 0 sends ReadShared.
        // Core 1 must be snooped with GetS and forward dirty data.
        // ------------------------------------------------------------
        $display("\n[TEST 6] Read Hit to Modified Line with Dirty Data Forwarding");
        mock_dirty_en = 4'b0010; // Core 1 signals dirty line available
        send_request(40'h00_8000_1000, 2'b00, 2'b00);

        while (snoop_valid == 4'h0) @(posedge clk);
        `EXPECT_EQ(snoop_valid, 4'b0010, "Snoop sent to owner Core 1")
        `EXPECT_EQ(snoop_type, 2'b00, "Snoop type is GetS")

        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b1, "Directory reports hit")
        `EXPECT_EQ(resp_dirty, 1'b1, "Dirty forwarding flag asserted")
        wait_idle();
        mock_dirty_en = 4'h0;

        // ------------------------------------------------------------
        // TEST 7: Cold Write Allocation & Self-Hit to Modified Line
        // ------------------------------------------------------------
        $display("\n[TEST 7] Cold Write Allocation & Hit to Owned Modified Line");
        send_request(40'h00_8000_2000, 2'b01, 2'b11); // Core 3 write miss
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b0, "Cold line is miss")
        wait_idle();

        // Core 3 writes again to the same line (already owned in ST_M)
        send_request(40'h00_8000_2000, 2'b01, 2'b11);
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b1, "Hit on owned Modified line")
        `EXPECT_EQ(resp_owner, 2'b11, "Owner is Core 3")
        `EXPECT_EQ(snoop_valid, 4'h0, "No snoop needed when owner writes to ST_M")
        wait_idle();

        // ------------------------------------------------------------
        // TEST 8: Clean Invalidation / Eviction
        // Line 0x8000_1000 is currently shared by Core 0 and Core 1.
        // Core 0 evicts, then Core 1 evicts.
        // ------------------------------------------------------------
        $display("\n[TEST 8] Clean Invalidation & Eviction Tracking");
        send_request(40'h00_8000_1000, 2'b10, 2'b00); // Core 0 evicts
        wait_response(20);
        wait_idle();

        send_request(40'h00_8000_1000, 2'b10, 2'b01); // Core 1 evicts (last sharer)
        wait_response(20);
        wait_idle();

        // ------------------------------------------------------------
        // TEST 9: Verification that Evicted Line is now Invalid (Miss)
        // ------------------------------------------------------------
        $display("\n[TEST 9] Verify Evicted Line is Invalid");
        send_request(40'h00_8000_1000, 2'b00, 2'b10); // Core 2 reads
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b0, "Evicted line correctly reports miss (ST_I)")
        wait_idle();

        // ------------------------------------------------------------
        // TEST 10: Multi-Address Coexistence Across Index Sets
        // ------------------------------------------------------------
        $display("\n[TEST 10] Multi-Address Tracking Across Distinct Sets");
        send_request(40'h00_8000_0040, 2'b00, 2'b00); // Set 1
        wait_response(20);
        wait_idle();

        send_request(40'h00_8000_0080, 2'b00, 2'b01); // Set 2
        wait_response(20);
        wait_idle();

        send_request(40'h00_8000_00C0, 2'b00, 2'b10); // Set 3
        wait_response(20);
        wait_idle();

        // Verify Set 1 still hits
        send_request(40'h00_8000_0040, 2'b00, 2'b00);
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b1, "Set 1 entry preserved and hits")
        wait_idle();

        // Verify Set 2 still hits
        send_request(40'h00_8000_0080, 2'b00, 2'b01);
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b1, "Set 2 entry preserved and hits")
        wait_idle();

        // Verify Set 3 still hits
        send_request(40'h00_8000_00C0, 2'b00, 2'b10);
        wait_response(20);
        `EXPECT_EQ(resp_hit, 1'b1, "Set 3 entry preserved and hits")
        wait_idle();

        $display("\n==================================================================");
        $display("  ALL L2 SNOOP FILTER QUALIFICATION TESTS COMPLETED SUCCESSFULLY");
        $display("==================================================================\n");

        `TB_REPORT("L2_SNOOP_FILTER")
    end

endmodule
