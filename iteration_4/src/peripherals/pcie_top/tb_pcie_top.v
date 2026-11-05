`timescale 1ns / 1ps

module tb_pcie_top();

    logic pcie_clk;
    logic pcie_rst_n;
    logic pipe_clk;
    logic m_awvalid;
    logic m_awready;
    logic m_awaddr;
    logic m_awid;
    logic m_awlen;
    logic m_awsize;
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
    logic m_arlen;
    logic m_arsize;
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
    logic s_arsize;
    logic s_rvalid;
    logic s_rready;
    logic s_rdata;
    logic s_rresp;
    logic s_rlast;
    logic s_rid;
    logic pipe_tx_data;
    logic pipe_tx_datak;
    logic pipe_rx_data;
    logic pipe_rx_datak;
    logic pipe_tx_rate;
    logic pipe_tx_elecidle;
    logic pipe_tx_compliance;
    logic pipe_rx_polarity;
    logic pipe_power_down;
    logic pipe_rx_valid;
    logic pipe_rx_elecidle;
    logic pipe_rx_status;
    logic pipe_phy_status;

    // DUT Instantiation
    pcie_top uut (
        .pcie_clk(pcie_clk),
        .pcie_rst_n(pcie_rst_n),
        .pipe_clk(pipe_clk),
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
        .s_arsize(s_arsize),
        .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .s_rlast(s_rlast),
        .s_rid(s_rid),
        .pipe_tx_data(pipe_tx_data),
        .pipe_tx_datak(pipe_tx_datak),
        .pipe_rx_data(pipe_rx_data),
        .pipe_rx_datak(pipe_rx_datak),
        .pipe_tx_rate(pipe_tx_rate),
        .pipe_tx_elecidle(pipe_tx_elecidle),
        .pipe_tx_compliance(pipe_tx_compliance),
        .pipe_rx_polarity(pipe_rx_polarity),
        .pipe_power_down(pipe_power_down),
        .pipe_rx_valid(pipe_rx_valid),
        .pipe_rx_elecidle(pipe_rx_elecidle),
        .pipe_rx_status(pipe_rx_status),
        .pipe_phy_status(pipe_phy_status)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        pcie_clk = 0;
        pipe_clk = 0;
    end

    always #3.6 pcie_clk = ~pcie_clk;
    always #3.6 pipe_clk = ~pipe_clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_pcie_top.vcd");
        $dumpvars(0, tb_pcie_top);

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
        s_arsize = 0;
        s_rready = 0;
        pipe_rx_data = 0;
        pipe_rx_datak = 0;
        pipe_rx_valid = 0;
        pipe_rx_elecidle = 0;
        pipe_rx_status = 0;
        pipe_phy_status = 0;

        // 2. Assert Resets
        #10;
        pcie_rst_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        pcie_rst_n = 1;
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
            s_arsize = $random;
            s_rready = $random;
            pipe_rx_data = $random;
            pipe_rx_datak = $random;
            pipe_rx_valid = $random;
            pipe_rx_elecidle = $random;
            pipe_rx_status = $random;
            pipe_phy_status = $random;
        end

        #1000;
        $finish;
    end

endmodule
