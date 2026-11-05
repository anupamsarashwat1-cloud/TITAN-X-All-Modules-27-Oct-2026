`timescale 1ns / 1ps

module tb_fifo_async();

    logic wr_clk;
    logic wr_rst_n;
    logic wr_en;
    logic wr_data;
    logic full;
    logic rd_clk;
    logic rd_rst_n;
    logic rd_en;
    logic rd_data;
    logic empty;

    // DUT Instantiation
    fifo_async uut (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .rd_clk(rd_clk),
        .rd_rst_n(rd_rst_n),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        wr_clk = 0;
        rd_clk = 0;
    end

    always #3.6 wr_clk = ~wr_clk;
    always #3.6 rd_clk = ~rd_clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_fifo_async.vcd");
        $dumpvars(0, tb_fifo_async);

        // 1. Initialize all data inputs
        wr_en = 0;
        wr_data = 0;
        rd_en = 0;

        // 2. Assert Resets
        #10;
        wr_rst_n = 0; // Active low
        rd_rst_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        wr_rst_n = 1;
        rd_rst_n = 1;
        #20;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
            wr_en = $random;
            wr_data = $random;
            rd_en = $random;
        end

        #1000;
        $finish;
    end

endmodule
