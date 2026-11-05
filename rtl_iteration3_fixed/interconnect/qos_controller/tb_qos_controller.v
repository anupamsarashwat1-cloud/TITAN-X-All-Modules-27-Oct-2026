`timescale 1ns / 1ps

module tb_qos_controller();

    logic clk;
    logic rst_n;
    logic cfg_base_qos;
    logic cfg_boost_qos;
    logic cfg_bw_limit;
    logic cfg_time_win;
    logic m_arvalid;
    logic m_arready;
    logic m_awvalid;
    logic m_awready;
    logic m_arqos;
    logic m_awqos;

    // DUT Instantiation
    qos_controller uut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_base_qos(cfg_base_qos),
        .cfg_boost_qos(cfg_boost_qos),
        .cfg_bw_limit(cfg_bw_limit),
        .cfg_time_win(cfg_time_win),
        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_arqos(m_arqos),
        .m_awqos(m_awqos)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_qos_controller.vcd");
        $dumpvars(0, tb_qos_controller);

        // 1. Initialize all data inputs
        cfg_base_qos = 0;
        cfg_boost_qos = 0;
        cfg_bw_limit = 0;
        cfg_time_win = 0;
        m_arvalid = 0;
        m_arready = 0;
        m_awvalid = 0;
        m_awready = 0;

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
            cfg_base_qos = $random;
            cfg_boost_qos = $random;
            cfg_bw_limit = $random;
            cfg_time_win = $random;
            m_arvalid = $random;
            m_arready = $random;
            m_awvalid = $random;
            m_awready = $random;
        end

        #1000;
        $finish;
    end

endmodule
