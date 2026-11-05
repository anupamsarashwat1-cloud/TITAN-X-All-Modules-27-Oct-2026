`timescale 1ns / 1ps

module tb_fifo_sync();

    logic clk;
    logic rst_n;
    logic wr_en;
    logic rd_en;
    logic wr_data;
    logic rd_data;
    logic full;
    logic empty;
    logic count;

    // DUT Instantiation
    fifo_sync uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .full(full),
        .empty(empty),
        .count(count)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_fifo_sync.vcd");
        $dumpvars(0, tb_fifo_sync);

        // 1. Initialize all data inputs
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;

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
            wr_en = $random;
            rd_en = $random;
            wr_data = $random;
        end

        #1000;
        $finish;
    end

endmodule
