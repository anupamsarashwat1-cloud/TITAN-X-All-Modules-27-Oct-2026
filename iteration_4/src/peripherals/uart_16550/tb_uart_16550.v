`timescale 1ns / 1ps

module tb_uart_16550();

    logic clk;
    logic rst_n;
    logic paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic pwdata;
    logic prdata;
    logic pready;
    logic pslverr;
    logic uart_irq;
    logic rxd;
    logic txd;
    logic irda_tx;
    logic irda_rx;
    logic lin_tx;
    logic lin_rx;

    // DUT Instantiation
    uart_16550 uut (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .uart_irq(uart_irq),
        .rxd(rxd),
        .txd(txd),
        .irda_tx(irda_tx),
        .irda_rx(irda_rx),
        .lin_tx(lin_tx),
        .lin_rx(lin_rx)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_uart_16550.vcd");
        $dumpvars(0, tb_uart_16550);

        // 1. Initialize all data inputs
        paddr = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        pwdata = 0;
        rxd = 0;
        irda_rx = 0;
        lin_rx = 0;

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
            rxd = $random;
            irda_rx = $random;
            lin_rx = $random;
        end

        #1000;
        $finish;
    end

endmodule
