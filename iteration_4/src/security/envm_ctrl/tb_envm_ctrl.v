`timescale 1ns / 1ps

module tb_envm_ctrl();

    logic clk;
    logic rst_n;
    logic s_arvalid;
    logic s_arready;
    logic s_araddr;
    logic s_rvalid;
    logic s_rready;
    logic s_rdata;
    logic s_rresp;
    logic paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic pwdata;
    logic prdata;
    logic pready;
    logic pslverr;
    logic envm_clk;
    logic envm_ce_n;
    logic envm_we_n;
    logic envm_addr;
    logic envm_wdata;
    logic envm_rdata;
    logic envm_ready;

    // DUT Instantiation
    envm_ctrl uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_araddr(s_araddr),
        .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .envm_clk(envm_clk),
        .envm_ce_n(envm_ce_n),
        .envm_we_n(envm_we_n),
        .envm_addr(envm_addr),
        .envm_wdata(envm_wdata),
        .envm_rdata(envm_rdata),
        .envm_ready(envm_ready)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_envm_ctrl.vcd");
        $dumpvars(0, tb_envm_ctrl);

        // 1. Initialize all data inputs
        s_arvalid = 0;
        s_araddr = 0;
        s_rready = 0;
        paddr = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        pwdata = 0;
        envm_rdata = 0;
        envm_ready = 0;

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
            s_arvalid = $random;
            s_araddr = $random;
            s_rready = $random;
            paddr = $random;
            psel = $random;
            penable = $random;
            pwrite = $random;
            pwdata = $random;
            envm_rdata = $random;
            envm_ready = $random;
        end

        #1000;
        $finish;
    end

endmodule
