`timescale 1ns / 1ps

module tb_rv_dcache();

    logic clk;
    logic rst_n;
    logic cpu_addr;
    logic cpu_wdata;
    logic cpu_wstrb;
    logic cpu_req;
    logic cpu_wr;
    logic cpu_size;
    logic cpu_rdata;
    logic cpu_valid;
    logic cpu_stall;
    logic is_lr;
    logic is_sc;
    logic lr_addr_in;
    logic lr_valid_in;
    logic sc_success;
    logic flush_all;
    logic flush_addr_en;
    logic flush_addr;
    logic m_arvalid;
    logic m_arready;
    logic m_araddr;
    logic m_arlen;
    logic m_arsize;
    logic m_arburst;
    logic m_arlock;
    logic m_rvalid;
    logic m_rready;
    logic m_rdata;
    logic m_rlast;
    logic m_rresp;
    logic m_awvalid;
    logic m_awready;
    logic m_awaddr;
    logic m_awlen;
    logic m_awsize;
    logic m_awburst;
    logic m_wvalid;
    logic m_wready;
    logic m_wdata;
    logic m_wstrb;
    logic m_wlast;
    logic m_bvalid;
    logic m_bready;
    logic m_bresp;
    logic snoop_valid;
    logic snoop_addr;
    logic snoop_type;
    logic snoop_ack;
    logic snoop_data_valid;
    logic snoop_data;
    logic ecc_1bit;
    logic ecc_2bit;

    // DUT Instantiation
    rv_dcache uut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_wstrb(cpu_wstrb),
        .cpu_req(cpu_req),
        .cpu_wr(cpu_wr),
        .cpu_size(cpu_size),
        .cpu_rdata(cpu_rdata),
        .cpu_valid(cpu_valid),
        .cpu_stall(cpu_stall),
        .is_lr(is_lr),
        .is_sc(is_sc),
        .lr_addr_in(lr_addr_in),
        .lr_valid_in(lr_valid_in),
        .sc_success(sc_success),
        .flush_all(flush_all),
        .flush_addr_en(flush_addr_en),
        .flush_addr(flush_addr),
        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_araddr(m_araddr),
        .m_arlen(m_arlen),
        .m_arsize(m_arsize),
        .m_arburst(m_arburst),
        .m_arlock(m_arlock),
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .m_rdata(m_rdata),
        .m_rlast(m_rlast),
        .m_rresp(m_rresp),
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
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_type(snoop_type),
        .snoop_ack(snoop_ack),
        .snoop_data_valid(snoop_data_valid),
        .snoop_data(snoop_data),
        .ecc_1bit(ecc_1bit),
        .ecc_2bit(ecc_2bit)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_dcache.vcd");
        $dumpvars(0, tb_rv_dcache);

        // 1. Initialize all data inputs
        cpu_addr = 0;
        cpu_wdata = 0;
        cpu_wstrb = 0;
        cpu_req = 0;
        cpu_wr = 0;
        cpu_size = 0;
        is_lr = 0;
        is_sc = 0;
        lr_addr_in = 0;
        lr_valid_in = 0;
        flush_all = 0;
        flush_addr_en = 0;
        flush_addr = 0;
        m_arready = 0;
        m_rvalid = 0;
        m_rdata = 0;
        m_rlast = 0;
        m_rresp = 0;
        m_awready = 0;
        m_wready = 0;
        m_bvalid = 0;
        m_bresp = 0;
        snoop_valid = 0;
        snoop_addr = 0;
        snoop_type = 0;

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
            cpu_addr = $random;
            cpu_wdata = $random;
            cpu_wstrb = $random;
            cpu_req = $random;
            cpu_wr = $random;
            cpu_size = $random;
            is_lr = $random;
            is_sc = $random;
            lr_addr_in = $random;
            lr_valid_in = $random;
            flush_all = $random;
            flush_addr_en = $random;
            flush_addr = $random;
            m_arready = $random;
            m_rvalid = $random;
            m_rdata = $random;
            m_rlast = $random;
            m_rresp = $random;
            m_awready = $random;
            m_wready = $random;
            m_bvalid = $random;
            m_bresp = $random;
            snoop_valid = $random;
            snoop_addr = $random;
            snoop_type = $random;
        end

        #1000;
        $finish;
    end

endmodule
