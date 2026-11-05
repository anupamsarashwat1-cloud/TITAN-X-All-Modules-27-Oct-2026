`timescale 1ns / 1ps

module tb_axi4_crossbar();

    logic clk;
    logic rst_n;
    logic m_awvalid;
    logic m_awready;
    logic m_awaddr;
    logic m_awid;
    logic m_wvalid;
    logic m_wready;
    logic m_wdata;
    logic m_wstrb;
    logic m_wlast;
    logic m_bvalid;
    logic m_bready;
    logic m_bresp;
    logic m_bid;
    logic m_arvalid;
    logic m_arready;
    logic m_araddr;
    logic m_arid;
    logic m_rvalid;
    logic m_rready;
    logic m_rdata;
    logic m_rresp;
    logic m_rlast;
    logic m_rid;
    logic s_awvalid;
    logic s_awready;
    logic s_awaddr;
    logic s_awid;
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
    logic s_rvalid;
    logic s_rready;
    logic s_rdata;
    logic s_rresp;
    logic s_rlast;
    logic s_rid;

    // DUT Instantiation
    axi4_crossbar uut (
        .clk(clk),
        .rst_n(rst_n),
        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_awaddr(m_awaddr),
        .m_awid(m_awid),
        .m_wvalid(m_wvalid),
        .m_wready(m_wready),
        .m_wdata(m_wdata),
        .m_wstrb(m_wstrb),
        .m_wlast(m_wlast),
        .m_bvalid(m_bvalid),
        .m_bready(m_bready),
        .m_bresp(m_bresp),
        .m_bid(m_bid),
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
        .s_awvalid(s_awvalid),
        .s_awready(s_awready),
        .s_awaddr(s_awaddr),
        .s_awid(s_awid),
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
        .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .s_rlast(s_rlast),
        .s_rid(s_rid)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_axi4_crossbar.vcd");
        $dumpvars(0, tb_axi4_crossbar);

        // 1. Initialize all data inputs
        m_awvalid = 0;
        m_awaddr = 0;
        m_awid = 0;
        m_wvalid = 0;
        m_wdata = 0;
        m_wstrb = 0;
        m_wlast = 0;
        m_bready = 0;
        m_arvalid = 0;
        m_araddr = 0;
        m_arid = 0;
        m_rready = 0;
        s_awready = 0;
        s_wready = 0;
        s_bvalid = 0;
        s_bresp = 0;
        s_bid = 0;
        s_arready = 0;
        s_rvalid = 0;
        s_rdata = 0;
        s_rresp = 0;
        s_rlast = 0;
        s_rid = 0;

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
            m_awvalid = $random;
            m_awaddr = $random;
            m_awid = $random;
            m_wvalid = $random;
            m_wdata = $random;
            m_wstrb = $random;
            m_wlast = $random;
            m_bready = $random;
            m_arvalid = $random;
            m_araddr = $random;
            m_arid = $random;
            m_rready = $random;
            s_awready = $random;
            s_wready = $random;
            s_bvalid = $random;
            s_bresp = $random;
            s_bid = $random;
            s_arready = $random;
            s_rvalid = $random;
            s_rdata = $random;
            s_rresp = $random;
            s_rlast = $random;
            s_rid = $random;
        end

        #1000;
        $finish;
    end

endmodule
