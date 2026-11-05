`timescale 1ns / 1ps

module tb_rv_pmp();

    logic clk;
    logic rst_n;
    logic paddr;
    logic check_r;
    logic check_w;
    logic check_x;
    logic priv_mode;
    logic check_en;
    logic pmpcfg0;
    logic pmpcfg2;
    logic pmpaddr_packed;
    logic pmp_fault;

    // DUT Instantiation
    rv_pmp uut (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(paddr),
        .check_r(check_r),
        .check_w(check_w),
        .check_x(check_x),
        .priv_mode(priv_mode),
        .check_en(check_en),
        .pmpcfg0(pmpcfg0),
        .pmpcfg2(pmpcfg2),
        .pmpaddr_packed(pmpaddr_packed),
        .pmp_fault(pmp_fault)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_pmp.vcd");
        $dumpvars(0, tb_rv_pmp);

        // 1. Initialize all data inputs
        paddr = 0;
        check_r = 0;
        check_w = 0;
        check_x = 0;
        priv_mode = 0;
        check_en = 0;
        pmpcfg0 = 0;
        pmpcfg2 = 0;
        pmpaddr_packed = 0;

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
            paddr = $random;
            check_r = $random;
            check_w = $random;
            check_x = $random;
            priv_mode = $random;
            check_en = $random;
            pmpcfg0 = $random;
            pmpcfg2 = $random;
            pmpaddr_packed = $random;
        end

        #1000;
        $finish;
    end

endmodule
