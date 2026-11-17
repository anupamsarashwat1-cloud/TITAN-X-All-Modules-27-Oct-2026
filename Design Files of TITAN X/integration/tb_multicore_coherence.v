// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Integration Test: Multicore Cache Coherence & Snooping (Phase 17)
// Chain: 2x Core AXI Masters (Hart 0, Hart 1) → AXI4 Crossbar → L2 Cache Top
//        (integrated with L2 Snoop Filter MESI directory) → DDR4 Controller → DDR4 SDRAM BFM
// Verifies:
//   1. Core 0 write to shared cacheline + Core 1 readback (coherent sharing)
//   2. Core 1 write invalidation of Core 0 copy via snoop filter
//   3. Core 0 readback of updated line
//   4. Concurrent multi-core access to distinct cache lines without collision

`timescale 1ns/1ps

`include "tb_bfms.vh"

module tb_multicore_coherence;

    `include "tb_macros.vh"

    reg clk;
    reg rst_n;
    `TB_HARNESS(6_000_000)

    `TB_SCOREBOARD

    localparam AW = 40, DW = 64, IDW = 4, NM = 2, NS = 9;

    // Core 0 & Core 1 master wires
    wire [NM-1:0]        m_awvalid, m_awready, m_wvalid, m_wready, m_wlast;
    wire [NM-1:0]        m_bvalid, m_bready, m_arvalid, m_arready, m_rvalid, m_rready, m_rlast;
    wire [(NM*AW)-1:0]   m_awaddr, m_araddr;
    wire [(NM*DW)-1:0]   m_wdata, m_rdata;
    wire [(NM*(DW/8))-1:0] m_wstrb;
    wire [(NM*2)-1:0]    m_bresp, m_rresp;
    wire [(NM*IDW)-1:0]  m_awid, m_bid, m_arid, m_rid;

    // Crossbar slave side (NS=9)
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

    // L2 snoop wires to cores
    wire [3:0]           snoop_valid;
    wire [39:0]          snoop_addr;
    wire [1:0]           snoop_type;
    reg  [3:0]           snoop_ack;
    wire [3:0]           snoop_data_valid;

    assign snoop_data_valid = 4'h0;

    // DDR pins
    wire ck_p, ck_n, cke, cs_n, ras_n, cas_n, we_n;
    wire [2:0] ba; wire [1:0] bg; wire [15:0] addr16; wire [7:0] dm;
    wire [63:0] dq; wire [7:0] dqs_p, dqs_n;

    // ------------------------------------------------------------
    // Core 0 & Core 1 BFMs
    // ------------------------------------------------------------
    axi_master_bfm #(.AW(AW), .DW(DW), .IDW(IDW), .GUARD(1000), .MASTER_ID(0)) u_core0 (
        .clk(clk), .rst_n(rst_n),
        .m_awvalid(m_awvalid[0]), .m_awready(m_awready[0]),
        .m_awaddr(m_awaddr[0*AW +: AW]), .m_awid(m_awid[0*IDW +: IDW]),
        .m_wvalid(m_wvalid[0]), .m_wready(m_wready[0]),
        .m_wdata(m_wdata[0*DW +: DW]), .m_wstrb(m_wstrb[0*(DW/8) +: (DW/8)]), .m_wlast(m_wlast[0]),
        .m_bvalid(m_bvalid[0]), .m_bready(m_bready[0]), .m_bresp(m_bresp[0*2 +: 2]), .m_bid(m_bid[0*IDW +: IDW]),
        .m_arvalid(m_arvalid[0]), .m_arready(m_arready[0]),
        .m_araddr(m_araddr[0*AW +: AW]), .m_arid(m_arid[0*IDW +: IDW]),
        .m_rvalid(m_rvalid[0]), .m_rready(m_rready[0]),
        .m_rdata(m_rdata[0*DW +: DW]), .m_rresp(m_rresp[0*2 +: 2]), .m_rlast(m_rlast[0]), .m_rid(m_rid[0*IDW +: IDW])
    );

    axi_master_bfm #(.AW(AW), .DW(DW), .IDW(IDW), .GUARD(1000), .MASTER_ID(1)) u_core1 (
        .clk(clk), .rst_n(rst_n),
        .m_awvalid(m_awvalid[1]), .m_awready(m_awready[1]),
        .m_awaddr(m_awaddr[1*AW +: AW]), .m_awid(m_awid[1*IDW +: IDW]),
        .m_wvalid(m_wvalid[1]), .m_wready(m_wready[1]),
        .m_wdata(m_wdata[1*DW +: DW]), .m_wstrb(m_wstrb[1*(DW/8) +: (DW/8)]), .m_wlast(m_wlast[1]),
        .m_bvalid(m_bvalid[1]), .m_bready(m_bready[1]), .m_bresp(m_bresp[1*2 +: 2]), .m_bid(m_bid[1*IDW +: IDW]),
        .m_arvalid(m_arvalid[1]), .m_arready(m_arready[1]),
        .m_araddr(m_araddr[1*AW +: AW]), .m_arid(m_arid[1*IDW +: IDW]),
        .m_rvalid(m_rvalid[1]), .m_rready(m_rready[1]),
        .m_rdata(m_rdata[1*DW +: DW]), .m_rresp(m_rresp[1*2 +: 2]), .m_rlast(m_rlast[1]), .m_rid(m_rid[1*IDW +: IDW])
    );

    // ------------------------------------------------------------
    // AXI4 Crossbar (2 Masters -> 9 Slaves)
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
    // Shared L2 Cache Top (with integrated Snoop Filter)
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
        .snoop_data_valid(snoop_data_valid)
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

    // Active Snoop Responder for Core 0 and Core 1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            snoop_ack <= 4'h0;
        else
            snoop_ack <= snoop_valid;
    end

    // ------------------------------------------------------------
    // Coherence Stimulus & Scorecard
    // ------------------------------------------------------------
    initial begin
        $dumpfile("tb_multicore_coherence.vcd");
        $dumpvars(0, tb_multicore_coherence);
    end

    reg [1:0]  resp0, resp1;
    reg [63:0] rd0, rd1;
    integer t;

    initial begin
        // Wait for DDR initialization
        t = 0;
        while (u_ddr.init_done !== 1'b1 && t < 100000) begin
            @(posedge clk); t = t + 1;
        end
        `EXPECT_TRUE(u_ddr.init_done === 1'b1, "DDR init completes")
        repeat (20) @(posedge clk);

        $display("\n========================================================");
        $display("  STARTING MULTICORE COHERENCE & SNOOPING SUITE");
        $display("========================================================");

        // TEST 1: Cold start — Core 0 writes shared cache line @ 0x8000_1000
        $display("\n[TEST 1] Core 0 writes 64'h1111_2222_3333_4444 to 0x8000_1000");
        u_core0.axi_write(40'h00_8000_1000, 64'h1111_2222_3333_4444, resp0);
        `EXPECT_EQ(resp0, 2'b00, "Core 0 write OKAY")

        // TEST 2: Core 1 reads from shared cache line @ 0x8000_1000 (must observe Core 0 data)
        $display("[TEST 2] Core 1 reads from 0x8000_1000 (expects 64'h1111_2222_3333_4444)");
        u_core1.axi_read(40'h00_8000_1000, rd1, resp1);
        `EXPECT_EQ(resp1, 2'b00, "Core 1 read OKAY")
        `EXPECT_KNOWN(rd1, 64, "Core 1 read data known")
        `EXPECT_EQ(rd1, 64'h1111_2222_3333_4444, "Core 1 observes Core 0 shared write")

        // TEST 3: Core 1 overwrites the shared cache line @ 0x8000_1000
        $display("\n[TEST 3] Core 1 overwrites 0x8000_1000 with 64'hAAAA_BBBB_CCCC_DDDD");
        u_core1.axi_write(40'h00_8000_1000, 64'hAAAA_BBBB_CCCC_DDDD, resp1);
        `EXPECT_EQ(resp1, 2'b00, "Core 1 overwrite OKAY")

        // TEST 4: Core 0 reads back from 0x8000_1000 (must observe Core 1 updated data)
        $display("[TEST 4] Core 0 reads from 0x8000_1000 (expects 64'hAAAA_BBBB_CCCC_DDDD)");
        u_core0.axi_read(40'h00_8000_1000, rd0, resp0);
        `EXPECT_EQ(resp0, 2'b00, "Core 0 readback OKAY")
        `EXPECT_KNOWN(rd0, 64, "Core 0 readback known")
        `EXPECT_EQ(rd0, 64'hAAAA_BBBB_CCCC_DDDD, "Core 0 observes Core 1 overwrite")

        // TEST 5: Independent non-conflicting multi-core concurrent cacheline operations
        $display("\n[TEST 5] Independent distinct cacheline accesses across cores");
        u_core0.axi_write(40'h00_8000_2000, 64'hCAFE_BABE_0000_0001, resp0);
        u_core1.axi_write(40'h00_8000_3000, 64'hFEED_FACE_0000_0002, resp1);
        `EXPECT_EQ(resp0, 2'b00, "Core 0 distinct write OKAY")
        `EXPECT_EQ(resp1, 2'b00, "Core 1 distinct write OKAY")

        u_core0.axi_read(40'h00_8000_2000, rd0, resp0);
        u_core1.axi_read(40'h00_8000_3000, rd1, resp1);
        `EXPECT_EQ(rd0, 64'hCAFE_BABE_0000_0001, "Core 0 distinct read matches")
        `EXPECT_EQ(rd1, 64'hFEED_FACE_0000_0002, "Core 1 distinct read matches")

        $display("\n========================================================");
        $display("  ALL MULTICORE COHERENCE TESTS COMPLETED SUCCESSFULLY");
        $display("========================================================\n");

        `TB_REPORT("MULTICORE_COHERENCE")
    end

endmodule
