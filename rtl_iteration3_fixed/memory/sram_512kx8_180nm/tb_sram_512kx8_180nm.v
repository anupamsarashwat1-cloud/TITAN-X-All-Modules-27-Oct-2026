`timescale 1ns / 1ps

module tb_sram_512kx8_180nm();

    logic CLK;
    logic CEN;
    logic WEN;
    logic A;
    logic D;
    logic Q;

    // DUT Instantiation
    sram_512kx8_180nm uut (
        .CLK(CLK),
        .CEN(CEN),
        .WEN(WEN),
        .A(A),
        .D(D),
        .Q(Q)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        CLK = 0;
    end

    always #3.6 CLK = ~CLK;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_sram_512kx8_180nm.vcd");
        $dumpvars(0, tb_sram_512kx8_180nm);

        // 1. Initialize all data inputs
        CEN = 0;
        WEN = 0;
        A = 0;
        D = 0;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
            CEN = $random;
            WEN = $random;
            A = $random;
            D = $random;
        end

        #1000;
        $finish;
    end

endmodule
