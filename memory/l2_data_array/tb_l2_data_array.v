// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — L2 Data Array Qualification Testbench
// Module: tb_l2_data_array
//
// Verification Coverage:
//   1. Reset state: dout_valid deasserted upon reset.
//   2. Synchronous 1-cycle read latency: dout_valid asserts exactly 1 cycle after cs && !we.
//   3. Byte write masking: individual byte lanes [7:0] can be selectively modified.
//   4. Multi-bank addressing: independent storage and non-aliased access across all 128 banks.
//   5. Pipelined back-to-back reads: continuous data delivery on consecutive clock cycles.

`timescale 1ns/1ps

`include "tb_macros.vh"

module tb_l2_data_array;

    reg clk;
    reg rst_n;
    `TB_HARNESS(5_000_000)
    `TB_SCOREBOARD

    localparam DATA_W = 64;
    localparam DEPTH  = 8192;
    localparam ADDR_W = $clog2(DEPTH);

    reg              cs;
    reg              we;
    reg  [7:0]       wmask;
    reg  [ADDR_W-1:0] addr;
    reg  [DATA_W-1:0] din;
    wire [DATA_W-1:0] dout;
    wire             dout_valid;

    // DUT Instantiation
    l2_data_array #(
        .DATA_W(DATA_W),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .cs(cs),
        .we(we),
        .wmask(wmask),
        .addr(addr),
        .din(din),
        .dout(dout),
        .dout_valid(dout_valid)
    );

    task write_word(input [ADDR_W-1:0] a, input [DATA_W-1:0] d, input [7:0] m);
        begin
            @(posedge clk);
            cs    <= 1'b1;
            we    <= 1'b1;
            addr  <= a;
            din   <= d;
            wmask <= m;
            @(posedge clk);
            cs    <= 1'b0;
            we    <= 1'b0;
            wmask <= 8'h00;
        end
    endtask

    task read_word(input [ADDR_W-1:0] a, output [DATA_W-1:0] d);
        begin
            @(posedge clk);
            cs   <= 1'b1;
            we   <= 1'b0;
            addr <= a;
            @(posedge clk);
            cs   <= 1'b0;
            #1;
            `EXPECT_EQ(dout_valid, 1'b1, "read_word: dout_valid must be 1 on cycle N+1")
            d = dout;
            @(posedge clk);
            #1;
            `EXPECT_EQ(dout_valid, 1'b0, "read_word: dout_valid must deassert on cycle N+2")
        end
    endtask

    reg [63:0] rd_data;
    integer b_idx;

    initial begin
        $dumpfile("tb_l2_data_array.vcd");
        $dumpvars(0, tb_l2_data_array);

        cs    = 0;
        we    = 0;
        wmask = 0;
        addr  = 0;
        din   = 0;

        @(posedge rst_n);
        repeat (4) @(posedge clk);

        $display("\n==================================================================");
        $display("  TITAN X — L2 DATA ARRAY QUALIFICATION (DEF-ARCH-04)");
        $display("==================================================================");

        // ------------------------------------------------------------
        // TEST 1: Reset State
        // ------------------------------------------------------------
        $display("\n--- TEST 1: Reset State ---");
        `EXPECT_EQ(dout_valid, 1'b0, "Test 1: dout_valid must be 0 after reset")

        // ------------------------------------------------------------
        // TEST 2: Synchronous 1-Cycle Read Latency
        // ------------------------------------------------------------
        $display("\n--- TEST 2: Synchronous 1-Cycle Read Latency ---");
        write_word(13'h000A, 64'h0123_4567_89AB_CDEF, 8'hFF);

        @(posedge clk);
        cs   <= 1'b1;
        we   <= 1'b0;
        addr <= 13'h000A;
        #1;
        `EXPECT_EQ(dout_valid, 1'b0, "Test 2: dout_valid must remain 0 during cycle N")
        @(posedge clk);
        cs   <= 1'b0;
        #1;
        `EXPECT_EQ(dout_valid, 1'b1, "Test 2: dout_valid asserted at cycle N+1")
        `EXPECT_EQ(dout, 64'h0123_4567_89AB_CDEF, "Test 2: dout matches written data")
        @(posedge clk);
        #1;
        `EXPECT_EQ(dout_valid, 1'b0, "Test 2: dout_valid deasserts at cycle N+2")

        // ------------------------------------------------------------
        // TEST 3: Byte Write Masking (8 Byte Lanes)
        // ------------------------------------------------------------
        $display("\n--- TEST 3: Byte Write Masking (8 Byte Lanes) ---");
        write_word(13'h0020, 64'h0000_0000_0000_0000, 8'hFF);

        for (b_idx = 0; b_idx < 8; b_idx = b_idx + 1) begin
            write_word(13'h0020, (64'hA0 + b_idx) << (b_idx * 8), (8'h01 << b_idx));
        end

        read_word(13'h0020, rd_data);
        `EXPECT_EQ(rd_data, 64'hA7A6_A5A4_A3A2_A1A0, "Test 3: byte masking across all 8 byte lanes")

        // Partial overwrite: overwrite byte 3 with 0x55 and byte 6 with 0xAA
        write_word(13'h0020, 64'h00AA_0000_5500_0000, 8'h48);
        read_word(13'h0020, rd_data);
        `EXPECT_EQ(rd_data, 64'hA7AA_A5A4_55A2_A1A0, "Test 3: multi-byte selective write mask")

        // ------------------------------------------------------------
        // TEST 4: Multi-Bank Addressing (128 Banks)
        // ------------------------------------------------------------
        $display("\n--- TEST 4: Multi-Bank Non-Aliased Storage ---");
        // Bank 0 (addr 0)
        write_word(13'd0, 64'hBBBB_0000_0000_0001, 8'hFF);
        // Bank 1 (addr 64)
        write_word(13'd64, 64'hBBBB_0000_0000_0002, 8'hFF);
        // Bank 63 (addr 63*64 + 12 = 4044)
        write_word(13'd4044, 64'hBBBB_0000_0000_0003, 8'hFF);
        // Bank 127 (addr 127*64 + 63 = 8191)
        write_word(13'd8191, 64'hBBBB_0000_0000_0004, 8'hFF);

        read_word(13'd0, rd_data);
        `EXPECT_EQ(rd_data, 64'hBBBB_0000_0000_0001, "Test 4: Bank 0 readback")

        read_word(13'd64, rd_data);
        `EXPECT_EQ(rd_data, 64'hBBBB_0000_0000_0002, "Test 4: Bank 1 readback")

        read_word(13'd4044, rd_data);
        `EXPECT_EQ(rd_data, 64'hBBBB_0000_0000_0003, "Test 4: Bank 63 readback")

        read_word(13'd8191, rd_data);
        `EXPECT_EQ(rd_data, 64'hBBBB_0000_0000_0004, "Test 4: Bank 127 readback")

        // ------------------------------------------------------------
        // TEST 5: Pipelined Back-to-Back Reads
        // ------------------------------------------------------------
        $display("\n--- TEST 5: Pipelined Back-to-Back Reads ---");
        @(posedge clk);
        cs   <= 1'b1;
        we   <= 1'b0;
        addr <= 13'd0;    // Req 1 (Bank 0)

        @(posedge clk);
        addr <= 13'd64;   // Req 2 (Bank 1)

        #1;
        `EXPECT_EQ(dout_valid, 1'b1, "Test 5: Req 1 dout_valid")
        `EXPECT_EQ(dout, 64'hBBBB_0000_0000_0001, "Test 5: Req 1 data from Bank 0")

        @(posedge clk);
        addr <= 13'd8191; // Req 3 (Bank 127)

        #1;
        `EXPECT_EQ(dout_valid, 1'b1, "Test 5: Req 2 dout_valid")
        `EXPECT_EQ(dout, 64'hBBBB_0000_0000_0002, "Test 5: Req 2 data from Bank 1")

        @(posedge clk);
        cs   <= 1'b0;     // End stream

        #1;
        `EXPECT_EQ(dout_valid, 1'b1, "Test 5: Req 3 dout_valid")
        `EXPECT_EQ(dout, 64'hBBBB_0000_0000_0004, "Test 5: Req 3 data from Bank 127")

        @(posedge clk);
        #1;
        `EXPECT_EQ(dout_valid, 1'b0, "Test 5: Stream complete, dout_valid deasserted")

        // ------------------------------------------------------------
        // Sign-off Report
        // ------------------------------------------------------------
        `TB_REPORT("tb_l2_data_array")
    end

endmodule
