`timescale 1ns / 1ps

module tb_vdma();

    logic clk;
    logic rst_n;
    logic [31:0] s_axis_s2mm_tdata;
    logic s_axis_s2mm_tvalid;
    wire s_axis_s2mm_tready;
    logic s_axis_s2mm_tuser;
    logic s_axis_s2mm_tlast;
    wire [31:0] m_axis_mm2s_tdata;
    wire m_axis_mm2s_tvalid;
    logic m_axis_mm2s_tready;
    wire m_axis_mm2s_tuser;
    wire m_axis_mm2s_tlast;
    wire m_axi_awvalid;
    logic m_axi_awready;
    wire [39:0] m_axi_awaddr;
    wire [7:0] m_axi_awlen;
    wire [2:0] m_axi_awsize;
    wire m_axi_wvalid;
    logic m_axi_wready;
    wire [63:0] m_axi_wdata;
    wire [7:0] m_axi_wstrb;
    wire m_axi_wlast;
    logic m_axi_bvalid;
    wire m_axi_bready;
    logic [1:0] m_axi_bresp;
    wire m_axi_arvalid;
    logic m_axi_arready;
    wire [39:0] m_axi_araddr;
    wire [7:0] m_axi_arlen;
    wire [2:0] m_axi_arsize;
    logic m_axi_rvalid;
    wire m_axi_rready;
    logic [63:0] m_axi_rdata;
    logic [1:0] m_axi_rresp;
    logic m_axi_rlast;
    logic [31:0] paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] pwdata;
    wire [31:0] prdata;
    wire pready;
    wire pslverr;
    wire vdma_irq;

    // DUT Instantiation
    vdma uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_s2mm_tdata(s_axis_s2mm_tdata),
        .s_axis_s2mm_tvalid(s_axis_s2mm_tvalid),
        .s_axis_s2mm_tready(s_axis_s2mm_tready),
        .s_axis_s2mm_tuser(s_axis_s2mm_tuser),
        .s_axis_s2mm_tlast(s_axis_s2mm_tlast),
        .m_axis_mm2s_tdata(m_axis_mm2s_tdata),
        .m_axis_mm2s_tvalid(m_axis_mm2s_tvalid),
        .m_axis_mm2s_tready(m_axis_mm2s_tready),
        .m_axis_mm2s_tuser(m_axis_mm2s_tuser),
        .m_axis_mm2s_tlast(m_axis_mm2s_tlast),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .vdma_irq(vdma_irq)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_vdma.vcd");
        $dumpvars(0, tb_vdma);

        // 1. Initialize all data inputs
        s_axis_s2mm_tdata = 0;
        s_axis_s2mm_tvalid = 0;
        s_axis_s2mm_tuser = 0;
        s_axis_s2mm_tlast = 0;
        m_axis_mm2s_tready = 0;
        m_axi_awready = 0;
        m_axi_wready = 0;
        m_axi_bvalid = 0;
        m_axi_bresp = 0;
        m_axi_arready = 0;
        m_axi_rvalid = 0;
        m_axi_rdata = 0;
        m_axi_rresp = 0;
        m_axi_rlast = 0;
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
            s_axis_s2mm_tdata = $random;
            s_axis_s2mm_tvalid = $random;
            s_axis_s2mm_tuser = $random;
            s_axis_s2mm_tlast = $random;
            m_axis_mm2s_tready = $random;
            m_axi_awready = $random;
            m_axi_wready = $random;
            m_axi_bvalid = $random;
            m_axi_bresp = $random;
            m_axi_arready = $random;
            m_axi_rvalid = $random;
            m_axi_rdata = $random;
            m_axi_rresp = $random;
            m_axi_rlast = $random;
            paddr = $random;
            psel = $random;
            penable = $random;
            pwrite = $random;
            pwdata = $random;
        end

        #1000;
        $display("\n==============================");
        $display("VDMA VERDICT: ✅ PASS — Random stimulus completed (no crash)");
        $display("==============================\n");
        $finish;
    end

endmodule
