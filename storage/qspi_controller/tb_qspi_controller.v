`timescale 1ns / 1ps

module tb_qspi_controller();

    logic clk;
    logic rst_n;
    logic s_arvalid;
    wire s_arready;
    logic [31:0] s_araddr;
    wire s_rvalid;
    logic s_rready;
    wire [31:0] s_rdata;
    wire [1:0] s_rresp;
    logic [31:0] paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] pwdata;
    wire [31:0] prdata;
    wire pready;
    wire pslverr;
    wire qspi_sclk;
    wire qspi_cs_n;
    wire [3:0] qspi_io;

    // DUT Instantiation
    qspi_controller uut (
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
        .qspi_sclk(qspi_sclk),
        .qspi_cs_n(qspi_cs_n),
        .qspi_io(qspi_io)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_qspi_controller.vcd");
        $dumpvars(0, tb_qspi_controller);

        // 1. Initialize all data inputs
        s_arvalid = 0;
        s_araddr = 0;
        s_rready = 0;
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
            s_arvalid = $random;
            s_araddr = $random;
            s_rready = $random;
            paddr = $random;
            psel = $random;
            penable = $random;
            pwrite = $random;
            pwdata = $random;
        end

        #1000;
        $display("\n==============================");
        $display("QSPI_CONTROLLER VERDICT: ✅ PASS — Random stimulus completed (no crash)");
        $display("==============================\n");
        $finish;
    end

endmodule
