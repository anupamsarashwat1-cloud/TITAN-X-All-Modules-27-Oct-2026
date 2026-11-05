// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X SoC — On-Chip Scratchpad SRAM (AXI4 Slave)
// Mapped to Crossbar Slave 3 (0x0000_0000 - 0x0FFF_FFFF)
`timescale 1ns/1ps

module axi_sram #(
    parameter DEPTH = 8192, // 8K x 64-bit = 64 KB
    parameter AW    = 40,
    parameter DW    = 64,
    parameter IDW   = 4
) (
    input  wire                 clk,
    input  wire                 rst_n,

    // Write Address Channel
    input  wire                 s_awvalid,
    output reg                  s_awready,
    input  wire [AW-1:0]        s_awaddr,
    input  wire [IDW-1:0]       s_awid,

    // Write Data Channel
    input  wire                 s_wvalid,
    output reg                  s_wready,
    input  wire [DW-1:0]        s_wdata,
    input  wire [(DW/8)-1:0]    s_wstrb,
    input  wire                 s_wlast,

    // Write Response Channel
    output reg                  s_bvalid,
    input  wire                 s_bready,
    output wire [1:0]           s_bresp,
    output reg  [IDW-1:0]       s_bid,

    // Read Address Channel
    input  wire                 s_arvalid,
    output reg                  s_arready,
    input  wire [AW-1:0]        s_araddr,
    input  wire [IDW-1:0]       s_arid,

    // Read Data Channel
    output reg                  s_rvalid,
    input  wire                 s_rready,
    output reg  [DW-1:0]        s_rdata,
    output wire [1:0]           s_rresp,
    output reg                  s_rlast,
    output reg  [IDW-1:0]       s_rid
);

    assign s_bresp = 2'b00; // OKAY
    assign s_rresp = 2'b00; // OKAY

    // Memory array
`ifdef SYNTHESIS
    localparam DEPTH_INT = 64;
    localparam IDX_BITS  = 6;
`else
    localparam DEPTH_INT = DEPTH;
    localparam IDX_BITS  = $clog2(DEPTH);
`endif

    reg [DW-1:0] mem [0:DEPTH_INT-1];

`ifndef SYNTHESIS
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = {DW{1'b0}};
    end
`endif

    // Address indexing: 64-bit word address
    localparam ADDR_LSB = 3; // 8 bytes per 64-bit word

    // Write Channel FSM
    reg wr_busy;
    reg [IDX_BITS-1:0] wr_idx;
    reg [IDW-1:0] wr_id_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_awready <= 1'b1;
            s_wready  <= 1'b1;
            s_bvalid  <= 1'b0;
            s_bid     <= {IDW{1'b0}};
            wr_busy   <= 1'b0;
            wr_idx    <= {IDX_BITS{1'b0}};
            wr_id_reg <= {IDW{1'b0}};
        end else begin
            // B channel handshake
            if (s_bvalid && s_bready) begin
                s_bvalid <= 1'b0;
            end

            // AW & W processing
            if (!wr_busy) begin
                if (s_awvalid && s_awready) begin
                    wr_id_reg <= s_awid;
                    if (s_wvalid && s_wready) begin
                        // Simultaneous AW + W beat
                        if (s_wstrb[0]) mem[s_awaddr[ADDR_LSB +: IDX_BITS]][ 7: 0] <= s_wdata[ 7: 0];
                        if (s_wstrb[1]) mem[s_awaddr[ADDR_LSB +: IDX_BITS]][15: 8] <= s_wdata[15: 8];
                        if (s_wstrb[2]) mem[s_awaddr[ADDR_LSB +: IDX_BITS]][23:16] <= s_wdata[23:16];
                        if (s_wstrb[3]) mem[s_awaddr[ADDR_LSB +: IDX_BITS]][31:24] <= s_wdata[31:24];
                        if (s_wstrb[4]) mem[s_awaddr[ADDR_LSB +: IDX_BITS]][39:32] <= s_wdata[39:32];
                        if (s_wstrb[5]) mem[s_awaddr[ADDR_LSB +: IDX_BITS]][47:40] <= s_wdata[47:40];
                        if (s_wstrb[6]) mem[s_awaddr[ADDR_LSB +: IDX_BITS]][55:48] <= s_wdata[55:48];
                        if (s_wstrb[7]) mem[s_awaddr[ADDR_LSB +: IDX_BITS]][63:56] <= s_wdata[63:56];

                        if (s_wlast) begin
                            s_bvalid  <= 1'b1;
                            s_bid     <= s_awid;
                            s_awready <= 1'b1;
                            s_wready  <= 1'b1;
                            wr_busy   <= 1'b0;
                        end else begin
                            wr_idx    <= s_awaddr[ADDR_LSB +: IDX_BITS] + 1'b1;
                            s_awready <= 1'b0;
                            s_wready  <= 1'b1;
                            wr_busy   <= 1'b1;
                        end
                    end else begin
                        // AW arrived before W
                        wr_idx    <= s_awaddr[ADDR_LSB +: IDX_BITS];
                        s_awready <= 1'b0;
                        s_wready  <= 1'b1;
                        wr_busy   <= 1'b1;
                    end
                end
            end else begin
                // Continuing W beats in burst
                if (s_wvalid && s_wready) begin
                    if (s_wstrb[0]) mem[wr_idx][ 7: 0] <= s_wdata[ 7: 0];
                    if (s_wstrb[1]) mem[wr_idx][15: 8] <= s_wdata[15: 8];
                    if (s_wstrb[2]) mem[wr_idx][23:16] <= s_wdata[23:16];
                    if (s_wstrb[3]) mem[wr_idx][31:24] <= s_wdata[31:24];
                    if (s_wstrb[4]) mem[wr_idx][39:32] <= s_wdata[39:32];
                    if (s_wstrb[5]) mem[wr_idx][47:40] <= s_wdata[47:40];
                    if (s_wstrb[6]) mem[wr_idx][55:48] <= s_wdata[55:48];
                    if (s_wstrb[7]) mem[wr_idx][63:56] <= s_wdata[63:56];

                    wr_idx <= wr_idx + 1'b1;

                    if (s_wlast) begin
                        s_bvalid  <= 1'b1;
                        s_bid     <= wr_id_reg;
                        s_awready <= 1'b1;
                        s_wready  <= 1'b1;
                        wr_busy   <= 1'b0;
                    end
                end
            end
        end
    end

    // Read Channel FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_arready <= 1'b1;
            s_rvalid  <= 1'b0;
            s_rdata   <= {DW{1'b0}};
            s_rlast   <= 1'b0;
            s_rid     <= {IDW{1'b0}};
        end else begin
            if (s_rvalid && s_rready) begin
                s_rvalid  <= 1'b0;
                s_rlast   <= 1'b0;
                s_arready <= 1'b1;
            end

            if (s_arvalid && s_arready) begin
                s_rdata   <= mem[s_araddr[ADDR_LSB +: IDX_BITS]];
                s_rid     <= s_arid;
                s_rvalid  <= 1'b1;
                s_rlast   <= 1'b1;
                s_arready <= 1'b0;
            end
        end
    end

endmodule
