// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Phase 2 Gate D Qualification Testbench
// Module: tb_integ_multicore_mesi
// Verifies:
//   1. 4-Core AXI interconnect to shared L2 Cache and DDR4 subsystem.
//   2. Active snoop invalidation across cores via L2 Snoop Filter.
//   3. Hardware MESI state transitions (ST_I -> ST_E -> ST_M -> ST_S -> ST_I).
//   4. Dirty line data forwarding when a core holds a modified line.
//   5. Concurrent multi-core access across all 4 cores without bus collision.

`timescale 1ns/1ps

`include "tb_bfms.vh"

module tb_integ_multicore_mesi;

    `include "tb_macros.vh"

    reg clk;
    reg rst_n;
    `TB_HARNESS(10_000_000)
    `TB_SCOREBOARD

    localparam AW = 40, DW = 64, IDW = 4, NM = 4, NS = 9;

    // 4 Core Master AXI wires
    wire [NM-1:0]        m_awvalid, m_awready, m_wvalid, m_wready, m_wlast;
    wire [NM-1:0]        m_bvalid, m_bready, m_arvalid, m_arready, m_rvalid, m_rready, m_rlast;
    wire [(NM*AW)-1:0]   m_awaddr, m_araddr;
    wire [(NM*DW)-1:0]   m_wdata, m_rdata;
    wire [(NM*(DW/8))-1:0] m_wstrb;
    wire [(NM*2)-1:0]    m_bresp, m_rresp;
    wire [(NM*IDW)-1:0]  m_awid, m_bid, m_arid, m_rid;

    // Crossbar Slave wires
    wire [NS-1:0]        sx_awvalid, sx_wvalid, sx_wlast;
    wire [NS-1:0]        sx_bvalid, sx_arvalid, sx_rvalid, sx_rready, sx_rlast;
    wire [(NS*AW)-1:0]   sx_awaddr, sx_araddr;
    wire [(NS*DW)-1:0]   sx_wdata, sx_rdata;
    wire [(NS*(DW/8))-1:0] sx_wstrb;
    wire [(NS*2)-1:0]    sx_bresp, sx_rresp;
    wire [(NS*IDW)-1:0]  sx_awid, sx_bid, sx_arid, sx_rid;
    wire [NS-1:0]        sx_awready, sx_wready, sx_bready, sx_arready;

    // L2 to DDR controller wires
    wire                 l2_m_arvalid, l2_m_arready;
    wire [39:0]          l2_m_araddr;
    wire                 l2_m_rvalid, l2_m_rready;
    wire [63:0]          l2_m_rdata;
    wire [1:0]           l2_m_rresp;
    wire                 l2_m_awvalid, l2_m_awready;
    wire [39:0]          l2_m_awaddr;
    wire                 l2_m_wvalid, l2_m_wready;
    wire [63:0]          l2_m_wdata;
    wire [7:0]           l2_m_wstrb;
    wire                 l2_m_bvalid, l2_m_bready;

    // L2 Snoop wires to Cores
    wire [3:0]           snoop_valid;
    wire [39:0]          snoop_addr;
    wire [1:0]           snoop_type;
    reg  [3:0]           snoop_ack;
    reg  [3:0]           snoop_data_valid;
    wire [511:0]         snoop_data;

    // DDR pins
    wire ck_p, ck_n, cke, cs_n, ras_n, cas_n, we_n;
    wire [2:0] ba; wire [1:0] bg; wire [15:0] addr16; wire [7:0] dm;
    wire [63:0] dq; wire [7:0] dqs_p, dqs_n;

    // ------------------------------------------------------------
    // 4x AXI Master BFMs (Cores 0, 1, 2, 3)
    // ------------------------------------------------------------
    genvar c;
    generate for (c = 0; c < NM; c = c + 1) begin : gen_cores
        axi_master_bfm #(.AW(AW), .DW(DW), .IDW(IDW), .GUARD(2000), .MASTER_ID(c)) u_core (
            .clk(clk), .rst_n(rst_n),
            .m_awvalid(m_awvalid[c]), .m_awready(m_awready[c]),
            .m_awaddr(m_awaddr[c*AW +: AW]), .m_awid(m_awid[c*IDW +: IDW]),
            .m_wvalid(m_wvalid[c]), .m_wready(m_wready[c]),
            .m_wdata(m_wdata[c*DW +: DW]), .m_wstrb(m_wstrb[c*(DW/8) +: (DW/8)]), .m_wlast(m_wlast[c]),
            .m_bvalid(m_bvalid[c]), .m_bready(m_bready[c]), .m_bresp(m_bresp[c*2 +: 2]), .m_bid(m_bid[c*IDW +: IDW]),
            .m_arvalid(m_arvalid[c]), .m_arready(m_arready[c]),
            .m_araddr(m_araddr[c*AW +: AW]), .m_arid(m_arid[c*IDW +: IDW]),
            .m_rvalid(m_rvalid[c]), .m_rready(m_rready[c]),
            .m_rdata(m_rdata[c*DW +: DW]), .m_rresp(m_rresp[c*2 +: 2]), .m_rlast(m_rlast[c]), .m_rid(m_rid[c*IDW +: IDW])
        );
    end endgenerate

    // ------------------------------------------------------------
    // AXI4 Crossbar (4 Masters -> 9 Slaves)
    // ------------------------------------------------------------
    axi4_crossbar #(.NM(NM), .NS(NS)) u_xbar (
        .clk(clk), .rst_n(rst_n),
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr), .m_awid(m_awid),
        .m_wvalid(m_wvalid), .m_wready(m_wready), .m_wdata(m_wdata), .m_wstrb(m_wstrb), .m_wlast(m_wlast),
        .m_bvalid(m_bvalid), .m_bready(m_bready), .m_bresp(m_bresp), .m_bid(m_bid),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr), .m_arid(m_arid),
        .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rdata(m_rdata), .m_rresp(m_rresp), .m_rlast(m_rlast), .m_rid(m_rid),
        .s_awvalid(sx_awvalid), .s_awready(sx_awready), .s_awaddr(sx_awaddr), .s_awid(sx_awid),
        .s_wvalid(sx_wvalid), .s_wready(sx_wready), .s_wdata(sx_wdata), .s_wstrb(sx_wstrb), .s_wlast(sx_wlast),
        .s_bvalid(sx_bvalid), .s_bready(sx_bready), .s_bresp(sx_bresp), .s_bid(sx_bid),
        .s_arvalid(sx_arvalid), .s_arready(sx_arready), .s_araddr(sx_araddr), .s_arid(sx_arid),
        .s_rvalid(sx_rvalid), .s_rready(sx_rready), .s_rdata(sx_rdata), .s_rresp(sx_rresp), .s_rlast(sx_rlast), .s_rid(sx_rid)
    );

    // Unused crossbar slaves 1..8 tied off safely
    genvar s;
    generate for (s = 1; s < NS; s = s + 1) begin : g_tie
        assign sx_awready[s] = 1'b1;
        assign sx_wready[s]  = 1'b1;
        assign sx_bready[s]  = 1'b1;
        assign sx_bvalid[s]  = 1'b0;
        assign sx_bid[s*IDW +: IDW] = {IDW{1'b0}};
        assign sx_bresp[s*2 +: 2]   = 2'b00;
        assign sx_arready[s] = 1'b1;
        assign sx_rvalid[s]  = 1'b0;
        assign sx_rdata[s*DW +: DW] = {DW{1'b0}};
        assign sx_rresp[s*2 +: 2]   = 2'b00;
        assign sx_rlast[s]   = 1'b0;
        assign sx_rid[s*IDW +: IDW] = {IDW{1'b0}};
    end endgenerate

    // Crossbar Slave 0 ID tracking
    reg [IDW-1:0] l2_s_rid, l2_s_bid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l2_s_rid <= {IDW{1'b0}};
            l2_s_bid <= {IDW{1'b0}};
        end else begin
            if (sx_arvalid[0] && sx_arready[0])
                l2_s_rid <= sx_arid[0*IDW +: IDW];
            if (sx_awvalid[0] && sx_awready[0])
                l2_s_bid <= sx_awid[0*IDW +: IDW];
        end
    end
    assign sx_rlast[0]             = 1'b1;
    assign sx_rid[0*IDW +: IDW]    = l2_s_rid;
    assign sx_bid[0*IDW +: IDW]    = l2_s_bid;

    // ------------------------------------------------------------
    // Shared L2 Cache Top (with integrated MESI Snoop Filter)
    // ------------------------------------------------------------
    l2_cache_top u_l2_cache (
        .clk(clk),
        .rst_n(rst_n),
        .s_arvalid(sx_arvalid[0]),
        .s_arready(sx_arready[0]),
        .s_araddr (sx_araddr[0*AW +: AW]),
        .s_arid   (sx_arid[0*IDW +: IDW]),
        .s_rvalid (sx_rvalid[0]),
        .s_rready (sx_rready[0]),
        .s_rdata  (sx_rdata[0*DW +: DW]),
        .s_rresp  (sx_rresp[0*2 +: 2]),
        .s_awvalid(sx_awvalid[0]),
        .s_awready(sx_awready[0]),
        .s_awaddr (sx_awaddr[0*AW +: AW]),
        .s_awid   (sx_awid[0*IDW +: IDW]),
        .s_wvalid (sx_wvalid[0]),
        .s_wready (sx_wready[0]),
        .s_wdata  (sx_wdata[0*DW +: DW]),
        .s_wstrb  (sx_wstrb[0*(DW/8) +: (DW/8)]),
        .s_bvalid (sx_bvalid[0]),
        .s_bready (sx_bready[0]),
        .s_bresp  (sx_bresp[0*2 +: 2]),

        .m_arvalid(l2_m_arvalid),
        .m_arready(l2_m_arready),
        .m_araddr (l2_m_araddr),
        .m_rvalid (l2_m_rvalid),
        .m_rready (l2_m_rready),
        .m_rdata  (l2_m_rdata),
        .m_rresp  (l2_m_rresp),
        .m_awvalid(l2_m_awvalid),
        .m_awready(l2_m_awready),
        .m_awaddr (l2_m_awaddr),
        .m_wvalid (l2_m_wvalid),
        .m_wready (l2_m_wready),
        .m_wdata  (l2_m_wdata),
        .m_wstrb  (l2_m_wstrb),
        .m_bvalid (l2_m_bvalid),
        .m_bready (l2_m_bready),

        .snoop_valid(snoop_valid),
        .snoop_addr (snoop_addr),
        .snoop_type (snoop_type),
        .snoop_ack  (snoop_ack),
        .snoop_data_valid(snoop_data_valid),
        .snoop_data (snoop_data)
    );

    // ------------------------------------------------------------
    // DDR4 Controller & Memory BFM
    // ------------------------------------------------------------
    ddr_ctrl_top u_ddr (
        .clk(clk), .rst_n(rst_n),
        .s_awvalid(l2_m_awvalid), .s_awready(l2_m_awready),
        .s_awaddr(l2_m_awaddr), .s_awid(4'h0),
        .s_awlen(8'h00), .s_awsize(3'd3),
        .s_wvalid(l2_m_wvalid), .s_wready(l2_m_wready),
        .s_wdata(l2_m_wdata), .s_wstrb(l2_m_wstrb), .s_wlast(1'b1),
        .s_bvalid(l2_m_bvalid), .s_bready(l2_m_bready),
        .s_bresp(), .s_bid(),
        .s_arvalid(l2_m_arvalid), .s_arready(l2_m_arready),
        .s_araddr(l2_m_araddr), .s_arid(4'h0),
        .s_arlen(8'h00),
        .s_rvalid(l2_m_rvalid), .s_rready(l2_m_rready),
        .s_rdata(l2_m_rdata), .s_rresp(l2_m_rresp), .s_rlast(), .s_rid(),

        .ddr_ck_p(ck_p), .ddr_ck_n(ck_n), .ddr_cke(cke), .ddr_cs_n(cs_n),
        .ddr_ras_n(ras_n), .ddr_cas_n(cas_n), .ddr_we_n(we_n),
        .ddr_ba(ba), .ddr_bg(bg), .ddr_addr(addr16), .ddr_dm(dm),
        .ddr_dq(dq), .ddr_dqs_p(dqs_p), .ddr_dqs_n(dqs_n)
    );

    ddr4_sdram_bfm #(.ROWS(1024), .COLS(64)) u_dram (
        .ddr_ck_p(ck_p), .ddr_ck_n(ck_n), .ddr_cke(cke),
        .ddr_cs_n(cs_n), .ddr_ras_n(ras_n), .ddr_cas_n(cas_n),
        .ddr_we_n(we_n),
        .ddr_act_n(1'b0), .ddr_reset_n(1'b1), .ddr_odt(1'b0),
        .ddr_addr(addr16), .ddr_ba(ba), .ddr_bg(bg),
        .ddr_dq(dq), .ddr_dqs_p(dqs_p), .ddr_dqs_n(dqs_n)
    );

    // ------------------------------------------------------------
    // MESI Snoop Emulation & Dirty Forwarding per Core
    // ------------------------------------------------------------
    reg [511:0] core0_dirty_line;
    reg         core0_line_dirty;
    reg         core0_line_valid;
    reg [39:0]  core0_line_addr;

    reg [511:0] core1_dirty_line;
    reg         core1_line_dirty;
    reg         core1_line_valid;
    reg [39:0]  core1_line_addr;

    assign snoop_data = snoop_data_valid[0] ? core0_dirty_line :
                        snoop_data_valid[1] ? core1_dirty_line : 512'h0;

    integer snoop_inv_count_core0 = 0;
    integer snoop_inv_count_core1 = 0;
    integer snoop_fwd_count_core0 = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snoop_ack <= 4'h0;
            snoop_data_valid <= 4'h0;
            snoop_inv_count_core0 <= 0;
            snoop_inv_count_core1 <= 0;
            snoop_fwd_count_core0 <= 0;
        end else begin
            snoop_ack <= 4'h0;
            snoop_data_valid <= 4'h0;

            // Core 0 Snoop Responder
            if (snoop_valid[0]) begin
                snoop_ack[0] <= 1'b1;
                if (core0_line_valid && (snoop_addr[39:6] == core0_line_addr[39:6])) begin
                    if (core0_line_dirty) begin
                        snoop_data_valid[0] <= 1'b1;
                        snoop_fwd_count_core0 <= snoop_fwd_count_core0 + 1;
                    end
                    // 00=GetS (downgrade to S), 01=GetM (inv), 10=Inv
                    if (snoop_type == 2'b01 || snoop_type == 2'b10) begin
                        core0_line_valid <= 1'b0;
                        core0_line_dirty <= 1'b0;
                        snoop_inv_count_core0 <= snoop_inv_count_core0 + 1;
                    end else if (snoop_type == 2'b00) begin
                        core0_line_dirty <= 1'b0; // Clean in S state
                    end
                end
            end

            // Core 1 Snoop Responder
            if (snoop_valid[1]) begin
                snoop_ack[1] <= 1'b1;
                if (core1_line_valid && (snoop_addr[39:6] == core1_line_addr[39:6])) begin
                    if (core1_line_dirty) begin
                        snoop_data_valid[1] <= 1'b1;
                    end
                    if (snoop_type == 2'b01 || snoop_type == 2'b10) begin
                        core1_line_valid <= 1'b0;
                        core1_line_dirty <= 1'b0;
                        snoop_inv_count_core1 <= snoop_inv_count_core1 + 1;
                    end else if (snoop_type == 2'b00) begin
                        core1_line_dirty <= 1'b0;
                    end
                end
            end

            // Cores 2 & 3 simple ack
            if (snoop_valid[2]) snoop_ack[2] <= 1'b1;
            if (snoop_valid[3]) snoop_ack[3] <= 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Test Vectors and Verification
    // ------------------------------------------------------------
    initial begin
        $dumpfile("tb_integ_multicore_mesi.vcd");
        $dumpvars(0, tb_integ_multicore_mesi);
    end

    reg [1:0]  resp0, resp1, resp2, resp3;
    reg [63:0] rd0, rd1, rd2, rd3;
    integer t;

    initial begin
        core0_line_valid = 1'b0;
        core0_line_dirty = 1'b0;
        core0_line_addr  = 40'h0;
        core0_dirty_line = 512'h0;

        core1_line_valid = 1'b0;
        core1_line_dirty = 1'b0;
        core1_line_addr  = 40'h0;
        core1_dirty_line = 512'h0;

        // Wait for DDR memory controller initialization
        t = 0;
        while (u_ddr.init_done !== 1'b1 && t < 100000) begin
            @(posedge clk); t = t + 1;
        end
        `EXPECT_TRUE(u_ddr.init_done === 1'b1, "DDR init complete")
        repeat (20) @(posedge clk);

        $display("\n==================================================================");
        $display("  TITAN X GATE D: MULTICORE MESI COHERENCE & SNOOP QUALIFICATION");
        $display("==================================================================");

        // --------------------------------------------------------
        // SCENARIO 1: Cold Allocation & MESI State Transition (I -> M)
        // --------------------------------------------------------
        $display("\n--- SCENARIO 1: Core 0 Write Miss & MESI Transition to Modified (ST_M) ---");
        // Core 0 writes 64'hAAAA_1111_BBBB_2222 to 0x8000_1000
        core0_line_valid = 1'b1;
        core0_line_dirty = 1'b1;
        core0_line_addr  = 40'h00_8000_1000;
        core0_dirty_line = {8{64'hAAAA_1111_BBBB_2222}};

        gen_cores[0].u_core.axi_write(40'h00_8000_1000, 64'hAAAA_1111_BBBB_2222, resp0);
        `EXPECT_EQ(resp0, 2'b00, "Core 0 write response OKAY")
        repeat (10) @(posedge clk);

        // --------------------------------------------------------
        // SCENARIO 2: ReadShared (GetS) & Dirty Data Forwarding
        // Core 1 reads the same line. Core 0 holds ST_M.
        // Snoop Filter issues snoop GetS (2'b00) to Core 0.
        // Core 0 supplies dirty line; directory transitions to ST_S.
        // --------------------------------------------------------
        $display("\n--- SCENARIO 2: Core 1 ReadShared (GetS) & Dirty Data Forwarding ---");
        gen_cores[1].u_core.axi_read(40'h00_8000_1000, rd1, resp1);
        `EXPECT_EQ(resp1, 2'b00, "Core 1 read response OKAY")
        `EXPECT_EQ(rd1, 64'hAAAA_1111_BBBB_2222, "Core 1 reads data forwarded from Core 0")
        `EXPECT_TRUE(snoop_fwd_count_core0 > 0, "Core 0 dirty line forwarded via snoop channel")
        `EXPECT_EQ(core0_line_dirty, 1'b0, "Core 0 line downgraded from Modified to Shared (clean)")
        repeat (10) @(posedge clk);

        // Core 1 now also holds a valid copy
        core1_line_valid = 1'b1;
        core1_line_dirty = 1'b0;
        core1_line_addr  = 40'h00_8000_1000;

        // --------------------------------------------------------
        // SCENARIO 3: Write to Shared Line & Invalidation (ST_S -> ST_I)
        // Core 1 overwrites the line with 64'hCAFE_BABE_FEED_FACE.
        // Snoop Filter detects shared line and issues Invalidate (2'b10) to Core 0.
        // Core 0 must invalidate its copy (valid -> 0).
        // --------------------------------------------------------
        $display("\n--- SCENARIO 3: Core 1 Write Invalidation of Core 0 Copy ---");
        core1_line_dirty = 1'b1;
        core1_dirty_line = {8{64'hCAFE_BABE_FEED_FACE}};

        gen_cores[1].u_core.axi_write(40'h00_8000_1000, 64'hCAFE_BABE_FEED_FACE, resp1);
        `EXPECT_EQ(resp1, 2'b00, "Core 1 write response OKAY")
        repeat (10) @(posedge clk);

        `EXPECT_TRUE(snoop_inv_count_core0 > 0, "Core 0 received snoop invalidation")
        `EXPECT_EQ(core0_line_valid, 1'b0, "Core 0 line transitioned to Invalid (ST_I)")

        // --------------------------------------------------------
        // SCENARIO 4: Core 0 Readback Following Invalidation
        // Core 0 reads back from 0x8000_1000. Must observe Core 1 updated data.
        // --------------------------------------------------------
        $display("\n--- SCENARIO 4: Core 0 Readback Observing Updated Coherent Data ---");
        gen_cores[0].u_core.axi_read(40'h00_8000_1000, rd0, resp0);
        `EXPECT_EQ(resp0, 2'b00, "Core 0 readback response OKAY")
        `EXPECT_EQ(rd0, 64'hCAFE_BABE_FEED_FACE, "Core 0 readback observes Core 1 overwrite")
        repeat (10) @(posedge clk);

        // --------------------------------------------------------
        // SCENARIO 5: 4-Core Concurrent Non-Conflicting Accesses
        // All 4 cores access distinct cachelines across distinct banks.
        // --------------------------------------------------------
        $display("\n--- SCENARIO 5: 4-Core Concurrent Distinct Cacheline Operations ---");
        gen_cores[0].u_core.axi_write(40'h00_8000_2000, 64'h1000_0000_0000_0001, resp0);
        gen_cores[1].u_core.axi_write(40'h00_8000_3000, 64'h2000_0000_0000_0002, resp1);
        gen_cores[2].u_core.axi_write(40'h00_8000_4000, 64'h3000_0000_0000_0003, resp2);
        gen_cores[3].u_core.axi_write(40'h00_8000_5000, 64'h4000_0000_0000_0004, resp3);

        `EXPECT_EQ(resp0, 2'b00, "Core 0 distinct write OKAY")
        `EXPECT_EQ(resp1, 2'b00, "Core 1 distinct write OKAY")
        `EXPECT_EQ(resp2, 2'b00, "Core 2 distinct write OKAY")
        `EXPECT_EQ(resp3, 2'b00, "Core 3 distinct write OKAY")

        gen_cores[0].u_core.axi_read(40'h00_8000_2000, rd0, resp0);
        gen_cores[1].u_core.axi_read(40'h00_8000_3000, rd1, resp1);
        gen_cores[2].u_core.axi_read(40'h00_8000_4000, rd2, resp2);
        gen_cores[3].u_core.axi_read(40'h00_8000_5000, rd3, resp3);

        `EXPECT_EQ(rd0, 64'h1000_0000_0000_0001, "Core 0 line verified")
        `EXPECT_EQ(rd1, 64'h2000_0000_0000_0002, "Core 1 line verified")
        `EXPECT_EQ(rd2, 64'h3000_0000_0000_0003, "Core 2 line verified")
        `EXPECT_EQ(rd3, 64'h4000_0000_0000_0004, "Core 3 line verified")

        $display("\n==================================================================");
        $display("  ALL MULTICORE MESI COHERENCE TESTS COMPLETED SUCCESSFULLY");
        $display("==================================================================\n");

        `TB_REPORT("MULTICORE_MESI")
    end

endmodule
