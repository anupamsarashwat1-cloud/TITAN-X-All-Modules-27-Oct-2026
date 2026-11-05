`timescale 1ns / 1ps

module tb_rv_fetch();

    logic clk;
    logic rst_n;
    logic stall;
    logic flush;
    logic branch_taken;
    logic branch_target;
    logic imem_addr;
    logic imem_arvalid;
    logic imem_arready;
    logic imem_rdata;
    logic imem_rvalid;
    logic imem_rresp;
    logic pc_out;
    logic instr_out;
    logic valid_out;

    // DUT Instantiation
    rv_fetch uut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .imem_addr(imem_addr),
        .imem_arvalid(imem_arvalid),
        .imem_arready(imem_arready),
        .imem_rdata(imem_rdata),
        .imem_rvalid(imem_rvalid),
        .imem_rresp(imem_rresp),
        .pc_out(pc_out),
        .instr_out(instr_out),
        .valid_out(valid_out)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_fetch.vcd");
        $dumpvars(0, tb_rv_fetch);

        // 1. Initialize all data inputs
        stall = 0;
        flush = 0;
        branch_taken = 0;
        branch_target = 0;
        imem_arready = 0;
        imem_rdata = 0;
        imem_rvalid = 0;
        imem_rresp = 0;

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
            stall = $random;
            flush = $random;
            branch_taken = $random;
            branch_target = $random;
            imem_arready = $random;
            imem_rdata = $random;
            imem_rvalid = $random;
            imem_rresp = $random;
        end

        #1000;
        $finish;
    end

endmodule
