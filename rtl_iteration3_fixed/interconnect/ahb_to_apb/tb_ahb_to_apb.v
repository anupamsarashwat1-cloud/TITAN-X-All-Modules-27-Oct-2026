`timescale 1ns / 1ps

module tb_ahb_to_apb();

    logic clk;
    logic rst_n;
    logic haddr;
    logic hwrite;
    logic htrans;
    logic hwdata;
    logic hrdata;
    logic hready_out;
    logic hresp;
    logic paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic pwdata;
    logic prdata;
    logic pready;
    logic pslverr;

    // DUT Instantiation
    ahb_to_apb uut (
        .clk(clk),
        .rst_n(rst_n),
        .haddr(haddr),
        .hwrite(hwrite),
        .htrans(htrans),
        .hwdata(hwdata),
        .hrdata(hrdata),
        .hready_out(hready_out),
        .hresp(hresp),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_ahb_to_apb.vcd");
        $dumpvars(0, tb_ahb_to_apb);

        // 1. Initialize all data inputs
        haddr = 0;
        hwrite = 0;
        htrans = 0;
        hwdata = 0;
        prdata = 0;
        pready = 0;
        pslverr = 0;

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
            haddr = $random;
            hwrite = $random;
            htrans = $random;
            hwdata = $random;
            prdata = $random;
            pready = $random;
            pslverr = $random;
        end

        #1000;
        $finish;
    end

endmodule
