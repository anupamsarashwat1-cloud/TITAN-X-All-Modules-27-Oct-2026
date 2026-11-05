`timescale 1ns / 1ps

module tb_rtc();

    logic clk;
    logic rtc_clk;
    logic rst_n;
    logic paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic pwdata;
    logic prdata;
    logic pready;
    logic pslverr;
    logic timer_irq;

    // DUT Instantiation
    rtc uut (
        .clk(clk),
        .rtc_clk(rtc_clk),
        .rst_n(rst_n),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .timer_irq(timer_irq)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
        rtc_clk = 0;
    end

    always #3.6 clk = ~clk;
    always #3.6 rtc_clk = ~rtc_clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rtc.vcd");
        $dumpvars(0, tb_rtc);

        // 1. Initialize all data inputs
        paddr = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
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
            paddr = $random;
            psel = $random;
            penable = $random;
            pwrite = $random;
            pwdata = $random;
        end

        #1000;
        $finish;
    end

endmodule
