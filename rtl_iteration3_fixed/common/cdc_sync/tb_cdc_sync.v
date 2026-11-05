`timescale 1ns / 1ps

module tb_cdc_sync();

    logic dst_clk;
    logic rst_n;
    logic data_in;
    logic data_out;

    // DUT Instantiation
    cdc_sync uut (
        .dst_clk(dst_clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        dst_clk = 0;
    end

    always #3.6 dst_clk = ~dst_clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_cdc_sync.vcd");
        $dumpvars(0, tb_cdc_sync);

        // 1. Initialize all data inputs
        data_in = 0;

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
            data_in = $random;
        end

        #1000;
        $finish;
    end

endmodule
