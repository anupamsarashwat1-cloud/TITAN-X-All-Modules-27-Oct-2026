// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — L2 Cache Controller
// 16-Way Set-Associative, 64-byte line, Burst Refill & Writeback, MESI Dirty Intervention
`timescale 1ns/1ps

module l2_cache_ctrl #(
    parameter ADDR_W = 40,
    parameter DATA_W = 64,
    parameter TAG_W  = 28,  // 40 - 6(index) - 6(offset)
    parameter IDX_W  = 6,   // 64 sets
    parameter OFF_W  = 6,   // 64B lines (8 beats of 64 bits)
    parameter WAYS   = 16,  // 16-way set-associative
    parameter SETS   = 64
) (
    input  wire              clk,
    input  wire              rst_n,

    // CPU-side AXI4-Lite slave (from crossbar/cores)
    input  wire              s_arvalid,
    output reg               s_arready,
    input  wire [ADDR_W-1:0] s_araddr,
    input  wire [3:0]        s_arid,
    output reg               s_rvalid,
    input  wire              s_rready,
    output reg  [DATA_W-1:0] s_rdata,
    output reg  [1:0]        s_rresp,

    input  wire              s_awvalid,
    output reg               s_awready,
    input  wire [ADDR_W-1:0] s_awaddr,
    input  wire [3:0]        s_awid,
    input  wire              s_wvalid,
    output reg               s_wready,
    input  wire [DATA_W-1:0] s_wdata,
    input  wire [7:0]        s_wstrb,
    output reg               s_bvalid,
    input  wire              s_bready,
    output reg  [1:0]        s_bresp,

    // Memory-side AXI4 burst master (to burst-to-lite shim / DDR)
    output reg               m_arvalid,
    input  wire              m_arready,
    output reg  [ADDR_W-1:0] m_araddr,
    output reg  [7:0]        m_arlen,
    output reg  [2:0]        m_arsize,
    output reg  [1:0]        m_arburst,
    input  wire              m_rvalid,
    output reg               m_rready,
    input  wire [DATA_W-1:0] m_rdata,
    input  wire [1:0]        m_rresp,
    input  wire              m_rlast,

    output reg               m_awvalid,
    input  wire              m_awready,
    output reg  [ADDR_W-1:0] m_awaddr,
    output reg  [7:0]        m_awlen,
    output reg  [2:0]        m_awsize,
    output reg  [1:0]        m_awburst,
    output reg               m_wvalid,
    input  wire              m_wready,
    output reg  [DATA_W-1:0] m_wdata,
    output reg  [7:0]        m_wstrb,
    output reg               m_wlast,
    input  wire              m_bvalid,
    output reg               m_bready,
    input  wire [1:0]        m_bresp,

    // Snoop filter request/response interface
    output reg               sf_req_valid,
    output reg  [ADDR_W-1:0] sf_req_addr,
    output reg  [1:0]        sf_req_type,   // 00=ReadShared, 01=ReadUnique/Write
    output reg  [1:0]        sf_req_core,
    input  wire              sf_resp_valid,
    input  wire              sf_resp_hit,
    input  wire              sf_resp_dirty,
    input  wire [1:0]        sf_resp_owner,
    input  wire [511:0]      snoop_data
);

    // ------------------------------------------------------------
    // States
    // ------------------------------------------------------------
    localparam ST_IDLE       = 4'd0;
    localparam ST_LOOKUP     = 4'd1;
    localparam ST_INTERVENE  = 4'd2;
    localparam ST_EVICT_AW   = 4'd3;
    localparam ST_EVICT_W    = 4'd4;
    localparam ST_EVICT_B    = 4'd5;
    localparam ST_REFILL_AR  = 4'd6;
    localparam ST_REFILL_R   = 4'd7;
    localparam ST_RESP_R     = 4'd8;
    localparam ST_RESP_W     = 4'd9;

    reg [3:0] state;

    // Latched transaction registers
    reg [ADDR_W-1:0] req_addr;
    reg [3:0]        req_id;
    reg [DATA_W-1:0] req_wdata;
    reg [7:0]        req_wstrb;
    reg              req_wr;

    reg [ADDR_W-1:0] awaddr_latched;
    reg [3:0]        awid_latched;
    reg [DATA_W-1:0] wdata_latched;
    reg [7:0]        wstrb_latched;
    reg              aw_pend, w_pend;

    // ------------------------------------------------------------
    // 16-Way Cache Arrays
    // ------------------------------------------------------------
    reg [TAG_W-1:0]  tag_mem     [0:SETS-1][0:WAYS-1];
    reg              valid_mem   [0:SETS-1][0:WAYS-1];
    reg              dirty_mem   [0:SETS-1][0:WAYS-1];
    reg [3:0]        replace_ptr [0:SETS-1];

    // Data array: SETS × WAYS × 8 beats (64-bit words)
    reg [DATA_W-1:0] data_mem    [0:SETS-1][0:WAYS-1][0:7];

    wire [TAG_W-1:0] req_tag     = req_addr[ADDR_W-1 : OFF_W+IDX_W];
    wire [IDX_W-1:0] req_index   = req_addr[OFF_W+IDX_W-1 : OFF_W];
    wire [2:0]       word_offset = req_addr[5:3];

    // 16-way combinational tag matching & hit detection
    reg [WAYS-1:0] way_hit_comb;
    reg [3:0]      hit_way_comb;
    reg            line_hit_comb;
    reg [3:0]      alloc_way_comb;
    integer w_idx;

    always @* begin
        way_hit_comb   = {WAYS{1'b0}};
        hit_way_comb   = 4'd0;
        line_hit_comb  = 1'b0;
        alloc_way_comb = replace_ptr[req_index];

        for (w_idx = 0; w_idx < WAYS; w_idx = w_idx + 1) begin
            if (valid_mem[req_index][w_idx] && (tag_mem[req_index][w_idx] == req_tag)) begin
                way_hit_comb[w_idx] = 1'b1;
                hit_way_comb        = w_idx[3:0];
                line_hit_comb       = 1'b1;
            end
        end

        // Prefer invalid way if available
        for (w_idx = WAYS - 1; w_idx >= 0; w_idx = w_idx - 1) begin
            if (!valid_mem[req_index][w_idx]) begin
                alloc_way_comb = w_idx[3:0];
            end
        end
    end

    // Refill & Eviction counters and registers
    reg [2:0]        refill_cnt;
    reg [2:0]        evict_cnt;
    reg [3:0]        target_way;
    reg [3:0]        evict_way;
    reg [DATA_W-1:0] read_word_latched;

    integer s_i, w_i, b_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= ST_IDLE;
            s_arready         <= 1'b1;
            s_awready         <= 1'b1;
            s_wready          <= 1'b1;
            s_rvalid          <= 1'b0;
            s_rdata           <= {DATA_W{1'b0}};
            s_rresp           <= 2'b00;
            s_bvalid          <= 1'b0;
            s_bresp           <= 2'b00;

            m_arvalid         <= 1'b0;
            m_araddr          <= {ADDR_W{1'b0}};
            m_arlen           <= 8'd0;
            m_arsize          <= 3'b011;
            m_arburst         <= 2'b01;
            m_rready          <= 1'b0;

            m_awvalid         <= 1'b0;
            m_awaddr          <= {ADDR_W{1'b0}};
            m_awlen           <= 8'd0;
            m_awsize          <= 3'b011;
            m_awburst         <= 2'b01;
            m_wvalid          <= 1'b0;
            m_wdata           <= {DATA_W{1'b0}};
            m_wstrb           <= 8'h00;
            m_wlast           <= 1'b0;
            m_bready          <= 1'b0;

            sf_req_valid      <= 1'b0;
            sf_req_addr       <= {ADDR_W{1'b0}};
            sf_req_type       <= 2'b00;
            sf_req_core       <= 2'b00;

            req_addr          <= {ADDR_W{1'b0}};
            req_id            <= 4'h0;
            req_wdata         <= {DATA_W{1'b0}};
            req_wstrb         <= 8'h0;
            req_wr            <= 1'b0;
            awaddr_latched    <= {ADDR_W{1'b0}};
            awid_latched      <= 4'h0;
            wdata_latched     <= {DATA_W{1'b0}};
            wstrb_latched     <= 8'h0;
            aw_pend           <= 1'b0;
            w_pend            <= 1'b0;
            refill_cnt        <= 3'd0;
            evict_cnt         <= 3'd0;
            target_way        <= 4'd0;
            evict_way         <= 4'd0;
            read_word_latched <= {DATA_W{1'b0}};

            for (s_i = 0; s_i < SETS; s_i = s_i + 1) begin
                replace_ptr[s_i] = 4'd0;
                for (w_i = 0; w_i < WAYS; w_i = w_i + 1) begin
                    valid_mem[s_i][w_i] = 1'b0;
                    dirty_mem[s_i][w_i] = 1'b0;
                    tag_mem[s_i][w_i]   = {TAG_W{1'b0}};
                    for (b_i = 0; b_i < 8; b_i = b_i + 1) begin
                        data_mem[s_i][w_i][b_i] = {DATA_W{1'b0}};
                    end
                end
            end
        end else begin
            sf_req_valid <= 1'b0; // Default pulse

            case (state)
                // ----------------------------------------------------
                // IDLE: Accept incoming Read or Write requests
                // ----------------------------------------------------
                ST_IDLE: begin
                    if (!aw_pend && !w_pend && s_arvalid && s_arready) begin
                        req_addr     <= s_araddr;
                        req_id       <= s_arid;
                        req_wr       <= 1'b0;
                        s_arready    <= 1'b0;
                        s_awready    <= 1'b0;
                        s_wready     <= 1'b0;

                        // Issue Snoop Filter request
                        sf_req_valid <= 1'b1;
                        sf_req_addr  <= s_araddr;
                        sf_req_type  <= 2'b00; // ReadShared
                        sf_req_core  <= s_arid[1:0];

                        state        <= ST_LOOKUP;
                    end else begin
                        // Latch Write Address
                        if (s_awvalid && s_awready) begin
                            awaddr_latched <= s_awaddr;
                            awid_latched   <= s_awid;
                            aw_pend        <= 1'b1;
                            s_awready      <= 1'b0;
                        end

                        // Latch Write Data
                        if (s_wvalid && s_wready) begin
                            wdata_latched <= s_wdata;
                            wstrb_latched <= s_wstrb;
                            w_pend        <= 1'b1;
                            s_wready      <= 1'b0;
                        end

                        // If both AW and W captured, start write transaction
                        if (((s_awvalid && s_awready) || aw_pend) &&
                            ((s_wvalid  && s_wready)  || w_pend)) begin
                            req_addr     <= aw_pend ? awaddr_latched : s_awaddr;
                            req_id       <= aw_pend ? awid_latched   : s_awid;
                            req_wdata    <= w_pend  ? wdata_latched  : s_wdata;
                            req_wstrb    <= w_pend  ? wstrb_latched  : s_wstrb;
                            req_wr       <= 1'b1;
                            aw_pend      <= 1'b0;
                            w_pend       <= 1'b0;
                            s_arready    <= 1'b0;
                            s_awready    <= 1'b0;
                            s_wready     <= 1'b0;

                            // Issue Snoop Filter request
                            sf_req_valid <= 1'b1;
                            sf_req_addr  <= aw_pend ? awaddr_latched : s_awaddr;
                            sf_req_type  <= 2'b01; // ReadUnique/Write
                            sf_req_core  <= aw_pend ? awid_latched[1:0] : s_awid[1:0];

                            state        <= ST_LOOKUP;
                        end else begin
                            if (!aw_pend && !(s_awvalid && s_awready)) s_awready <= 1'b1;
                            if (!w_pend  && !(s_wvalid  && s_wready))  s_wready  <= 1'b1;
                            if (!aw_pend && !w_pend && !s_awvalid && !s_wvalid) s_arready <= 1'b1;
                            else s_arready <= 1'b0;
                        end
                    end
                end

                // ----------------------------------------------------
                // LOOKUP: 16-way tag check & snoop filter response
                // ----------------------------------------------------
                ST_LOOKUP: begin
                    if (sf_resp_valid) begin
                        if (sf_resp_dirty) begin
                            // ----------------------------------------
                            // DIRTY-OWNER INTERVENTION:
                            // Another core holds line Modified; capture
                            // its dirty line directly via snoop channel.
                            // Bypasses stale DDR completely!
                            // ----------------------------------------
                            target_way <= line_hit_comb ? hit_way_comb : alloc_way_comb;

                            for (b_i = 0; b_i < 8; b_i = b_i + 1) begin
                                data_mem[req_index][line_hit_comb ? hit_way_comb : alloc_way_comb][b_i] <= snoop_data[b_i*64 +: 64];
                            end
                            tag_mem[req_index][line_hit_comb ? hit_way_comb : alloc_way_comb]   <= req_tag;
                            valid_mem[req_index][line_hit_comb ? hit_way_comb : alloc_way_comb] <= 1'b1;

                            if (!req_wr) begin
                                // Read served directly from snoop line
                                dirty_mem[req_index][line_hit_comb ? hit_way_comb : alloc_way_comb] <= 1'b0;
                                s_rdata  <= snoop_data[word_offset*64 +: 64];
                                s_rvalid <= 1'b1;
                                s_rresp  <= 2'b00;
                                state    <= ST_RESP_R;
                            end else begin
                                // Write merges new data into intervened line
                                for (b_i = 0; b_i < 8; b_i = b_i + 1) begin
                                    if (req_wstrb[b_i])
                                        data_mem[req_index][line_hit_comb ? hit_way_comb : alloc_way_comb][word_offset][b_i*8 +: 8] <= req_wdata[b_i*8 +: 8];
                                end
                                dirty_mem[req_index][line_hit_comb ? hit_way_comb : alloc_way_comb] <= 1'b1;
                                s_bvalid <= 1'b1;
                                s_bresp  <= 2'b00;
                                state    <= ST_RESP_W;
                            end
                        end else if (line_hit_comb) begin
                            // ----------------------------------------
                            // L2 CACHE HIT (Clean or existing dirty)
                            // ----------------------------------------
                            if (!req_wr) begin
                                s_rdata  <= data_mem[req_index][hit_way_comb][word_offset];
                                s_rvalid <= 1'b1;
                                s_rresp  <= 2'b00;
                                state    <= ST_RESP_R;
                            end else begin
                                for (b_i = 0; b_i < 8; b_i = b_i + 1) begin
                                    if (req_wstrb[b_i])
                                        data_mem[req_index][hit_way_comb][word_offset][b_i*8 +: 8] <= req_wdata[b_i*8 +: 8];
                                end
                                dirty_mem[req_index][hit_way_comb] <= 1'b1;
                                s_bvalid <= 1'b1;
                                s_bresp  <= 2'b00;
                                state    <= ST_RESP_W;
                            end
                        end else begin
                            // ----------------------------------------
                            // L2 CACHE MISS: Refill from DDR
                            // Check if victim way needs dirty writeback
                            // ----------------------------------------
                            target_way <= alloc_way_comb;
                            if (valid_mem[req_index][alloc_way_comb] && dirty_mem[req_index][alloc_way_comb]) begin
                                // Victim is dirty: 8-beat writeback burst
                                evict_way <= alloc_way_comb;
                                m_awvalid <= 1'b1;
                                m_awaddr  <= {tag_mem[req_index][alloc_way_comb], req_index, 6'b000000};
                                m_awlen   <= 8'd7;    // 8 beats
                                m_awsize  <= 3'b011;  // 8 bytes
                                m_awburst <= 2'b01;   // INCR
                                state     <= ST_EVICT_AW;
                            end else begin
                                // Victim clean/invalid: direct 8-beat read refill burst
                                m_arvalid  <= 1'b1;
                                m_araddr   <= {req_addr[ADDR_W-1:OFF_W], 6'b000000};
                                m_arlen    <= 8'd7;   // 8 beats
                                m_arsize   <= 3'b011; // 8 bytes
                                m_arburst  <= 2'b01;  // INCR
                                refill_cnt <= 3'd0;
                                state      <= ST_REFILL_AR;
                            end
                        end
                    end
                end

                // ----------------------------------------------------
                // EVICT AW: Emit writeback address to DDR
                // ----------------------------------------------------
                ST_EVICT_AW: begin
                    if (m_awvalid && m_awready) begin
                        m_awvalid <= 1'b0;
                        evict_cnt <= 3'd0;
                        m_wvalid  <= 1'b1;
                        m_wdata   <= data_mem[req_index][evict_way][0];
                        m_wstrb   <= 8'hFF;
                        m_wlast   <= 1'b0;
                        state     <= ST_EVICT_W;
                    end
                end

                // ----------------------------------------------------
                // EVICT W: Stream 8-beat writeback burst
                // ----------------------------------------------------
                ST_EVICT_W: begin
                    if (m_wvalid && m_wready) begin
                        if (evict_cnt == 3'd7) begin
                            m_wvalid <= 1'b0;
                            m_wlast  <= 1'b0;
                            m_bready <= 1'b1;
                            state    <= ST_EVICT_B;
                        end else begin
                            evict_cnt <= evict_cnt + 3'd1;
                            m_wvalid  <= 1'b1;
                            m_wdata   <= data_mem[req_index][evict_way][evict_cnt + 3'd1];
                            m_wstrb   <= 8'hFF;
                            m_wlast   <= (evict_cnt + 3'd1 == 3'd7);
                        end
                    end
                end

                // ----------------------------------------------------
                // EVICT B: Wait for DDR write response, then refill
                // ----------------------------------------------------
                ST_EVICT_B: begin
                    if (m_bvalid && m_bready) begin
                        m_bready   <= 1'b0;
                        // Now issue 8-beat refill burst
                        m_arvalid  <= 1'b1;
                        m_araddr   <= {req_addr[ADDR_W-1:OFF_W], 6'b000000};
                        m_arlen    <= 8'd7;   // 8 beats
                        m_arsize   <= 3'b011; // 8 bytes
                        m_arburst  <= 2'b01;  // INCR
                        refill_cnt <= 3'd0;
                        state      <= ST_REFILL_AR;
                    end
                end

                // ----------------------------------------------------
                // REFILL AR: Issue read refill address to DDR
                // ----------------------------------------------------
                ST_REFILL_AR: begin
                    if (m_arvalid && m_arready) begin
                        m_arvalid <= 1'b0;
                        m_rready  <= 1'b1;
                        state     <= ST_REFILL_R;
                    end
                end

                // ----------------------------------------------------
                // REFILL R: Collect 8 beats and assemble line
                // ----------------------------------------------------
                ST_REFILL_R: begin
                    if (m_rvalid && m_rready) begin
                        if (req_wr && (refill_cnt == word_offset)) begin
                            for (b_i = 0; b_i < 8; b_i = b_i + 1) begin
                                data_mem[req_index][target_way][refill_cnt][b_i*8 +: 8] <=
                                    req_wstrb[b_i] ? req_wdata[b_i*8 +: 8] : m_rdata[b_i*8 +: 8];
                            end
                        end else begin
                            data_mem[req_index][target_way][refill_cnt] <= m_rdata;
                        end

                        if (!req_wr && (refill_cnt == word_offset)) begin
                            read_word_latched <= m_rdata;
                        end

                        if (m_rlast || (refill_cnt == 3'd7)) begin
                            m_rready <= 1'b0;

                            // Update tag and valid
                            tag_mem[req_index][target_way]   <= req_tag;
                            valid_mem[req_index][target_way] <= 1'b1;
                            replace_ptr[req_index]           <= replace_ptr[req_index] + 4'd1;

                            if (!req_wr) begin
                                // Read miss satisfied
                                dirty_mem[req_index][target_way] <= 1'b0;
                                s_rdata  <= (refill_cnt == word_offset) ? m_rdata : read_word_latched;
                                s_rvalid <= 1'b1;
                                s_rresp  <= 2'b00;
                                state    <= ST_RESP_R;
                            end else begin
                                dirty_mem[req_index][target_way] <= 1'b1;
                                s_bvalid <= 1'b1;
                                s_bresp  <= 2'b00;
                                state    <= ST_RESP_W;
                            end
                        end else begin
                            refill_cnt <= refill_cnt + 3'd1;
                        end
                    end
                end

                // ----------------------------------------------------
                // RESP R: Deliver read data to requesting core
                // ----------------------------------------------------
                ST_RESP_R: begin
                    if (s_rvalid && s_rready) begin
                        s_rvalid  <= 1'b0;
                        s_arready <= 1'b1;
                        s_awready <= 1'b1;
                        s_wready  <= 1'b1;
                        state     <= ST_IDLE;
                    end
                end

                // ----------------------------------------------------
                // RESP W: Deliver write response to requesting core
                // ----------------------------------------------------
                ST_RESP_W: begin
                    if (s_bvalid && s_bready) begin
                        s_bvalid  <= 1'b0;
                        s_arready <= 1'b1;
                        s_awready <= 1'b1;
                        s_wready  <= 1'b1;
                        state     <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
