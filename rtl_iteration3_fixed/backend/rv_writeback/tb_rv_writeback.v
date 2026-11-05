`timescale 1ns / 1ps

module tb_rv_writeback();

    logic clk;
    logic rst_n;
    logic result;
    logic rd_in;
    logic reg_write;
    logic valid_in;
    logic wb_data;
    logic wb_rd;
    logic wb_we;
    logic fwd_wb_data;
    logic fwd_wb_rd;
    logic fwd_wb_valid;

    // DUT Instantiation
    rv_writeback uut (
        .clk(clk),
        .rst_n(rst_n),
        .result(result),
        .rd_in(rd_in),
        .reg_write(reg_write),
        .valid_in(valid_in),
        .wb_data(wb_data),
        .wb_rd(wb_rd),
        .wb_we(wb_we),
        .fwd_wb_data(fwd_wb_data),
        .fwd_wb_rd(fwd_wb_rd),
        .fwd_wb_valid(fwd_wb_valid)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_writeback.vcd");
        $dumpvars(0, tb_rv_writeback);

        // 1. Initialize all data inputs
        result = 0;
        rd_in = 0;
        reg_write = 0;
        valid_in = 0;

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
            result = $random;
            rd_in = $random;
            reg_write = $random;
            valid_in = $random;
        end

        #1000;
        $finish;
    end

endmodule
