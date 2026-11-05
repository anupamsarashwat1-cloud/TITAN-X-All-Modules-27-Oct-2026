`timescale 1ns / 1ps

module tb_secure_boot();

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
    logic envm_addr;
    logic envm_req;
    logic envm_rdata;
    logic envm_valid;
    logic boot_pass;
    logic boot_fail;

    // DUT Instantiation
    secure_boot uut (
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
        .envm_addr(envm_addr),
        .envm_req(envm_req),
        .envm_rdata(envm_rdata),
        .envm_valid(envm_valid),
        .boot_pass(boot_pass),
        .boot_fail(boot_fail)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_secure_boot.vcd");
        $dumpvars(0, tb_secure_boot);

        // 1. Initialize all data inputs
        paddr = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        pwdata = 0;
        envm_rdata = 0;
        envm_valid = 0;

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
            envm_rdata = $random;
            envm_valid = $random;
        end

        #1000;
        $finish;
    end

endmodule
