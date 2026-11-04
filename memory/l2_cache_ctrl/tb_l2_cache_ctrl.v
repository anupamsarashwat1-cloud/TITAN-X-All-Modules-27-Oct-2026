// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — L2 Cache Controller Unit Qualification
// Module: tb_l2_cache_ctrl
//
// Verification Coverage:
//   1. Cold Read Miss: Native 8-beat AXI4 INCR burst refill (arlen=7, arsize=3, arburst=01).
//   2. Read Hit: Instant response with 0 master bus cycles.
//   3. Write Hit: In-place update, marked dirty, 0 master bus writes.
//   4. 16-Way Set Associativity: 16 concurrent lines in Set 8 retained without thrashing.
//   5. 17th Way Conflict & Eviction: Native 8-beat AXI4 INCR burst writeback (awlen=7, wlast on beat 7).
//   6. MESI Dirty Intervention: Direct capture from snoop interface, 0 memory reads.
//   7. Write-Allocate Merge: Refill stream merges partial/full stores accurately.
//   8. Reset & Idle Recovery: Clean return to ready state upon reset.

`timescale 1ns/1ps

`include "tb_macros.vh"

module tb_l2_cache_ctrl;

    reg clk;
    reg rst_n;
    `TB_HARNESS(20_000_000)
    `TB_SCOREBOARD

    // CPU-side AXI4-Lite slave
    reg         s_arvalid;
    wire        s_arready;
    reg  [39:0] s_araddr;
    reg  [3:0]  s_arid;
    wire        s_rvalid;
    reg         s_rready;
    wire [63:0] s_rdata;
    wire [1:0]  s_rresp;

    reg         s_awvalid;
    wire        s_awready;
    reg  [39:0] s_awaddr;
    reg  [3:0]  s_awid;
    reg         s_wvalid;
    wire        s_wready;
    reg  [63:0] s_wdata;
    reg  [7:0]  s_wstrb;
    wire        s_bvalid;
    reg         s_bready;
    wire [1:0]  s_bresp;

    // Memory-side native AXI4 burst master
    wire        m_arvalid;
    reg         m_arready;
    wire [39:0] m_araddr;
    wire [7:0]  m_arlen;
    wire [2:0]  m_arsize;
    wire [1:0]  m_arburst;
    reg         m_rvalid;
    wire        m_rready;
    reg  [63:0] m_rdata;
    reg  [1:0]  m_rresp;
    reg         m_rlast;

    wire        m_awvalid;
    reg         m_awready;
    wire [39:0] m_awaddr;
    wire [7:0]  m_awlen;
    wire [2:0]  m_awsize;
    wire [1:0]  m_awburst;
    wire        m_wvalid;
    reg         m_wready;
    wire [63:0] m_wdata;
    wire [7:0]  m_wstrb;
    wire        m_wlast;
    reg         m_bvalid;
    wire        m_bready;
    reg  [1:0]  m_bresp;

    // Snoop filter interface
    wire        sf_req_valid;
    wire [39:0] sf_req_addr;
    wire [1:0]  sf_req_type;
    wire [1:0]  sf_req_core;
    reg         sf_resp_valid;
    reg         sf_resp_hit;
    reg         sf_resp_dirty;
    reg  [1:0]  sf_resp_owner;
    reg  [511:0] snoop_data;

    // DUT Instantiation
    l2_cache_ctrl #(
        .ADDR_W(40),
        .DATA_W(64),
        .TAG_W(28),
        .IDX_W(6),
        .OFF_W(6),
        .WAYS(16),
        .SETS(64)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),

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

        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_araddr(m_araddr),
        .m_arlen(m_arlen),
        .m_arsize(m_arsize),
        .m_arburst(m_arburst),
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .m_rdata(m_rdata),
        .m_rresp(m_rresp),
        .m_rlast(m_rlast),

        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_awaddr(m_awaddr),
        .m_awlen(m_awlen),
        .m_awsize(m_awsize),
        .m_awburst(m_awburst),
        .m_wvalid(m_wvalid),
        .m_wready(m_wready),
        .m_wdata(m_wdata),
        .m_wstrb(m_wstrb),
        .m_wlast(m_wlast),
        .m_bvalid(m_bvalid),
        .m_bready(m_bready),
        .m_bresp(m_bresp),

        .sf_req_valid(sf_req_valid),
        .sf_req_addr(sf_req_addr),
        .sf_req_type(sf_req_type),
        .sf_req_core(sf_req_core),
        .sf_resp_valid(sf_resp_valid),
        .sf_resp_hit(sf_resp_hit),
        .sf_resp_dirty(sf_resp_dirty),
        .sf_resp_owner(sf_resp_owner),
        .snoop_data(snoop_data)
    );

    // ------------------------------------------------------------
    // Snoop Filter Model
    // ------------------------------------------------------------
    reg        sf_intervene_mode;
    reg [39:0] sf_intervene_addr;
    reg [511:0] sf_intervene_line;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sf_resp_valid <= 1'b0;
            sf_resp_hit   <= 1'b0;
            sf_resp_dirty <= 1'b0;
            sf_resp_owner <= 2'b00;
            snoop_data    <= 512'h0;
        end else begin
            sf_resp_valid <= 1'b0;
            if (sf_req_valid) begin
                sf_resp_valid <= 1'b1;
                if (sf_intervene_mode && (sf_req_addr[39:6] == sf_intervene_addr[39:6])) begin
                    sf_resp_hit   <= 1'b1;
                    sf_resp_dirty <= 1'b1;
                    sf_resp_owner <= 2'd0;
                    snoop_data    <= sf_intervene_line;
                end else begin
                    sf_resp_hit   <= 1'b0;
                    sf_resp_dirty <= 1'b0;
                    sf_resp_owner <= 2'd0;
                    snoop_data    <= 512'h0;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Native AXI4 Burst Memory Responder
    // ------------------------------------------------------------
    reg [63:0] ddr_mem [0:65535];
    integer init_i;
    initial begin
        for (init_i = 0; init_i < 65536; init_i = init_i + 1) begin
            ddr_mem[init_i] = {32'hAA00_0000 | init_i[15:0], 32'h5500_0000 | init_i[15:0]};
        end
    end

    integer burst_read_count;
    integer burst_write_count;
    integer read_beat_count;
    integer write_beat_count;

    reg [39:0] cur_rd_addr;
    reg [7:0]  cur_rd_len, rd_cnt;
    reg        rd_active;

    reg [39:0] cur_wr_addr;
    reg [7:0]  cur_wr_len, wr_cnt;
    reg        wr_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_arready         <= 1'b1;
            m_rvalid          <= 1'b0;
            m_rdata           <= 64'h0;
            m_rresp           <= 2'b00;
            m_rlast           <= 1'b0;
            m_awready         <= 1'b1;
            m_wready          <= 1'b0;
            m_bvalid          <= 1'b0;
            m_bresp           <= 2'b00;
            rd_active         <= 1'b0;
            wr_active         <= 1'b0;
            burst_read_count  <= 0;
            burst_write_count <= 0;
            read_beat_count   <= 0;
            write_beat_count  <= 0;
            rd_cnt            <= 8'h0;
            wr_cnt            <= 8'h0;
        end else begin
            // Burst Read
            if (rd_active) begin
                if (m_rvalid && m_rready) begin
                    read_beat_count <= read_beat_count + 1;
                    if (m_rlast) begin
                        m_rvalid  <= 1'b0;
                        m_rlast   <= 1'b0;
                        rd_active <= 1'b0;
                        m_arready <= 1'b1;
                    end else begin
                        rd_cnt   <= rd_cnt + 8'd1;
                        m_rdata  <= ddr_mem[(((cur_rd_addr >> 3) + rd_cnt + 1)) & 16'hFFFF];
                        m_rlast  <= (rd_cnt + 8'd1 == cur_rd_len);
                        m_rvalid <= 1'b1;
                    end
                end
            end else if (m_arvalid && m_arready) begin
                `EXPECT_EQ(m_arlen, 8'd7, "l2_cache_ctrl: arlen must be 7 (8 beats)")
                `EXPECT_EQ(m_arsize, 3'd3, "l2_cache_ctrl: arsize must be 3 (8 bytes)")
                `EXPECT_EQ(m_arburst, 2'b01, "l2_cache_ctrl: arburst must be INCR (01)")
                `EXPECT_EQ(m_araddr[5:0], 6'b000000, "l2_cache_ctrl: araddr must be 64B aligned")

                cur_rd_addr      <= m_araddr;
                cur_rd_len       <= m_arlen;
                rd_cnt           <= 8'h0;
                burst_read_count <= burst_read_count + 1;
                m_arready        <= 1'b0;
                rd_active        <= 1'b1;

                m_rvalid         <= 1'b1;
                m_rdata          <= ddr_mem[(m_araddr >> 3) & 16'hFFFF];
                m_rlast          <= (m_arlen == 8'h0);
                m_rresp          <= 2'b00;
            end

            // Burst Write
            if (m_bvalid && m_bready) begin
                m_bvalid   <= 1'b0;
                m_awready  <= 1'b1;
                wr_active  <= 1'b0;
            end else if (wr_active) begin
                if (m_wvalid && m_wready) begin
                    write_beat_count <= write_beat_count + 1;
                    `EXPECT_EQ(m_wlast, (wr_cnt == cur_wr_len), "l2_cache_ctrl: wlast must match last beat")
                    if (m_wstrb[0]) ddr_mem[((cur_wr_addr >> 3) + wr_cnt) & 16'hFFFF][7:0]   <= m_wdata[7:0];
                    if (m_wstrb[1]) ddr_mem[((cur_wr_addr >> 3) + wr_cnt) & 16'hFFFF][15:8]  <= m_wdata[15:8];
                    if (m_wstrb[2]) ddr_mem[((cur_wr_addr >> 3) + wr_cnt) & 16'hFFFF][23:16] <= m_wdata[23:16];
                    if (m_wstrb[3]) ddr_mem[((cur_wr_addr >> 3) + wr_cnt) & 16'hFFFF][31:24] <= m_wdata[31:24];
                    if (m_wstrb[4]) ddr_mem[((cur_wr_addr >> 3) + wr_cnt) & 16'hFFFF][39:32] <= m_wdata[39:32];
                    if (m_wstrb[5]) ddr_mem[((cur_wr_addr >> 3) + wr_cnt) & 16'hFFFF][47:40] <= m_wdata[47:40];
                    if (m_wstrb[6]) ddr_mem[((cur_wr_addr >> 3) + wr_cnt) & 16'hFFFF][55:48] <= m_wdata[55:48];
                    if (m_wstrb[7]) ddr_mem[((cur_wr_addr >> 3) + wr_cnt) & 16'hFFFF][63:56] <= m_wdata[63:56];

                    if (wr_cnt == cur_wr_len) begin
                        m_wready <= 1'b0;
                        m_bvalid <= 1'b1;
                    end else begin
                        wr_cnt   <= wr_cnt + 8'd1;
                    end
                end
            end else if (m_awvalid && m_awready) begin
                `EXPECT_EQ(m_awlen, 8'd7, "l2_cache_ctrl: awlen must be 7 (8 beats)")
                `EXPECT_EQ(m_awsize, 3'd3, "l2_cache_ctrl: awsize must be 3 (8 bytes)")
                `EXPECT_EQ(m_awburst, 2'b01, "l2_cache_ctrl: awburst must be INCR (01)")
                `EXPECT_EQ(m_awaddr[5:0], 6'b000000, "l2_cache_ctrl: awaddr must be 64B aligned")

                cur_wr_addr       <= m_awaddr;
                cur_wr_len        <= m_awlen;
                wr_cnt            <= 8'h0;
                burst_write_count <= burst_write_count + 1;
                m_awready         <= 1'b0;
                m_wready          <= 1'b1;
                wr_active         <= 1'b1;
            end
        end
    end

    // ------------------------------------------------------------
    // CPU Master Verification Tasks
    // ------------------------------------------------------------
    task cpu_read;
        input  [39:0] addr;
        input  [3:0]  id;
        output [63:0] data;
        integer to;
        begin
            @(posedge clk);
            s_arvalid <= 1'b1;
            s_araddr  <= addr;
            s_arid    <= id;
            s_rready  <= 1'b1;
            to = 0;
            while (!(s_arvalid && s_arready) && to < 1000) begin
                @(posedge clk);
                to = to + 1;
            end
            s_arvalid <= 1'b0;
            to = 0;
            while (!(s_rvalid && s_rready) && to < 2000) begin
                @(posedge clk);
                to = to + 1;
                if (s_rvalid) data = s_rdata;
            end
            `EXPECT_TRUE(to < 2000, "tb_l2_cache_ctrl: read timeout")
            s_rready <= 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task cpu_write;
        input [39:0] addr;
        input [3:0]  id;
        input [63:0] data;
        input [7:0]  strb;
        integer to;
        reg aw_done, w_done;
        begin
            @(posedge clk);
            s_awvalid <= 1'b1;
            s_awaddr  <= addr;
            s_awid    <= id;
            s_wvalid  <= 1'b1;
            s_wdata   <= data;
            s_wstrb   <= strb;
            s_bready  <= 1'b1;
            aw_done = 1'b0;
            w_done  = 1'b0;
            to = 0;
            while ((!aw_done || !w_done) && to < 1000) begin
                @(posedge clk);
                to = to + 1;
                if (s_awvalid && s_awready) begin
                    aw_done = 1'b1;
                    s_awvalid <= 1'b0;
                end
                if (s_wvalid && s_wready) begin
                    w_done = 1'b1;
                    s_wvalid <= 1'b0;
                end
            end
            to = 0;
            while (!(s_bvalid && s_bready) && to < 3000) begin
                @(posedge clk);
                to = to + 1;
            end
            `EXPECT_TRUE(to < 3000, "tb_l2_cache_ctrl: write timeout")
            s_bready <= 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // Test Vectors
    // ------------------------------------------------------------
    reg [63:0] rd_val;
    integer snap_rbursts, snap_wbursts;
    integer way_i;
    reg [39:0] test_addr;

    initial begin
        $dumpfile("tb_l2_cache_ctrl.vcd");
        $dumpvars(0, tb_l2_cache_ctrl);

        s_arvalid         = 0;
        s_araddr          = 0;
        s_arid            = 0;
        s_rready          = 0;
        s_awvalid         = 0;
        s_awaddr          = 0;
        s_awid            = 0;
        s_wvalid          = 0;
        s_wdata           = 0;
        s_wstrb           = 0;
        s_bready          = 0;
        sf_intervene_mode = 0;
        sf_intervene_addr = 0;
        sf_intervene_line = 0;

        @(posedge rst_n);
        repeat (10) @(posedge clk);

        $display("\n==================================================================");
        $display("  TITAN X — L2 CACHE CONTROLLER UNIT QUALIFICATION");
        $display("==================================================================");

        // --------------------------------------------------------
        // SCENARIO 1: Cold Read Miss -> 8-Beat AXI4 Burst Refill
        // --------------------------------------------------------
        $display("\n--- SCENARIO 1: Cold Read Miss Native 8-Beat Refill ---");
        snap_rbursts = burst_read_count;
        cpu_read(40'h8000_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8000_0000 >> 3) & 16'hFFFF], "Scenario 1: read data matches DDR memory")
        `EXPECT_EQ(burst_read_count - snap_rbursts, 1, "Scenario 1: exactly 1 AXI4 burst emitted")
        `EXPECT_EQ(read_beat_count, 8, "Scenario 1: exactly 8 data beats received")

        // --------------------------------------------------------
        // SCENARIO 2: Read Hit -> 0 Burst Reads
        // --------------------------------------------------------
        $display("\n--- SCENARIO 2: Read Hit ---");
        snap_rbursts = burst_read_count;
        cpu_read(40'h8000_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8000_0000 >> 3) & 16'hFFFF], "Scenario 2: hit word 0 matches")
        cpu_read(40'h8000_0028, 4'h0, rd_val); // offset 5 (0x28)
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8000_0028 >> 3) & 16'hFFFF], "Scenario 2: hit word 5 matches")
        `EXPECT_EQ(burst_read_count - snap_rbursts, 0, "Scenario 2: 0 memory bursts on hit")

        // --------------------------------------------------------
        // SCENARIO 3: Write Hit -> Update In-Place, Mark Dirty
        // --------------------------------------------------------
        $display("\n--- SCENARIO 3: Write Hit ---");
        snap_wbursts = burst_write_count;
        cpu_write(40'h8000_0000, 4'h0, 64'hCAFE_BABE_0123_4567, 8'hFF);
        `EXPECT_EQ(burst_write_count - snap_wbursts, 0, "Scenario 3: 0 memory writes on hit")
        cpu_read(40'h8000_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, 64'hCAFE_BABE_0123_4567, "Scenario 3: readback of modified word")

        // --------------------------------------------------------
        // SCENARIO 4: 16-Way Set Associativity (Set 8)
        // --------------------------------------------------------
        $display("\n--- SCENARIO 4: 16-Way Set Associativity (Set 8) ---");
        // Set 8 offset: 8 * 64 = 0x200
        for (way_i = 0; way_i < 16; way_i = way_i + 1) begin
            test_addr = 40'h8002_0200 + (way_i * 40'h1000);
            cpu_write(test_addr, 4'h0, {32'hDEAD_0000 | way_i, 32'hBEEF_0000 | way_i}, 8'hFF);
        end

        // Read back all 16 lines from Set 8. All 16 MUST hit in cache!
        snap_rbursts = burst_read_count;
        for (way_i = 0; way_i < 16; way_i = way_i + 1) begin
            test_addr = 40'h8002_0200 + (way_i * 40'h1000);
            cpu_read(test_addr, 4'h0, rd_val);
            `EXPECT_EQ(rd_val, {32'hDEAD_0000 | way_i, 32'hBEEF_0000 | way_i}, "Scenario 4: 16-way concurrent line retention")
        end
        `EXPECT_EQ(burst_read_count - snap_rbursts, 0, "Scenario 4: 0 memory bursts during 16-way readback")

        // --------------------------------------------------------
        // SCENARIO 5: 17th Way Eviction Writeback
        // --------------------------------------------------------
        $display("\n--- SCENARIO 5: 17th Line Conflict & Dirty Burst Writeback ---");
        test_addr = 40'h8002_0200 + (16 * 40'h1000);
        snap_wbursts = burst_write_count;
        snap_rbursts = burst_read_count;
        cpu_write(test_addr, 4'h0, 64'h8888_9999_AAAA_BBBB, 8'hFF);
        `EXPECT_EQ(burst_write_count - snap_wbursts, 1, "Scenario 5: exactly 1 burst writeback to memory")
        `EXPECT_EQ(burst_read_count - snap_rbursts, 1, "Scenario 5: exactly 1 burst refill for line 17")
        cpu_read(test_addr, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, 64'h8888_9999_AAAA_BBBB, "Scenario 5: readback of line 17 data")

        // --------------------------------------------------------
        // SCENARIO 6: MESI Dirty-Owner Intervention
        // --------------------------------------------------------
        $display("\n--- SCENARIO 6: MESI Dirty-Owner Intervention ---");
        sf_intervene_mode = 1'b1;
        sf_intervene_addr = 40'h8005_0000;
        sf_intervene_line = {8{64'hFACE_B00C_1234_5678}};

        snap_rbursts = burst_read_count;
        cpu_read(40'h8005_0000, 4'h1, rd_val);
        `EXPECT_EQ(rd_val, 64'hFACE_B00C_1234_5678, "Scenario 6: Core 1 received dirty snoop line")
        `EXPECT_EQ(burst_read_count - snap_rbursts, 0, "Scenario 6: 0 memory reads during dirty intervention")

        // --------------------------------------------------------
        // SCENARIO 7: Write-Allocate Refill Merge
        // --------------------------------------------------------
        $display("\n--- SCENARIO 7: Write-Allocate Refill Merge ---");
        sf_intervene_mode = 1'b0;
        // Write to word 2 (offset 0x10) of cold line 0x8006_0000
        cpu_write(40'h8006_0010, 4'h0, 64'h1234_5678_9ABC_DEF0, 8'hFF);
        // Read back word 2 -> must be written value
        cpu_read(40'h8006_0010, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, 64'h1234_5678_9ABC_DEF0, "Scenario 7: word 2 has merged store data")
        // Read back word 0 -> must be preserved DDR backing memory value
        cpu_read(40'h8006_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8006_0000 >> 3) & 16'hFFFF], "Scenario 7: word 0 has original refilled data")

        // --------------------------------------------------------
        // SCENARIO 8: Reset & Idle Recovery
        // --------------------------------------------------------
        $display("\n--- SCENARIO 8: Reset & Clean Recovery ---");
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);
        `EXPECT_TRUE(s_arready === 1'b1, "Scenario 8: s_arready ready after reset")
        `EXPECT_TRUE(s_awready === 1'b1, "Scenario 8: s_awready ready after reset")
        `EXPECT_TRUE(s_wready  === 1'b1, "Scenario 8: s_wready ready after reset")

        // Read post-reset
        cpu_read(40'h8007_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8007_0000 >> 3) & 16'hFFFF], "Scenario 8: functional read after reset")

        // --------------------------------------------------------
        // Sign-off Report
        // --------------------------------------------------------
        `TB_REPORT("tb_l2_cache_ctrl")
    end

endmodule
