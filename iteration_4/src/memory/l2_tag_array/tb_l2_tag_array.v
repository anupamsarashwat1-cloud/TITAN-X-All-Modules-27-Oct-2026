`timescale 1ns / 1ps

module tb_l2_tag_array();

    logic clk;
    logic rst_n;
    logic cs;
    logic we;
    logic index;
    logic tag_in;
    logic tag_out;
    logic valid_out;

    // DUT Instantiation
    l2_tag_array uut (
        .clk(clk),
        .rst_n(rst_n),
        .cs(cs),
        .we(we),
        .index(index),
        .tag_in(tag_in),
        .tag_out(tag_out),
        .valid_out(valid_out)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_l2_tag_array.vcd");
        $dumpvars(0, tb_l2_tag_array);

        // 1. Initialize all data inputs
        cs = 0;
        we = 0;
        index = 0;
        tag_in = 0;

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
            cs = $random;
            we = $random;
            index = $random;
            tag_in = $random;
        end

        #1000;
        $finish;
    end

endmodule
