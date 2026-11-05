`timescale 1ns / 1ps

module tb_rv_fpu();

    logic clk;
    logic rst_n;
    logic fop;
    logic fmt;
    logic rm;
    logic valid_in;
    logic fp_src1;
    logic fp_src2;
    logic fp_src3;
    logic int_src;
    logic frm_csr;
    logic fp_result;
    logic result_valid;
    logic fflags;
    logic fpu_done;
    logic int_result;
    logic int_result_valid;

    // DUT Instantiation
    rv_fpu uut (
        .clk(clk),
        .rst_n(rst_n),
        .fop(fop),
        .fmt(fmt),
        .rm(rm),
        .valid_in(valid_in),
        .fp_src1(fp_src1),
        .fp_src2(fp_src2),
        .fp_src3(fp_src3),
        .int_src(int_src),
        .frm_csr(frm_csr),
        .fp_result(fp_result),
        .result_valid(result_valid),
        .fflags(fflags),
        .fpu_done(fpu_done),
        .int_result(int_result),
        .int_result_valid(int_result_valid)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_fpu.vcd");
        $dumpvars(0, tb_rv_fpu);

        // 1. Initialize all data inputs
        fop = 0;
        fmt = 0;
        rm = 0;
        valid_in = 0;
        fp_src1 = 0;
        fp_src2 = 0;
        fp_src3 = 0;
        int_src = 0;
        frm_csr = 0;

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
            fop = $random;
            fmt = $random;
            rm = $random;
            valid_in = $random;
            fp_src1 = $random;
            fp_src2 = $random;
            fp_src3 = $random;
            int_src = $random;
            frm_csr = $random;
        end

        #1000;
        $finish;
    end

endmodule
