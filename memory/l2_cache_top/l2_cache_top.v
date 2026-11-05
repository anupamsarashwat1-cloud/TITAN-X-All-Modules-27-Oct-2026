// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — L2 Cache Top (Default 64KB, Scalable to 512KB/2MB, 16-way, 64B lines)
// Integrates 16-Way l2_cache_ctrl, l2_snoop_filter (MESI directory), and axi4_burst_to_lite.
`timescale 1ns/1ps
`include "params.vh"

module l2_cache_top #(
    parameter WAYS = 16,
    parameter SETS = 64
) (
    input  wire        clk,
    input  wire        rst_n,

    // AXI4-Lite slave (from crossbar / L1s)
    input  wire        s_arvalid,  output wire        s_arready,
    input  wire [39:0] s_araddr,
    input  wire [3:0]  s_arid,
    output wire        s_rvalid,   input  wire        s_rready,
    output wire [63:0] s_rdata,    output wire [1:0]  s_rresp,
    input  wire        s_awvalid,  output wire        s_awready,
    input  wire [39:0] s_awaddr,
    input  wire [3:0]  s_awid,
    input  wire        s_wvalid,   output wire        s_wready,
    input  wire [63:0] s_wdata,    input  wire [7:0]  s_wstrb,
    output wire        s_bvalid,   input  wire        s_bready,
    output wire [1:0]  s_bresp,

    // AXI4 master (to DDR controller)
    output wire        m_arvalid,  input  wire        m_arready,
    output wire [39:0] m_araddr,
    input  wire        m_rvalid,   output wire        m_rready,
    input  wire [63:0] m_rdata,    input  wire [1:0]  m_rresp,
    output wire        m_awvalid,  input  wire        m_awready,
    output wire [39:0] m_awaddr,
    output wire        m_wvalid,   input  wire        m_wready,
    output wire [63:0] m_wdata,    output wire [7:0]  m_wstrb,
    input  wire        m_bvalid,   output wire        m_bready,

    // L1 Snoop Interfaces (4 Application Cores)
    output wire [3:0]   snoop_valid,
    output wire [39:0]  snoop_addr,
    output wire [1:0]   snoop_type,
    input  wire [3:0]   snoop_ack,
    input  wire [3:0]   snoop_data_valid,
    input  wire [511:0] snoop_data
);

    // -------------------------------------------------------
    // Internal Wires: Controller ↔ Snoop Filter
    // -------------------------------------------------------
    wire        sf_req_valid;
    wire [39:0] sf_req_addr;
    wire [1:0]  sf_req_type;
    wire [1:0]  sf_req_core;
    wire        sf_resp_valid;
    wire        sf_resp_hit;
    wire        sf_resp_dirty;
    wire [1:0]  sf_resp_owner;

    reg [511:0] snoop_data_latched;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            snoop_data_latched <= 512'h0;
        else if (|snoop_data_valid)
            snoop_data_latched <= snoop_data;
    end
    wire [511:0] eff_snoop_data = (|snoop_data_valid) ? snoop_data : snoop_data_latched;

    // -------------------------------------------------------
    // Internal Wires: Controller ↔ Burst-to-Lite Shim
    // -------------------------------------------------------
    wire        ctrl_arvalid, ctrl_arready;
    wire [39:0] ctrl_araddr;
    wire [7:0]  ctrl_arlen;
    wire [2:0]  ctrl_arsize;
    wire [1:0]  ctrl_arburst;
    wire        ctrl_rvalid,  ctrl_rready, ctrl_rlast;
    wire [63:0] ctrl_rdata;
    wire [1:0]  ctrl_rresp;

    wire        ctrl_awvalid, ctrl_awready;
    wire [39:0] ctrl_awaddr;
    wire [7:0]  ctrl_awlen;
    wire [2:0]  ctrl_awsize;
    wire [1:0]  ctrl_awburst;
    wire        ctrl_wvalid,  ctrl_wready, ctrl_wlast;
    wire [63:0] ctrl_wdata;
    wire [7:0]  ctrl_wstrb;
    wire        ctrl_bvalid,  ctrl_bready;
    wire [1:0]  ctrl_bresp;

    // -------------------------------------------------------
    // Dynamic Geometry Parameters (DEF-ARCH-03)
    // -------------------------------------------------------
    localparam IDX_W = $clog2(SETS);
    localparam TAG_W = 40 - 6 - IDX_W;

    // -------------------------------------------------------
    // 16-Way Set-Associative L2 Cache Controller
    // -------------------------------------------------------
    l2_cache_ctrl #(
        .ADDR_W(40),
        .DATA_W(64),
        .TAG_W(TAG_W),
        .IDX_W(IDX_W),
        .OFF_W(6),
        .WAYS(WAYS),
        .SETS(SETS)
    ) u_ctrl (
        .clk(clk),
        .rst_n(rst_n),

        // CPU-side slave face
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_araddr(s_araddr),
        .s_arid(s_arid),
        .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .s_awvalid(s_awvalid),
        .s_awready(s_awready),
        .s_awaddr(s_awaddr),
        .s_awid(s_awid),
        .s_wvalid(s_wvalid),
        .s_wready(s_wready),
        .s_wdata(s_wdata),
        .s_wstrb(s_wstrb),
        .s_bvalid(s_bvalid),
        .s_bready(s_bready),
        .s_bresp(s_bresp),

        // Memory-side burst master face
        .m_arvalid(ctrl_arvalid),
        .m_arready(ctrl_arready),
        .m_araddr(ctrl_araddr),
        .m_arlen(ctrl_arlen),
        .m_arsize(ctrl_arsize),
        .m_arburst(ctrl_arburst),
        .m_rvalid(ctrl_rvalid),
        .m_rready(ctrl_rready),
        .m_rdata(ctrl_rdata),
        .m_rresp(ctrl_rresp),
        .m_rlast(ctrl_rlast),

        .m_awvalid(ctrl_awvalid),
        .m_awready(ctrl_awready),
        .m_awaddr(ctrl_awaddr),
        .m_awlen(ctrl_awlen),
        .m_awsize(ctrl_awsize),
        .m_awburst(ctrl_awburst),
        .m_wvalid(ctrl_wvalid),
        .m_wready(ctrl_wready),
        .m_wdata(ctrl_wdata),
        .m_wstrb(ctrl_wstrb),
        .m_wlast(ctrl_wlast),
        .m_bvalid(ctrl_bvalid),
        .m_bready(ctrl_bready),
        .m_bresp(ctrl_bresp),

        // Snoop filter interface
        .sf_req_valid(sf_req_valid),
        .sf_req_addr(sf_req_addr),
        .sf_req_type(sf_req_type),
        .sf_req_core(sf_req_core),
        .sf_resp_valid(sf_resp_valid),
        .sf_resp_hit(sf_resp_hit),
        .sf_resp_dirty(sf_resp_dirty),
        .sf_resp_owner(sf_resp_owner),
        .snoop_data(eff_snoop_data)
    );

    // -------------------------------------------------------
    // MESI Snoop Filter (Coherence Directory for L1 D-Caches)
    // -------------------------------------------------------
    l2_snoop_filter #(
        .NUM_CORES(4),
        .ADDR_W(40),
        .TAG_W(28),
        .INDEX_W(6),
        .WAYS(8)
    ) u_snoop_filter (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(sf_req_valid),
        .req_addr(sf_req_addr),
        .req_type(sf_req_type),
        .req_core(sf_req_core),
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_type(snoop_type),
        .snoop_ack(snoop_ack),
        .snoop_data_valid(snoop_data_valid),
        .resp_valid(sf_resp_valid),
        .resp_hit(sf_resp_hit),
        .resp_dirty(sf_resp_dirty),
        .resp_owner(sf_resp_owner)
    );

    // -------------------------------------------------------
    // AXI4 Burst-to-Lite Shim (Decomposes 8-beat bursts for DDR)
    // -------------------------------------------------------
    axi4_burst_to_lite #(
        .ADDR_W(40),
        .DATA_W(64),
        .MAX_BEATS(8)
    ) u_b2l (
        .clk(clk),
        .rst_n(rst_n),

        // Slave face from L2 Controller
        .s_arvalid(ctrl_arvalid),
        .s_arready(ctrl_arready),
        .s_araddr(ctrl_araddr),
        .s_arlen(ctrl_arlen),
        .s_arsize(ctrl_arsize),
        .s_arburst(ctrl_arburst),
        .s_rvalid(ctrl_rvalid),
        .s_rready(ctrl_rready),
        .s_rdata(ctrl_rdata),
        .s_rlast(ctrl_rlast),
        .s_rresp(ctrl_rresp),

        .s_awvalid(ctrl_awvalid),
        .s_awready(ctrl_awready),
        .s_awaddr(ctrl_awaddr),
        .s_awlen(ctrl_awlen),
        .s_awsize(ctrl_awsize),
        .s_awburst(ctrl_awburst),
        .s_wvalid(ctrl_wvalid),
        .s_wready(ctrl_wready),
        .s_wdata(ctrl_wdata),
        .s_wstrb(ctrl_wstrb),
        .s_wlast(ctrl_wlast),
        .s_bvalid(ctrl_bvalid),
        .s_bready(ctrl_bready),
        .s_bresp(ctrl_bresp),

        // Master face toward DDR Controller
        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_araddr(m_araddr),
        .m_arlen(),
        .m_arsize(),
        .m_arburst(),
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .m_rdata(m_rdata),
        .m_rlast(1'b1),
        .m_rresp(m_rresp),

        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_awaddr(m_awaddr),
        .m_awlen(),
        .m_awsize(),
        .m_awburst(),
        .m_wvalid(m_wvalid),
        .m_wready(m_wready),
        .m_wdata(m_wdata),
        .m_wstrb(m_wstrb),
        .m_wlast(),
        .m_bvalid(m_bvalid),
        .m_bready(m_bready),
        .m_bresp(2'b00)
    );

endmodule
