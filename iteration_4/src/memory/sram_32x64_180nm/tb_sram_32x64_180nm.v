`timescale 1ns / 1ps

module tb_sram_32x64_180nm();

    logic clk0;
    logic csb0;
    logic web0;
    logic wmask0;
    logic addr0;
    logic din0;
    logic dout0;

    // DUT Instantiation
    sram_32x64_180nm uut (
        .clk0(clk0),
        .csb0(csb0),
        .web0(web0),
        .wmask0(wmask0),
        .addr0(addr0),
        .din0(din0),
        .dout0(dout0)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk0 = 0;
    end

    always #3.6 clk0 = ~clk0;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_sram_32x64_180nm.vcd");
        $dumpvars(0, tb_sram_32x64_180nm);

        // 1. Initialize all data inputs
        csb0 = 0;
        web0 = 0;
        wmask0 = 0;
        addr0 = 0;
        din0 = 0;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
            csb0 = $random;
            web0 = $random;
            wmask0 = $random;
            addr0 = $random;
            din0 = $random;
        end

        #1000;
        $finish;
    end

endmodule
