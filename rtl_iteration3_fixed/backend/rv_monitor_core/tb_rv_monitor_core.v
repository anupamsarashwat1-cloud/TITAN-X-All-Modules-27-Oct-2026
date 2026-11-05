`timescale 1ns / 1ps

module tb_rv_monitor_core();

    logic clk;
    logic rst_n;
    logic irq_m_ext;
    logic irq_m_timer;
    logic irq_m_soft;
    logic imem_araddr;
    logic imem_arvalid;
    logic imem_arready;
    logic imem_rdata;
    logic imem_rvalid;
    logic imem_rresp;
    logic dmem_awvalid;
    logic dmem_awready;
    logic dmem_awaddr;
    logic dmem_awlen;
    logic dmem_awsize;
    logic dmem_awburst;
    logic dmem_wvalid;
    logic dmem_wready;
    logic dmem_wdata;
    logic dmem_wstrb;
    logic dmem_wlast;
    logic dmem_bvalid;
    logic dmem_bready;
    logic dmem_bresp;
    logic dmem_arvalid;
    logic dmem_arready;
    logic dmem_araddr;
    logic dmem_arlen;
    logic dmem_arsize;
    logic dmem_arburst;
    logic dmem_rvalid;
    logic dmem_rready;
    logic dmem_rdata;
    logic dmem_rlast;
    logic dmem_rresp;
    logic halt_req;
    logic resume_req;
    logic hart_halted;
    logic hart_running;

    // DUT Instantiation
    rv_monitor_core uut (
        .clk(clk),
        .rst_n(rst_n),
        .irq_m_ext(irq_m_ext),
        .irq_m_timer(irq_m_timer),
        .irq_m_soft(irq_m_soft),
        .imem_araddr(imem_araddr),
        .imem_arvalid(imem_arvalid),
        .imem_arready(imem_arready),
        .imem_rdata(imem_rdata),
        .imem_rvalid(imem_rvalid),
        .imem_rresp(imem_rresp),
        .dmem_awvalid(dmem_awvalid),
        .dmem_awready(dmem_awready),
        .dmem_awaddr(dmem_awaddr),
        .dmem_awlen(dmem_awlen),
        .dmem_awsize(dmem_awsize),
        .dmem_awburst(dmem_awburst),
        .dmem_wvalid(dmem_wvalid),
        .dmem_wready(dmem_wready),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_wlast(dmem_wlast),
        .dmem_bvalid(dmem_bvalid),
        .dmem_bready(dmem_bready),
        .dmem_bresp(dmem_bresp),
        .dmem_arvalid(dmem_arvalid),
        .dmem_arready(dmem_arready),
        .dmem_araddr(dmem_araddr),
        .dmem_arlen(dmem_arlen),
        .dmem_arsize(dmem_arsize),
        .dmem_arburst(dmem_arburst),
        .dmem_rvalid(dmem_rvalid),
        .dmem_rready(dmem_rready),
        .dmem_rdata(dmem_rdata),
        .dmem_rlast(dmem_rlast),
        .dmem_rresp(dmem_rresp),
        .halt_req(halt_req),
        .resume_req(resume_req),
        .hart_halted(hart_halted),
        .hart_running(hart_running)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_monitor_core.vcd");
        $dumpvars(0, tb_rv_monitor_core);

        // 1. Initialize all data inputs
        irq_m_ext = 0;
        irq_m_timer = 0;
        irq_m_soft = 0;
        imem_arready = 0;
        imem_rdata = 0;
        imem_rvalid = 0;
        imem_rresp = 0;
        dmem_awready = 0;
        dmem_wready = 0;
        dmem_bvalid = 0;
        dmem_bresp = 0;
        dmem_arready = 0;
        dmem_rvalid = 0;
        dmem_rdata = 0;
        dmem_rlast = 0;
        dmem_rresp = 0;
        halt_req = 0;
        resume_req = 0;

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
            irq_m_ext = $random;
            irq_m_timer = $random;
            irq_m_soft = $random;
            imem_arready = $random;
            imem_rdata = $random;
            imem_rvalid = $random;
            imem_rresp = $random;
            dmem_awready = $random;
            dmem_wready = $random;
            dmem_bvalid = $random;
            dmem_bresp = $random;
            dmem_arready = $random;
            dmem_rvalid = $random;
            dmem_rdata = $random;
            dmem_rlast = $random;
            dmem_rresp = $random;
            halt_req = $random;
            resume_req = $random;
        end

        #1000;
        $finish;
    end

endmodule
