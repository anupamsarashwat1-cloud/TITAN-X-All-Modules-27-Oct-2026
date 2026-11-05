`timescale 1ns / 1ps

module tb_rv_bpu();

    logic clk;
    logic rst_n;
    logic fetch_pc;
    logic fetch_valid;
    logic pred_taken;
    logic pred_target;
    logic pred_valid;
    logic ex_pc;
    logic ex_is_branch;
    logic ex_is_jal;
    logic ex_taken;
    logic ex_target;
    logic ex_valid;

    // DUT Instantiation
    rv_bpu uut (
        .clk(clk),
        .rst_n(rst_n),
        .fetch_pc(fetch_pc),
        .fetch_valid(fetch_valid),
        .pred_taken(pred_taken),
        .pred_target(pred_target),
        .pred_valid(pred_valid),
        .ex_pc(ex_pc),
        .ex_is_branch(ex_is_branch),
        .ex_is_jal(ex_is_jal),
        .ex_taken(ex_taken),
        .ex_target(ex_target),
        .ex_valid(ex_valid)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_bpu.vcd");
        $dumpvars(0, tb_rv_bpu);

        // 1. Initialize all data inputs
        fetch_pc = 0;
        fetch_valid = 0;
        ex_pc = 0;
        ex_is_branch = 0;
        ex_is_jal = 0;
        ex_taken = 0;
        ex_target = 0;
        ex_valid = 0;

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
            fetch_pc = $random;
            fetch_valid = $random;
            ex_pc = $random;
            ex_is_branch = $random;
            ex_is_jal = $random;
            ex_taken = $random;
            ex_target = $random;
            ex_valid = $random;
        end

        #1000;
        $finish;
    end

endmodule
