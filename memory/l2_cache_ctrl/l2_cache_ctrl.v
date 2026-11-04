// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — L2 Cache Controller
// Direct-mapped, write-through, 2KB capacity (64 sets × 32B line)
// States: IDLE → TAG_LOOKUP → HIT_SERVE → MISS_FETCH → MISS_FILL → WRITEBACK
`timescale 1ns/1ps
module l2_cache_ctrl #(
    parameter ADDR_W = 40,
    parameter DATA_W = 64,
    parameter TAG_W  = 28,  // 40 - 6(index) - 6(offset)
    parameter IDX_W  = 6,
    parameter OFF_W  = 6
) (
    input  wire              clk,
    input  wire              rst_n,
    // CPU-side AXI4-Lite slave
    input  wire              s_arvalid,  output reg        s_arready,
    input  wire [ADDR_W-1:0] s_araddr,
    output reg               s_rvalid,   input  wire       s_rready,
    output reg  [DATA_W-1:0] s_rdata,    output reg [1:0]  s_rresp,
    input  wire              s_awvalid,  output reg        s_awready,
    input  wire [ADDR_W-1:0] s_awaddr,
    input  wire              s_wvalid,   output reg        s_wready,
    input  wire [DATA_W-1:0] s_wdata,    input  wire [7:0] s_wstrb,
    output reg               s_bvalid,   input  wire       s_bready,
    output reg  [1:0]        s_bresp,
    // Memory-side AXI4 master (to DDR controller)
    output reg               m_arvalid,  input  wire       m_arready,
    output reg  [ADDR_W-1:0] m_araddr,
    input  wire              m_rvalid,   output reg        m_rready,
    input  wire [DATA_W-1:0] m_rdata,    input  wire [1:0] m_rresp,
    output reg               m_awvalid,  input  wire       m_awready,
    output reg  [ADDR_W-1:0] m_awaddr,
    output reg               m_wvalid,   input  wire       m_wready,
    output reg  [DATA_W-1:0] m_wdata,    output reg [7:0]  m_wstrb,
    input  wire              m_bvalid,   output reg        m_bready,
    // Tag array interface
    output reg               tag_cs,    output reg        tag_we,
    output reg  [IDX_W-1:0]  tag_index,
    output reg  [TAG_W-1:0]  tag_in,
    input  wire [TAG_W-1:0]  tag_out,   input  wire       tag_valid_out,
    // Data array interface
    output reg               dat_cs,    output reg        dat_we,
    output reg               dat_bank,
    output reg  [(DATA_W/8)-1:0] dat_wmask,
    output reg  [IDX_W-1:0]      dat_addr,
    output reg  [DATA_W-1:0]     dat_din,
    input  wire [DATA_W-1:0]     dat_dout,  input  wire       dat_dout_valid
);
    localparam ST_IDLE      = 3'd0;
    localparam ST_TAG_LU    = 3'd1;
    localparam ST_HIT       = 3'd2;
    localparam ST_MISS_FETCH= 3'd3;
    localparam ST_FILL      = 3'd4;
    localparam ST_WRTHR     = 3'd5;
    localparam ST_RESP      = 3'd6;

    reg [2:0] state;
    reg [ADDR_W-1:0] req_addr;
    reg [DATA_W-1:0] req_wdata;
    reg [7:0]        req_wstrb;
    reg              req_wr;
    reg [DATA_W-1:0] fetch_data;
    reg              aw_done;
    reg              w_done;
    reg              aw_latched;
    reg              w_latched;

    wire [TAG_W-1:0]  req_tag   = req_addr[ADDR_W-1 : OFF_W+IDX_W];
    wire [IDX_W-1:0]  req_index = req_addr[OFF_W+IDX_W-1 : OFF_W];
    wire              cache_hit = tag_valid_out && (tag_out == req_tag);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            s_arready  <= 1'b1;  s_awready <= 1'b1;  s_wready  <= 1'b1;
            s_rvalid   <= 1'b0;  s_rdata   <= {DATA_W{1'b0}}; s_rresp   <= 2'h0;
            s_bvalid   <= 1'b0;  s_bresp   <= 2'h0;
            m_arvalid  <= 1'b0;  m_awvalid <= 1'b0;  m_wvalid  <= 1'b0;
            m_rready   <= 1'b0;  m_bready  <= 1'b0;
            tag_cs     <= 1'b0;  tag_we    <= 1'b0;
            dat_cs     <= 1'b0;  dat_we    <= 1'b0;
            req_addr   <= {ADDR_W{1'b0}}; req_wr <= 1'b0;
            aw_done    <= 1'b0;  w_done    <= 1'b0;
            aw_latched <= 1'b0;  w_latched <= 1'b0;
        end else begin
            // Default deassert
            tag_cs   <= 1'b0;  dat_cs   <= 1'b0;
            s_rvalid <= 1'b0;  s_bvalid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (!aw_latched && !w_latched && s_arvalid && s_arready) begin
                        req_addr  <= s_araddr;
                        req_wr    <= 1'b0;
                        s_arready <= 1'b0;
                        s_awready <= 1'b0;
                        s_wready  <= 1'b0;
                        // Issue tag lookup
                        tag_cs    <= 1'b1;  tag_we <= 1'b0;
                        tag_index <= s_araddr[OFF_W+IDX_W-1:OFF_W];
                        state     <= ST_TAG_LU;
                    end else begin
                        // AW capture
                        if (s_awvalid && s_awready) begin
                            req_addr   <= s_awaddr;
                            aw_latched <= 1'b1;
                            s_awready  <= 1'b0;
                        end
                        // W capture
                        if (s_wvalid && s_wready) begin
                            req_wdata  <= s_wdata;
                            req_wstrb  <= s_wstrb;
                            w_latched  <= 1'b1;
                            s_wready   <= 1'b0;
                        end

                        // If both AW and W have been captured (now or previously)
                        if (((s_awvalid && s_awready) || aw_latched) &&
                            ((s_wvalid  && s_wready)  || w_latched)) begin
                            req_wr     <= 1'b1;
                            aw_latched <= 1'b0;
                            w_latched  <= 1'b0;
                            s_arready  <= 1'b0;
                            s_awready  <= 1'b0;
                            s_wready   <= 1'b0;
                            tag_cs     <= 1'b1;
                            tag_we     <= 1'b0;
                            tag_index  <= aw_latched ? req_addr[OFF_W+IDX_W-1:OFF_W] : s_awaddr[OFF_W+IDX_W-1:OFF_W];
                            state      <= ST_TAG_LU;
                        end else begin
                            // Maintain readiness for the pending channel
                            if (!aw_latched && !(s_awvalid && s_awready)) s_awready <= 1'b1;
                            if (!w_latched  && !(s_wvalid  && s_wready))  s_wready  <= 1'b1;
                            if (!aw_latched && !w_latched && !s_awvalid && !s_wvalid) s_arready <= 1'b1;
                            else s_arready <= 1'b0;
                        end
                    end
                end

                ST_TAG_LU: begin
                    // Tag lookup result available combinatorially
                    if (cache_hit && !req_wr) begin
                        // Read hit: fetch from data array
                        dat_cs   <= 1'b1;  dat_we   <= 1'b0;
                        dat_bank <= req_index[0];
                        dat_addr <= req_index;
                        state    <= ST_HIT;
                    end else if (cache_hit && req_wr) begin
                        // Write hit: update data array + write-through to DDR
                        dat_cs    <= 1'b1;  dat_we    <= 1'b1;
                        dat_bank  <= req_index[0];
                        dat_addr  <= req_index;
                        dat_din   <= req_wdata;
                        dat_wmask <= req_wstrb;
                        m_awvalid <= 1'b1;
                        m_awaddr  <= req_addr;
                        m_wvalid  <= 1'b1;
                        m_wdata   <= req_wdata;
                        m_wstrb   <= req_wstrb;
                        m_bready  <= 1'b1;
                        aw_done   <= 1'b0;
                        w_done    <= 1'b0;
                        state     <= ST_WRTHR;
                    end else begin
                        // Miss: fetch from DDR
                        m_arvalid <= 1'b1;
                        m_araddr  <= {req_addr[ADDR_W-1:OFF_W], {OFF_W{1'b0}}};
                        m_rready  <= 1'b1;
                        state     <= ST_MISS_FETCH;
                    end
                end

                ST_HIT: begin
                    if (s_rvalid) begin
                        if (s_rready) begin
                            s_rvalid  <= 1'b0;
                            s_arready <= 1'b1;
                            s_awready <= 1'b1;
                            s_wready  <= 1'b1;
                            state     <= ST_IDLE;
                        end else begin
                            s_rvalid  <= 1'b1; // hold until ready
                        end
                    end else if (dat_dout_valid) begin
                        s_rdata  <= dat_dout;
                        s_rvalid <= 1'b1;
                        s_rresp  <= 2'h0;
                    end
                end

                ST_MISS_FETCH: begin
                    if (m_arvalid && m_arready) m_arvalid <= 1'b0;
                    if (m_rvalid) begin
                        fetch_data <= m_rdata;
                        m_rready   <= 1'b0;
                        // Fill data array
                        dat_cs    <= 1'b1;  dat_we    <= 1'b1;
                        dat_bank  <= req_index[0];
                        dat_addr  <= req_index;
                        dat_din   <= m_rdata;
                        dat_wmask <= { (DATA_W/8){1'b1} };
                        // Update tag
                        tag_cs    <= 1'b1;  tag_we    <= 1'b1;
                        tag_index <= req_index;
                        tag_in    <= req_tag;
                        state     <= ST_FILL;
                    end
                end

                ST_FILL: begin
                    if (!req_wr) begin
                        if (s_rvalid) begin
                            if (s_rready) begin
                                s_rvalid  <= 1'b0;
                                s_arready <= 1'b1;
                                s_awready <= 1'b1;
                                s_wready  <= 1'b1;
                                state     <= ST_IDLE;
                            end else begin
                                s_rvalid  <= 1'b1; // hold until ready
                            end
                        end else begin
                            s_rdata  <= fetch_data;
                            s_rvalid <= 1'b1;
                            s_rresp  <= 2'h0;
                        end
                    end else begin
                        dat_cs    <= 1'b1;  dat_we    <= 1'b1;
                        dat_bank  <= req_index[0];
                        dat_addr  <= req_index;
                        dat_din   <= req_wdata;
                        dat_wmask <= req_wstrb;
                        m_awvalid <= 1'b1;
                        m_awaddr  <= req_addr;
                        m_wvalid  <= 1'b1;
                        m_wdata   <= req_wdata;
                        m_wstrb   <= req_wstrb;
                        m_bready  <= 1'b1;
                        aw_done   <= 1'b0;
                        w_done    <= 1'b0;
                        state     <= ST_WRTHR;
                    end
                end

                ST_WRTHR: begin
                    // Write-through to DDR
                    if (m_awvalid && m_awready) begin
                        m_awvalid <= 1'b0;
                        aw_done   <= 1'b1;
                    end
                    if (m_wvalid && m_wready) begin
                        m_wvalid  <= 1'b0;
                        w_done    <= 1'b1;
                    end
                    if (m_bvalid && m_bready) begin
                        m_bready <= 1'b0;
                        s_bvalid <= 1'b1;
                        s_bresp  <= 2'h0;
                        state    <= ST_RESP;
                    end
                end

                ST_RESP: begin
                    if (s_bready) begin
                        s_bvalid  <= 1'b0;
                        s_arready <= 1'b1;
                        s_awready <= 1'b1;
                        s_wready  <= 1'b1;
                        state     <= ST_IDLE;
                    end else begin
                        s_bvalid  <= 1'b1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
