`timescale 1ns / 1ps

module tb_interconnect_mpu();

    reg  clk;
    reg  rst_n;
    reg  cfg_base_addr;
    reg  cfg_limit_addr;
    reg  cfg_master_mask;
    reg  cfg_perm;
    reg  cfg_valid;
    reg  s_arvalid;
    wire s_arready;
    reg  s_araddr;
    reg  s_arid;
    wire m_arvalid;
    reg  m_arready;
    wire m_araddr;
    wire m_arid;
    reg  m_rvalid;
    wire m_rready;
    reg  m_rdata;
    reg  m_rresp;
    reg  m_rlast;
    reg  m_rid;
    wire s_rvalid;
    reg  s_rready;
    wire s_rdata;
    wire s_rresp;
    wire s_rlast;
    wire s_rid;
    reg  s_awvalid;
    wire s_awready;
    reg  s_awaddr;
    reg  s_awid;
    wire m_awvalid;
    reg  m_awready;
    wire m_awaddr;
    wire m_awid;
    reg  m_bvalid;
    wire m_bready;
    reg  m_bresp;
    reg  m_bid;
    wire s_bvalid;
    reg  s_bready;
    wire s_bresp;
    wire s_bid;

    // DUT Instantiation
    interconnect_mpu uut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_base_addr(cfg_base_addr),
        .cfg_limit_addr(cfg_limit_addr),
        .cfg_master_mask(cfg_master_mask),
        .cfg_perm(cfg_perm),
        .cfg_valid(cfg_valid),
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
        forever #3.6 clk = ~clk;
    end

    // Initial block for stimulus and VCD dumping
    initial begin
        $dumpfile("tb_interconnect_mpu.vcd");
        $dumpvars(0, tb_interconnect_mpu);

        // Initialize inputs
        rst_n = 0;
        cfg_base_addr = 0;
        cfg_limit_addr = 0;
        cfg_master_mask = 0;
        cfg_perm = 0;
        cfg_valid = 0;
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
        m_bvalid = 0;
        m_bresp = 0;
        m_bid = 0;
        s_bready = 0;

        // Reset sequence
        #10;
        rst_n = 1;
        #100;

        // Add manual test stimulus here...

        #1000;
        $finish;
    end

endmodule
