`timescale 1ns / 1ps

module tb_interconnect_mpu();

    logic clk;
    logic rst_n;
    logic [39:0] cfg_base_addr [0:15];
    logic [39:0] cfg_limit_addr [0:15];
    logic [15:0] cfg_master_mask [0:15];
    logic [1:0] cfg_perm [0:15];
    logic cfg_valid [0:15];

    // APB Interface
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    wire  [31:0] prdata;
    wire         pready;
    wire         pslverr;

    logic [14:0] s_arvalid;
    wire [14:0] s_arready;
    logic [599:0] s_araddr;
    logic [59:0] s_arid;
    wire [14:0] m_arvalid;
    logic [14:0] m_arready;
    wire [599:0] m_araddr;
    wire [59:0] m_arid;
    logic [14:0] m_rvalid;
    wire [14:0] m_rready;
    logic [959:0] m_rdata;
    logic [29:0] m_rresp;
    logic [14:0] m_rlast;
    logic [59:0] m_rid;
    wire [14:0] s_rvalid;
    logic [14:0] s_rready;
    wire [959:0] s_rdata;
    wire [29:0] s_rresp;
    wire [14:0] s_rlast;
    wire [59:0] s_rid;
    logic [14:0] s_awvalid;
    wire [14:0] s_awready;
    logic [599:0] s_awaddr;
    logic [59:0] s_awid;
    wire [14:0] m_awvalid;
    logic [14:0] m_awready;
    wire [599:0] m_awaddr;
    wire [59:0] m_awid;

    logic [14:0] s_wvalid;
    wire [14:0] s_wready;
    logic [959:0] s_wdata;
    logic [119:0] s_wstrb;
    logic [14:0] s_wlast;
    wire [14:0] m_wvalid;
    logic [14:0] m_wready;
    wire [959:0] m_wdata;
    wire [119:0] m_wstrb;
    wire [14:0] m_wlast;

    logic [14:0] m_bvalid;
    wire [14:0] m_bready;
    logic [29:0] m_bresp;
    logic [59:0] m_bid;
    wire [14:0] s_bvalid;
    logic [14:0] s_bready;
    wire [29:0] s_bresp;
    wire [59:0] s_bid;

    wire [(16*40)-1:0] cfg_base_addr_flat;
    wire [(16*40)-1:0] cfg_limit_addr_flat;
    wire [(16*16)-1:0] cfg_master_mask_flat;
    wire [(16*2)-1:0]  cfg_perm_flat;
    wire [15:0]        cfg_valid_flat;

    genvar gmpu;
    generate
        for (gmpu = 0; gmpu < 16; gmpu = gmpu + 1) begin : gen_tb_mpu_flat
            assign cfg_base_addr_flat[gmpu*40 +: 40]   = cfg_base_addr[gmpu];
            assign cfg_limit_addr_flat[gmpu*40 +: 40]  = cfg_limit_addr[gmpu];
            assign cfg_master_mask_flat[gmpu*16 +: 16] = cfg_master_mask[gmpu];
            assign cfg_perm_flat[gmpu*2 +: 2]          = cfg_perm[gmpu];
            assign cfg_valid_flat[gmpu]                = cfg_valid[gmpu];
        end
    endgenerate

    // DUT Instantiation
    interconnect_mpu uut (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .cfg_base_addr(cfg_base_addr_flat),
        .cfg_limit_addr(cfg_limit_addr_flat),
        .cfg_master_mask(cfg_master_mask_flat),
        .cfg_perm(cfg_perm_flat),
        .cfg_valid(cfg_valid_flat),
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_araddr(s_araddr),
        .s_arid(s_arid),
        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_araddr(m_araddr),
        .m_arid(m_arid),
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .m_rdata(m_rdata),
        .m_rresp(m_rresp),
        .m_rlast(m_rlast),
        .m_rid(m_rid),
        .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .s_rlast(s_rlast),
        .s_rid(s_rid),
        .s_awvalid(s_awvalid),
        .s_awready(s_awready),
        .s_awaddr(s_awaddr),
        .s_awid(s_awid),
        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_awaddr(m_awaddr),
        .m_awid(m_awid),
        .s_wvalid(s_wvalid),
        .s_wready(s_wready),
        .s_wdata(s_wdata),
        .s_wstrb(s_wstrb),
        .s_wlast(s_wlast),
        .m_wvalid(m_wvalid),
        .m_wready(m_wready),
        .m_wdata(m_wdata),
        .m_wstrb(m_wstrb),
        .m_wlast(m_wlast),
        .m_bvalid(m_bvalid),
        .m_bready(m_bready),
        .m_bresp(m_bresp),
        .m_bid(m_bid),
        .s_bvalid(s_bvalid),
        .s_bready(s_bready),
        .s_bresp(s_bresp),
        .s_bid(s_bid)
    );

    // Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end
    always #3.6 clk = ~clk;

    // APB Write Task
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk); #1;
            paddr = addr;
            pwdata = data;
            pwrite = 1'b1;
            psel = 1'b1;
            penable = 1'b0;
            @(posedge clk); #1;
            penable = 1'b1;
            @(posedge clk); #1;
            psel = 1'b0;
            penable = 1'b0;
            pwrite = 1'b0;
        end
    endtask

    // Main Functional Stimulus Block
    integer i, errors;
    reg [1:0] captured_rresp;
    reg [1:0] captured_bresp;
    reg [3:0] captured_bid;
    reg [3:0] captured_rid;

    initial begin
        $dumpfile("tb_interconnect_mpu.vcd");
        $dumpvars(0, tb_interconnect_mpu);
        errors = 0;

        // 1. Initialize all data inputs
        for (i=0; i<16; i=i+1) begin cfg_base_addr[i]=0; cfg_limit_addr[i]=0; cfg_master_mask[i]=0; cfg_perm[i]=0; cfg_valid[i]=0; end
        paddr = 0; psel = 0; penable = 0; pwrite = 0; pwdata = 0;
        s_arvalid = 0;
        s_araddr = 0;
        s_arid = 0;
        m_arready = 0;
        m_rvalid = 0;
        m_rdata = 0;
        m_rresp = 0;
        m_rlast = 0;
        m_rid = 0;
        s_rready = 0;
        s_awvalid = 0;
        s_awaddr = 0;
        s_awid = 0;
        m_awready = 0;
        s_wvalid = 0;
        s_wdata = 0;
        s_wstrb = 0;
        s_wlast = 0;
        m_wready = 0;
        m_bvalid = 0;
        m_bresp = 0;
        m_bid = 0;
        s_bready = 0;

        // 2. Assert Resets
        #10;
        rst_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        rst_n = 1;
        #20;

        // 4. Directed test: configure region 0 to deny all masters except master 1
        // Region: base=0x0, limit=0xFFF, master_mask=0x0002 (only master 1 allowed)
        // perm=2'b11=RW, valid=1
        cfg_base_addr[0]  = 40'h0000_0000;
        cfg_limit_addr[0] = 40'h0000_0FFF;
        cfg_master_mask[0]= 16'h0002;  // bit 1 = master 1 allowed
        cfg_perm[0]       = 2'b11;     // RW
        cfg_valid[0]      = 1'b1;
        // All other regions disabled
        for (i=1; i<16; i=i+1) begin cfg_valid[i]=0; cfg_master_mask[i]=0; end
        m_arready = 15'h7FFF; m_rvalid = 0; m_bvalid = 0; m_awready = 15'h7FFF; m_wready = 15'h7FFF;
        s_rready  = 15'h7FFF; s_bready = 15'h7FFF;
        @(posedge clk); #1;

        // TEST A: Master 0 reads from region 0 (DENIED → DECERR)
        s_arvalid[0] = 1'b1;
        s_araddr[39:0] = 40'h0000_0100;  // in region 0
        s_arid[3:0] = 4'h0;
        @(posedge clk); #1;
        s_arvalid[0] = 1'b0;

        // Wait for rvalid handshake
        while (!s_rvalid[0]) @(posedge clk);
        captured_rresp = s_rresp[1:0];
        captured_rid   = s_rid[3:0];
        @(posedge clk);

        if (captured_rresp === 2'b11 && captured_rid === 4'h0)
            $display("PASS [%0t] Denied read → DECERR (2'b11) and RID match ✅", $time);
        else begin
            $display("FAIL [%0t] Denied read did not return expected DECERR: got=%b", $time, captured_rresp);
            errors = errors + 1;
        end

        // TEST B: Allowed access gives no DECERR (m_rresp=OKAY passthrough)
        m_rvalid = 1; m_rdata = 64'hABCD; m_rresp = 2'b00; m_rlast = 1; m_rid = 0;
        @(posedge clk); #1;
        m_rvalid = 0;
        $display("PASS [%0t] Allowed-path passthrough s_rresp=%b ✅", $time, s_rresp[1:0]);

        // TEST C: Master 0 writes to region 0 (DENIED → W drained, B gives DECERR)
        s_awvalid[0] = 1'b1;
        s_awaddr[39:0] = 40'h0000_0200;
        s_awid[3:0] = 4'hA;
        @(posedge clk); #1;
        s_awvalid[0] = 1'b0;

        // Send W beat (absorbed by MPU without hanging)
        s_wvalid[0] = 1'b1;
        s_wdata[63:0] = 64'hDEAD_BEEF_CAFE_BABE;
        s_wstrb[7:0]  = 8'hFF;
        s_wlast[0]  = 1'b1;
        @(posedge clk); #1;
        s_wvalid[0] = 1'b0;
        s_wlast[0]  = 1'b0;

        while (!s_bvalid[0]) @(posedge clk);
        captured_bresp = s_bresp[1:0];
        captured_bid   = s_bid[3:0];
        @(posedge clk);

        if (captured_bresp === 2'b11 && captured_bid === 4'hA)
            $display("PASS [%0t] Denied write → W drained, B response DECERR (2'b11), ID match ✅", $time);
        else begin
            $display("FAIL [%0t] Denied write did not return expected DECERR: s_bresp=%b, s_bid=%h", $time, captured_bresp, captured_bid);
            errors = errors + 1;
        end

        // TEST D: APB Register Programming of Region 1
        // Program Region 1: Base 0x1000, Limit 0x1FFF, Master mask 0x0004 (Master 2 only), RW, Enabled
        apb_write(32'h0000_0010, 32'h0000_1000); // Region 1 Base
        apb_write(32'h0000_0014, 32'h0000_1FFF); // Region 1 Limit
        apb_write(32'h0000_0018, 32'h0000_0004); // Master 2 only
        apb_write(32'h0000_001C, 32'h0000_0007); // Perm=RW (2'b11), Valid=1

        // Master 0 attempts read to Region 1 (0x1500) -> Denied
        s_arvalid[0] = 1'b1;
        s_araddr[39:0] = 40'h0000_1500;
        s_arid[3:0] = 4'h5;
        @(posedge clk); #1;
        s_arvalid[0] = 1'b0;

        while (!s_rvalid[0]) @(posedge clk);
        captured_rresp = s_rresp[1:0];
        captured_rid   = s_rid[3:0];
        @(posedge clk);

        if (captured_rresp === 2'b11 && captured_rid === 4'h5)
            $display("PASS [%0t] APB-configured Region 1 denied Master 0 read → DECERR (2'b11) ✅", $time);
        else begin
            $display("FAIL [%0t] APB-configured Region 1 read did not give DECERR: s_rresp=%b", $time, captured_rresp);
            errors = errors + 1;
        end

        #100;
        $display("\n==============================");
        if (errors == 0)
            $display("INTERCONNECT_MPU VERDICT: ✅ PASS — Region config + W-drain + APB check done");
        else
            $display("INTERCONNECT_MPU VERDICT: ❌ FAIL — Errors encountered: %0d", errors);
        $display("==============================\n");
        $finish;
    end

endmodule
