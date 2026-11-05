`timescale 1ns / 1ps

module tb_ddr_ctrl_top();

    logic clk;
    logic rst_n;
    logic s_awvalid;
    logic s_awready;
    logic s_awaddr;
    logic s_awid;
    logic s_awlen;
    logic s_awsize;
    logic s_wvalid;
    logic s_wready;
    logic s_wdata;
    logic s_wstrb;
    logic s_wlast;
    logic s_bvalid;
    logic s_bready;
    logic s_bresp;
    logic s_bid;
    logic s_arvalid;
    logic s_arready;
    logic s_araddr;
    logic s_arid;
    logic s_arlen;
    logic s_rvalid;
    logic s_rready;
    logic s_rdata;
    logic s_rresp;
    logic s_rlast;
    logic s_rid;
    logic ddr_ck_p;
    logic ddr_ck_n;
    logic ddr_cke;
    logic ddr_cs_n;
    logic ddr_ras_n;
    logic ddr_cas_n;
    logic ddr_we_n;
    logic ddr_ba;
    logic ddr_bg;
    logic ddr_addr;
    logic ddr_dm;
    logic ddr_dq;
    logic ddr_dqs_p;
    logic ddr_dqs_n;

    // DUT Instantiation
    ddr_ctrl_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_awvalid(s_awvalid),
        .s_awready(s_awready),
        .s_awaddr(s_awaddr),
        .s_awid(s_awid),
        .s_awlen(s_awlen),
        .s_awsize(s_awsize),
        .s_wvalid(s_wvalid),
        .s_wready(s_wready),
        .s_wdata(s_wdata),
        .s_wstrb(s_wstrb),
        .s_wlast(s_wlast),
        .s_bvalid(s_bvalid),
        .s_bready(s_bready),
        .s_bresp(s_bresp),
        .s_bid(s_bid),
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_araddr(s_araddr),
        .s_arid(s_arid),
        .s_arlen(s_arlen),
        .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .s_rlast(s_rlast),
        .s_rid(s_rid),
        .ddr_ck_p(ddr_ck_p),
        .ddr_ck_n(ddr_ck_n),
        .ddr_cke(ddr_cke),
        .ddr_cs_n(ddr_cs_n),
        .ddr_ras_n(ddr_ras_n),
        .ddr_cas_n(ddr_cas_n),
        .ddr_we_n(ddr_we_n),
        .ddr_ba(ddr_ba),
        .ddr_bg(ddr_bg),
        .ddr_addr(ddr_addr),
        .ddr_dm(ddr_dm),
        .ddr_dq(ddr_dq),
        .ddr_dqs_p(ddr_dqs_p),
        .ddr_dqs_n(ddr_dqs_n)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_ddr_ctrl_top.vcd");
        $dumpvars(0, tb_ddr_ctrl_top);

        // 1. Initialize all data inputs
        s_awvalid = 0;
        s_awaddr = 0;
        s_awid = 0;
        s_awlen = 0;
        s_awsize = 0;
        s_wvalid = 0;
        s_wdata = 0;
        s_wstrb = 0;
        s_wlast = 0;
        s_bready = 0;
        s_arvalid = 0;
        s_araddr = 0;
        s_arid = 0;
        s_arlen = 0;
        s_rready = 0;

        // 2. Assert Resets
        #10;
        rst_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        rst_n = 1;
        #20;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
            s_awvalid = $random;
            s_awaddr = $random;
            s_awid = $random;
            s_awlen = $random;
            s_awsize = $random;
            s_wvalid = $random;
            s_wdata = $random;
            s_wstrb = $random;
            s_wlast = $random;
            s_bready = $random;
            s_arvalid = $random;
            s_araddr = $random;
            s_arid = $random;
            s_arlen = $random;
            s_rready = $random;
        end

        #1000;
        $finish;
    end

endmodule
