`timescale 1ns / 1ps

module tb_rv_icache();

    logic clk;
    logic rst_n;
    logic cpu_addr;
    logic cpu_req;
    logic cpu_rdata;
    logic cpu_valid;
    logic cpu_stall;
    logic invalidate;
    logic m_arvalid;
    logic m_arready;
    logic m_araddr;
    logic m_arlen;
    logic m_arsize;
    logic m_arburst;
    logic m_rvalid;
    logic m_rready;
    logic m_rdata;
    logic m_rlast;
    logic m_rresp;
    logic ecc_1bit;
    logic ecc_2bit;

    // DUT Instantiation
    rv_icache uut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_addr),
        .cpu_req(cpu_req),
        .cpu_rdata(cpu_rdata),
        .cpu_valid(cpu_valid),
        .cpu_stall(cpu_stall),
        .invalidate(invalidate),
        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_araddr(m_araddr),
        .m_arlen(m_arlen),
        .m_arsize(m_arsize),
        .m_arburst(m_arburst),
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .m_rdata(m_rdata),
        .m_rlast(m_rlast),
        .m_rresp(m_rresp),
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
        $dumpfile("tb_rv_icache.vcd");
        $dumpvars(0, tb_rv_icache);

        // 1. Initialize all data inputs
        cpu_addr = 0;
        cpu_req = 0;
        invalidate = 0;
        m_arready = 0;
        m_rvalid = 0;
        m_rdata = 0;
        m_rlast = 0;
        m_rresp = 0;

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
            cpu_req = $random;
            invalidate = $random;
            m_arready = $random;
            m_rvalid = $random;
            m_rdata = $random;
            m_rlast = $random;
            m_rresp = $random;
        end

        #1000;
        $finish;
    end

endmodule
