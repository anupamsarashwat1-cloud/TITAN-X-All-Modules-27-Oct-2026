`timescale 1ns / 1ps

module tb_mmu_arbiter();

    logic clk;
    logic rst_n;
    logic s_arvalid;
    logic s_arready;
    logic s_araddr;
    logic s_rvalid;
    logic s_rready;
    logic s_rdata;
    logic s_rresp;
    logic m_arvalid;
    logic m_arready;
    logic m_araddr;
    logic m_rvalid;
    logic m_rready;
    logic m_rdata;
    logic m_rresp;

    // DUT Instantiation
    mmu_arbiter uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_araddr(s_araddr),
        .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_araddr(m_araddr),
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .m_rdata(m_rdata),
        .m_rresp(m_rresp)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_mmu_arbiter.vcd");
        $dumpvars(0, tb_mmu_arbiter);

        // 1. Initialize all data inputs
        s_arvalid = 0;
        s_araddr = 0;
        s_rready = 0;
        m_arready = 0;
        m_rvalid = 0;
        m_rdata = 0;
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
            s_arvalid = $random;
            s_araddr = $random;
            s_rready = $random;
            m_arready = $random;
            m_rvalid = $random;
            m_rdata = $random;
            m_rresp = $random;
        end

        #1000;
        $finish;
    end

endmodule
