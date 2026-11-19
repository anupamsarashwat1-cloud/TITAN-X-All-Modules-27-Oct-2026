// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — AXI4 to AHB3-Lite Bridge
`timescale 1ns/1ps
// Width contract: the AXI slave side (DW) and the AHB master side (HDW) are
// INDEPENDENT parameters. The Titan-X fabric is 64-bit AXI but the AHB
// subsystem bus is 32 bits, so the bridge adapts: writes take the low HDW
// lanes of the AXI beat, reads are zero-extended into the AXI-width return.
// hsize stays 3'b010 (32-bit word) by construction — a single AXI beat maps
// to exactly one AHB word per transfer.
module axi4_to_ahb #(
    parameter AW  = 40,
    parameter DW  = 64,   // AXI-side datapath width (64 bits for Titan-X fabric)
    parameter HDW = 32,   // AHB-side datapath width (32 bits for peripheral subsystem)
    parameter IDW = 4
) (
    input  wire        clk,
    input  wire        rst_n,
    // AXI4-Lite slave
    input  wire        s_awvalid, output reg         s_awready,
    input  wire [AW-1:0] s_awaddr, input wire [IDW-1:0] s_awid,
    input  wire        s_wvalid,  output reg         s_wready,
    input  wire [DW-1:0] s_wdata, input wire [DW/8-1:0] s_wstrb,
    output reg         s_bvalid,  input  wire        s_bready,
    output wire [1:0]  s_bresp,   output wire [IDW-1:0] s_bid,
    input  wire        s_arvalid, output reg         s_arready,
    input  wire [AW-1:0] s_araddr, input wire [IDW-1:0] s_arid,
    output reg         s_rvalid,  input  wire        s_rready,
    output reg [DW-1:0] s_rdata,  output wire [1:0]  s_rresp,
    output wire        s_rlast,
    // AHB3-Lite master
    output reg [31:0]  haddr,
    output reg         hwrite,
    output reg [1:0]   htrans,
    output reg [2:0]   hsize,
    output reg [2:0]   hburst,
    output reg [HDW-1:0] hwdata,
    input  wire [HDW-1:0] hrdata,
    input  wire        hready,
    input  wire        hresp
);
    assign s_bresp = 2'h0;
    assign s_bid   = {IDW{1'b0}};
    assign s_rresp = 2'h0;
    assign s_rlast = 1'b1;

    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_NONSEQ = 2'b10;

    localparam BS_IDLE = 2'd0;
    localparam BS_ADDR = 2'd1;
    localparam BS_DATA = 2'd2;
    localparam BS_RESP = 2'd3;
    reg [1:0] bstate;
    reg is_wr;
    reg [IDW-1:0] saved_id;

    wire [HDW-1:0] wdata_sel = (s_awaddr[2] && (DW > HDW)) ? s_wdata[63:32] : s_wdata[31:0];
    wire [HDW-1:0] wdata_sel_hold = (haddr[2] && (DW > HDW)) ? s_wdata[63:32] : s_wdata[31:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bstate    <= BS_IDLE;
            s_awready <= 1'b1;
            s_arready <= 1'b1;
            s_wready  <= 1'b0;
            s_bvalid  <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= {DW{1'b0}};
            htrans    <= HTRANS_IDLE;
            hwrite    <= 1'b0;
            hsize     <= 3'b010;
            hburst    <= 3'b000;
            haddr     <= 32'h0;
            hwdata    <= {HDW{1'b0}};
            is_wr     <= 1'b0;
            saved_id  <= {IDW{1'b0}};
        end else begin
            s_bvalid <= 1'b0;
            s_rvalid <= 1'b0;
            case (bstate)
                BS_IDLE: begin
                    s_awready <= 1'b1;
                    s_arready <= 1'b1;
                    s_wready  <= 1'b0;
                    htrans    <= HTRANS_IDLE;
                    if (s_awvalid) begin
                        haddr     <= s_awaddr[31:0];
                        hwrite    <= 1'b1;
                        htrans    <= HTRANS_NONSEQ;
                        hsize     <= 3'b010;
                        saved_id  <= s_awid;
                        s_awready <= 1'b0;
                        is_wr     <= 1'b1;
                        if (s_wvalid) begin
                            hwdata   <= wdata_sel;
                            s_wready <= 1'b1;
                            bstate   <= BS_DATA;
                        end else begin
                            s_wready <= 1'b1;
                            bstate   <= BS_ADDR;
                        end
                    end else if (s_arvalid) begin
                        haddr     <= s_araddr[31:0];
                        hwrite    <= 1'b0;
                        htrans    <= HTRANS_NONSEQ;
                        hsize     <= 3'b010;
                        saved_id  <= s_arid;
                        s_arready <= 1'b0;
                        is_wr     <= 1'b0;
                        bstate    <= BS_DATA;
                    end
                end

                BS_ADDR: begin
                    if (s_wvalid) begin
                        hwdata   <= wdata_sel_hold;
                        s_wready <= 1'b1;
                        bstate   <= BS_DATA;
                    end
                end

                BS_DATA: begin
                    s_wready <= 1'b0;
                    if (is_wr) begin
                        if (hready) begin
                            s_bvalid <= 1'b1;
                            htrans   <= HTRANS_IDLE;
                            if (s_bready) begin
                                s_awready <= 1'b1;
                                s_arready <= 1'b1;
                                bstate    <= BS_IDLE;
                            end else begin
                                bstate    <= BS_RESP;
                            end
                        end
                    end else begin
                        if (hready) begin
                            s_rdata  <= (DW == 64) ? {hrdata, hrdata} : {{(DW-HDW){1'b0}}, hrdata};
                            s_rvalid <= 1'b1;
                            htrans   <= HTRANS_IDLE;
                            if (s_rready) begin
                                s_awready <= 1'b1;
                                s_arready <= 1'b1;
                                bstate    <= BS_IDLE;
                            end else begin
                                bstate    <= BS_RESP;
                            end
                        end
                    end
                end

                BS_RESP: begin
                    if (is_wr) begin
                        s_bvalid <= 1'b1;
                        if (s_bready) begin
                            s_awready <= 1'b1;
                            s_arready <= 1'b1;
                            bstate    <= BS_IDLE;
                        end
                    end else begin
                        s_rvalid <= 1'b1;
                        if (s_rready) begin
                            s_awready <= 1'b1;
                            s_arready <= 1'b1;
                            bstate    <= BS_IDLE;
                        end
                    end
                end

                default: bstate <= BS_IDLE;
            endcase
        end
    end
endmodule
