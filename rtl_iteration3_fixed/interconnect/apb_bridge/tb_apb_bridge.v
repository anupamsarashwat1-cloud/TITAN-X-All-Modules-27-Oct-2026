`timescale 1ns / 1ps

module tb_apb_bridge();

    logic clk;
    logic rst_n;
    logic s_awvalid;
    logic s_awready;
    logic s_awaddr;
    logic s_wvalid;
    logic s_wready;
    logic s_wdata;
    logic s_wstrb;
    logic s_bvalid;
    logic s_bready;
    logic s_bresp;
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
    logic pstrb;
    logic prdata;
    logic pready;
    logic pslverr;

    // DUT Instantiation
    apb_bridge uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_awvalid(s_awvalid),
        .s_awready(s_awready),
        .s_awaddr(s_awaddr),
        .s_wvalid(s_wvalid),
        .s_wready(s_wready),
        .s_wdata(s_wdata),
        .s_wstrb(s_wstrb),
        .s_bvalid(s_bvalid),
        .s_bready(s_bready),
        .s_bresp(s_bresp),
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
        .pstrb(pstrb),
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
        $dumpfile("tb_apb_bridge.vcd");
        $dumpvars(0, tb_apb_bridge);

        // 1. Initialize all data inputs
        s_awvalid = 0;
        s_awaddr = 0;
        s_wvalid = 0;
        s_wdata = 0;
        s_wstrb = 0;
        s_bready = 0;
        s_arvalid = 0;
        s_araddr = 0;
        s_rready = 0;
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
            s_awvalid = $random;
            s_awaddr = $random;
            s_wvalid = $random;
            s_wdata = $random;
            s_wstrb = $random;
            s_bready = $random;
            s_arvalid = $random;
            s_araddr = $random;
            s_rready = $random;
            prdata = $random;
            pready = $random;
            pslverr = $random;
        end

        #1000;
        $finish;
    end

endmodule
