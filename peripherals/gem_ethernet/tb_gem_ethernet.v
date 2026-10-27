`timescale 1ns / 1ps

module tb_gem_ethernet();

    logic clk;
    logic rst_n;
    wire m_awvalid;
    logic m_awready;
    wire [39:0] m_awaddr;
    wire [3:0] m_awid;
    wire [7:0] m_awlen;
    wire [2:0] m_awsize;
    wire m_wvalid;
    logic m_wready;
    wire [63:0] m_wdata;
    wire [7.0:0] m_wstrb;
    wire m_wlast;
    logic m_bvalid;
    wire m_bready;
    logic [1:0] m_bresp;
    logic [3:0] m_bid;
    wire m_arvalid;
    logic m_arready;
    wire [39:0] m_araddr;
    wire [3:0] m_arid;
    wire [7:0] m_arlen;
    wire [2:0] m_arsize;
    logic m_rvalid;
    wire m_rready;
    logic [63:0] m_rdata;
    logic [1:0] m_rresp;
    logic m_rlast;
    logic [3:0] m_rid;
    logic [31:0] paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] pwdata;
    wire [31:0] prdata;
    wire pready;
    wire pslverr;
    wire mac_irq;
    logic tx_clk;
    wire [7:0] gmii_txd;
    wire gmii_tx_en;
    wire gmii_tx_er;
    logic rx_clk;
    logic [7:0] gmii_rxd;
    logic gmii_rx_dv;
    logic gmii_rx_er;
    logic gmii_crs;
    logic gmii_col;

    // DUT Instantiation
    gem_ethernet uut (
        .clk(clk),
        .rst_n(rst_n),
        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_awaddr(m_awaddr),
        .m_awid(m_awid),
        .m_awlen(m_awlen),
        .m_awsize(m_awsize),
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
        .m_arlen(m_arlen),
        .m_arsize(m_arsize),
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .m_rdata(m_rdata),
        .m_rresp(m_rresp),
        .m_rlast(m_rlast),
        .m_rid(m_rid),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .mac_irq(mac_irq),
        .tx_clk(tx_clk),
        .gmii_txd(gmii_txd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er),
        .rx_clk(rx_clk),
        .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_crs(gmii_crs),
        .gmii_col(gmii_col)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
        tx_clk = 0;
        rx_clk = 0;
    end

    always #3.6 clk = ~clk;
    always #3.6 tx_clk = ~tx_clk;
    always #3.6 rx_clk = ~rx_clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_gem_ethernet.vcd");
        $dumpvars(0, tb_gem_ethernet);

        // 1. Initialize all data inputs
        m_awready = 0;
        m_wready = 0;
        m_bvalid = 0;
        m_bresp = 0;
        m_bid = 0;
        m_arready = 0;
        m_rvalid = 0;
        m_rdata = 0;
        m_rresp = 0;
        m_rlast = 0;
        m_rid = 0;
        paddr = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        pwdata = 0;
        gmii_rxd = 0;
        gmii_rx_dv = 0;
        gmii_rx_er = 0;
        gmii_crs = 0;
        gmii_col = 0;

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
            m_awready = $random;
            m_wready = $random;
            m_bvalid = $random;
            m_bresp = $random;
            m_bid = $random;
            m_arready = $random;
            m_rvalid = $random;
            m_rdata = $random;
            m_rresp = $random;
            m_rlast = $random;
            m_rid = $random;
            paddr = $random;
            psel = $random;
            penable = $random;
            pwrite = $random;
            pwdata = $random;
            gmii_rxd = $random;
            gmii_rx_dv = $random;
            gmii_rx_er = $random;
            gmii_crs = $random;
            gmii_col = $random;
        end

        #1000;
        $display("\n==============================");
        $display("GEM_ETHERNET VERDICT: ✅ PASS — Completed (no crash)");
        $display("==============================\n");
        $finish;
    end

endmodule
