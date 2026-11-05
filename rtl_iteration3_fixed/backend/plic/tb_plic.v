`timescale 1ns / 1ps

module tb_plic();

    logic clk;
    logic rst_n;
    logic interrupt_sources;
    logic psel;
    logic penable;
    logic pwrite;
    logic paddr;
    logic pwdata;
    logic prdata;
    logic pready;
    logic irq_targets;

    // DUT Instantiation
    plic uut (
        .clk(clk),
        .rst_n(rst_n),
        .interrupt_sources(interrupt_sources),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .irq_targets(irq_targets)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_plic.vcd");
        $dumpvars(0, tb_plic);

        // 1. Initialize all data inputs
        interrupt_sources = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        paddr = 0;
        pwdata = 0;

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
            interrupt_sources = $random;
            psel = $random;
            penable = $random;
            pwrite = $random;
            paddr = $random;
            pwdata = $random;
        end

        #1000;
        $finish;
    end

endmodule
