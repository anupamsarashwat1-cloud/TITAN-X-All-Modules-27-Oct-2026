// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — L2 Cache Top Full Subsystem Qualification
// Module: tb_l2_cache_top
//
// Verification Coverage:
//   1. Cold Read Miss: 8-beat AXI4 INCR burst refill decomposed into 8 single-beat DDR reads.
//   2. Read Hit: Zero downstream memory requests, instant data delivery.
//   3. Write Hit: Cache line update in-place, line marked dirty, zero DDR writes.
//   4. 16-Way Set Associativity: 16 distinct lines targeting the same set (Set 5)
//      coexist without thrashing; subsequent readback of all 16 lines produces 0 DDR accesses.
//   5. 17th Way Conflict & Eviction: Forces eviction of dirty line; verifies 8 single-beat
//      writeback beats (full 64-byte line) to DDR, followed by 8-beat refill.
//   6. MESI Dirty-Owner Intervention: Core 1 reads address owned in ST_M by Core 0;
//      L2 snoop filter asserts snoop to Core 0; Core 0 returns dirty data;
//      L2 intercepts and supplies data to Core 1 with 0 DDR read accesses.
//   7. Reset & Clean Idle Recovery: Verification of clean controller recovery upon reset.

`timescale 1ns/1ps

`include "tb_macros.vh"

module tb_l2_cache_top;

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

    // Memory-side AXI4 single-beat (via axi4_burst_to_lite shim)
    wire        m_arvalid;
    reg         m_arready;
    wire [39:0] m_araddr;
    reg         m_rvalid;
    wire        m_rready;
    reg  [63:0] m_rdata;
    reg  [1:0]  m_rresp;

    wire        m_awvalid;
    reg         m_awready;
    wire [39:0] m_awaddr;
    wire        m_wvalid;
    reg         m_wready;
    wire [63:0] m_wdata;
    wire [7:0]  m_wstrb;
    reg         m_bvalid;
    wire        m_bready;

    // L1 Snoop interfaces (4 cores)
    wire [3:0]   snoop_valid;
    wire [39:0]  snoop_addr;
    wire [1:0]   snoop_type;
    reg  [3:0]   snoop_ack;
    reg  [3:0]   snoop_data_valid;
    wire [511:0] snoop_data;

    // Bus instrumentation
    integer mem_read_beats;
    integer mem_write_beats;

    // ------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------
    l2_cache_top #(
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
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .m_rdata(m_rdata),
        .m_rresp(m_rresp),

        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_awaddr(m_awaddr),
        .m_wvalid(m_wvalid),
        .m_wready(m_wready),
        .m_wdata(m_wdata),
        .m_wstrb(m_wstrb),
        .m_bvalid(m_bvalid),
        .m_bready(m_bready),

        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_type(snoop_type),
        .snoop_ack(snoop_ack),
        .snoop_data_valid(snoop_data_valid),
        .snoop_data(snoop_data)
    );

    // ------------------------------------------------------------
    // Downstream Memory Responder (DDR Backing Model)
    // ------------------------------------------------------------
    reg [63:0] ddr_mem [0:65535];
    integer init_i;
    initial begin
        for (init_i = 0; init_i < 65536; init_i = init_i + 1) begin
            ddr_mem[init_i] = {32'hDD10_0000 | init_i[15:0], 32'hBA5E_0000 | init_i[15:0]};
        end
    end

    reg [39:0] cur_wr_addr;
    reg        wr_addr_seen, wr_data_seen;
    reg [63:0] cur_wr_data;
    reg [7:0]  cur_wr_strb;

    wire [15:0] eff_wr_idx = (m_awvalid && m_awready) ? m_awaddr[18:3] : cur_wr_addr[18:3];
    wire [63:0] eff_wr_dat = (m_wvalid && m_wready)   ? m_wdata : cur_wr_data;
    wire [7:0]  eff_wr_str = (m_wvalid && m_wready)   ? m_wstrb : cur_wr_strb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_arready       <= 1'b1;
            m_rvalid        <= 1'b0;
            m_rdata         <= 64'h0;
            m_rresp         <= 2'b00;
            m_awready       <= 1'b1;
            m_wready        <= 1'b1;
            m_bvalid        <= 1'b0;
            wr_addr_seen    <= 1'b0;
            wr_data_seen    <= 1'b0;
            mem_read_beats  <= 0;
            mem_write_beats <= 0;
        end else begin
            // Read channel:
            if (m_rvalid && m_rready) begin
                m_rvalid  <= 1'b0;
                m_arready <= 1'b1;
            end else if (m_arvalid && m_arready) begin
                m_arready <= 1'b0;
                m_rvalid  <= 1'b1;
                m_rdata   <= ddr_mem[m_araddr[18:3]];
                m_rresp   <= 2'b00;
                mem_read_beats <= mem_read_beats + 1;
            end

            // Write channel:
            if (m_bvalid && m_bready) begin
                m_bvalid     <= 1'b0;
                m_awready    <= 1'b1;
                m_wready     <= 1'b1;
                wr_addr_seen <= 1'b0;
                wr_data_seen <= 1'b0;
            end else begin
                if (m_awvalid && m_awready) begin
                    cur_wr_addr  <= m_awaddr;
                    wr_addr_seen <= 1'b1;
                    m_awready    <= 1'b0;
                end
                if (m_wvalid && m_wready) begin
                    cur_wr_data  <= m_wdata;
                    cur_wr_strb  <= m_wstrb;
                    wr_data_seen <= 1'b1;
                    m_wready     <= 1'b0;
                end
                if ((wr_addr_seen || (m_awvalid && m_awready)) &&
                    (wr_data_seen || (m_wvalid && m_wready)) && !m_bvalid) begin
                    if (eff_wr_str[0]) ddr_mem[eff_wr_idx][7:0]   <= eff_wr_dat[7:0];
                    if (eff_wr_str[1]) ddr_mem[eff_wr_idx][15:8]  <= eff_wr_dat[15:8];
                    if (eff_wr_str[2]) ddr_mem[eff_wr_idx][23:16] <= eff_wr_dat[23:16];
                    if (eff_wr_str[3]) ddr_mem[eff_wr_idx][31:24] <= eff_wr_dat[31:24];
                    if (eff_wr_str[4]) ddr_mem[eff_wr_idx][39:32] <= eff_wr_dat[39:32];
                    if (eff_wr_str[5]) ddr_mem[eff_wr_idx][47:40] <= eff_wr_dat[47:40];
                    if (eff_wr_str[6]) ddr_mem[eff_wr_idx][55:48] <= eff_wr_dat[55:48];
                    if (eff_wr_str[7]) ddr_mem[eff_wr_idx][63:56] <= eff_wr_dat[63:56];
                    m_bvalid <= 1'b1;
                    mem_write_beats <= mem_write_beats + 1;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // MESI Snoop Emulation for Core 0 & Core 1
    // ------------------------------------------------------------
    reg [511:0] core0_dirty_line;
    reg         core0_line_dirty;
    reg         core0_line_valid;
    reg [39:0]  core0_line_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snoop_ack        <= 4'b0;
            snoop_data_valid <= 4'b0;
        end else begin
            snoop_ack        <= 4'b0;
            snoop_data_valid <= 4'b0;
            if (snoop_valid[0]) begin
                snoop_ack[0] <= 1'b1;
                if (core0_line_valid && (snoop_addr[39:6] == core0_line_addr[39:6])) begin
                    if (core0_line_dirty) begin
                        snoop_data_valid[0] <= 1'b1;
                    end
                end
            end
            if (snoop_valid[1]) snoop_ack[1] <= 1'b1;
            if (snoop_valid[2]) snoop_ack[2] <= 1'b1;
            if (snoop_valid[3]) snoop_ack[3] <= 1'b1;
        end
    end

    assign snoop_data = snoop_data_valid[0] ? core0_dirty_line : 512'h0;

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
            `EXPECT_TRUE(to < 2000, "cpu_read timeout waiting for s_rvalid")
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
            `EXPECT_TRUE(to < 3000, "cpu_write timeout waiting for s_bvalid")
            s_bready <= 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // Test Vectors
    // ------------------------------------------------------------
    reg [63:0] rd_val;
    integer snap_rbeats, snap_wbeats;
    integer way_idx;
    reg [39:0] test_addr;

    initial begin
        $dumpfile("tb_l2_cache_top.vcd");
        $dumpvars(0, tb_l2_cache_top);

        s_arvalid = 0;
        s_araddr  = 0;
        s_arid    = 0;
        s_rready  = 0;
        s_awvalid = 0;
        s_awaddr  = 0;
        s_awid    = 0;
        s_wvalid  = 0;
        s_wdata   = 0;
        s_wstrb   = 0;
        s_bready  = 0;

        core0_line_valid = 0;
        core0_line_dirty = 0;
        core0_line_addr  = 0;
        core0_dirty_line = 0;

        // Wait for reset deassertion
        @(posedge rst_n);
        repeat (10) @(posedge clk);

        $display("\n==================================================================");
        $display("  TITAN X — L2 CACHE TOP TRUTHFUL ENGINEERING QUALIFICATION");
        $display("==================================================================");

        // --------------------------------------------------------
        // SCENARIO 1: Cold Read Miss -> 8-Beat AXI4 Refill Burst
        // --------------------------------------------------------
        $display("\n--- SCENARIO 1: Cold Read Miss & 8-Beat Refill ---");
        snap_rbeats = mem_read_beats;
        cpu_read(40'h8000_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8000_0000 >> 3) & 16'hFFFF], "Scenario 1: read data matches DDR memory")
        `EXPECT_EQ(mem_read_beats - snap_rbeats, 8, "Scenario 1: exactly 8 read beats fetched on miss")

        // --------------------------------------------------------
        // SCENARIO 2: Read Hit -> 0 DDR Accesses
        // --------------------------------------------------------
        $display("\n--- SCENARIO 2: Read Hit (Cache Hit) ---");
        snap_rbeats = mem_read_beats;
        // Same line, word 0
        cpu_read(40'h8000_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8000_0000 >> 3) & 16'hFFFF], "Scenario 2: read word 0 matches")
        // Same line, word 3 (offset 0x18)
        cpu_read(40'h8000_0018, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8000_0018 >> 3) & 16'hFFFF], "Scenario 2: read word 3 matches")
        `EXPECT_EQ(mem_read_beats - snap_rbeats, 0, "Scenario 2: 0 DDR read beats on cache hit")

        // --------------------------------------------------------
        // SCENARIO 3: Write Hit -> Update In-Place, Mark Dirty
        // --------------------------------------------------------
        $display("\n--- SCENARIO 3: Write Hit & Dirty State ---");
        snap_wbeats = mem_write_beats;
        cpu_write(40'h8000_0000, 4'h0, 64'hFEED_FACE_CAFE_BABE, 8'hFF);
        `EXPECT_EQ(mem_write_beats - snap_wbeats, 0, "Scenario 3: 0 DDR write beats on write hit")
        cpu_read(40'h8000_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, 64'hFEED_FACE_CAFE_BABE, "Scenario 3: readback of modified data")

        // --------------------------------------------------------
        // SCENARIO 4: 16-Way Set Associativity Verification
        // --------------------------------------------------------
        $display("\n--- SCENARIO 4: 16-Way Set Associativity (Set 5) ---");
        // Target Set 5: set_idx = 6'd5 (offset within 4KB set stride = 5 * 64 = 0x140)
        // Stride = 64 sets * 64 bytes = 4096 bytes (0x1000)
        // Install 16 distinct lines in Set 5
        for (way_idx = 0; way_idx < 16; way_idx = way_idx + 1) begin
            test_addr = 40'h8001_0140 + (way_idx * 40'h1000);
            cpu_write(test_addr, 4'h0, {32'hA000_0000 | way_idx, 32'h5000_0000 | way_idx}, 8'hFF);
        end

        // Read back all 16 lines from Set 5. All 16 MUST hit in cache!
        snap_rbeats = mem_read_beats;
        for (way_idx = 0; way_idx < 16; way_idx = way_idx + 1) begin
            test_addr = 40'h8001_0140 + (way_idx * 40'h1000);
            cpu_read(test_addr, 4'h0, rd_val);
            `EXPECT_EQ(rd_val, {32'hA000_0000 | way_idx, 32'h5000_0000 | way_idx}, "Scenario 4: 16-way concurrent line retention")
        end
        `EXPECT_EQ(mem_read_beats - snap_rbeats, 0, "Scenario 4: all 16 ways hit without DDR reads")

        // --------------------------------------------------------
        // SCENARIO 5: 17th Way Conflict & Eviction Writeback
        // --------------------------------------------------------
        $display("\n--- SCENARIO 5: 17th Line Conflict & Dirty Eviction Writeback ---");
        // Access 17th line in Set 5
        test_addr = 40'h8001_0140 + (16 * 40'h1000);
        snap_wbeats = mem_write_beats;
        snap_rbeats = mem_read_beats;
        cpu_write(test_addr, 4'h0, 64'h7777_8888_9999_AAAA, 8'hFF);
        `EXPECT_EQ(mem_write_beats - snap_wbeats, 8, "Scenario 5: exactly 8 writeback beats to DDR on eviction")
        `EXPECT_EQ(mem_read_beats - snap_rbeats, 8, "Scenario 5: exactly 8 refill beats for new line")
        cpu_read(test_addr, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, 64'h7777_8888_9999_AAAA, "Scenario 5: readback of 17th line data")

        // --------------------------------------------------------
        // SCENARIO 6: MESI Dirty-Owner Intervention
        // --------------------------------------------------------
        $display("\n--- SCENARIO 6: MESI Dirty-Owner Intervention via Snoop Interface ---");
        // Core 0 writes 40'h8003_0000 to place it into ST_M in snoop filter directory
        cpu_write(40'h8003_0000, 4'h0, 64'h1122_3344_5566_7788, 8'hFF);
        // Emulate Core 0 holding dirtier updated data in its L1 cache
        core0_line_valid = 1'b1;
        core0_line_dirty = 1'b1;
        core0_line_addr  = 40'h8003_0000;
        core0_dirty_line = {8{64'hCCCC_0000_DDDD_0000}};

        // Core 1 initiates read to 40'h8003_0000 (s_arid = 4'h1)
        snap_rbeats = mem_read_beats;
        cpu_read(40'h8003_0000, 4'h1, rd_val);
        `EXPECT_EQ(rd_val, 64'hCCCC_0000_DDDD_0000, "Scenario 6: Core 1 received dirty line from Core 0")
        `EXPECT_EQ(mem_read_beats - snap_rbeats, 0, "Scenario 6: 0 DDR reads during dirty intervention")

        // --------------------------------------------------------
        // SCENARIO 7: Reset & Clean Recovery
        // --------------------------------------------------------
        $display("\n--- SCENARIO 7: Reset & Clean Recovery ---");
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);
        `EXPECT_TRUE(s_arready === 1'b1, "Scenario 7: s_arready ready after reset")
        `EXPECT_TRUE(s_awready === 1'b1, "Scenario 7: s_awready ready after reset")
        `EXPECT_TRUE(s_wready  === 1'b1, "Scenario 7: s_wready ready after reset")

        // Verify read operation works post-reset
        cpu_read(40'h8004_0000, 4'h0, rd_val);
        `EXPECT_EQ(rd_val, ddr_mem[(40'h8004_0000 >> 3) & 16'hFFFF], "Scenario 7: functional read after reset")

        // --------------------------------------------------------
        // Sign-off Report
        // --------------------------------------------------------
        `TB_REPORT("tb_l2_cache_top")
    end

endmodule
