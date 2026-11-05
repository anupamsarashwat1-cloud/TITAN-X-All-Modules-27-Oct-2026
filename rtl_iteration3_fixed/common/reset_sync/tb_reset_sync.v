`timescale 1ns / 1ps

module tb_reset_sync();

    logic clk;
    logic async_rst_n;
    logic sync_rst_n;

    // DUT Instantiation
    reset_sync uut (
        .clk(clk),
        .async_rst_n(async_rst_n),
        .sync_rst_n(sync_rst_n)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_reset_sync.vcd");
        $dumpvars(0, tb_reset_sync);

        // 1. Initialize all data inputs

        // 2. Assert Resets
        #10;
        async_rst_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        async_rst_n = 1;
        #20;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
        end

        #1000;
        $finish;
    end

endmodule
