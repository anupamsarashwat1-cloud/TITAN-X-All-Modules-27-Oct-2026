`timescale 1ns / 1ps

module tb_mipi_csi2_rx();

    logic rst_n;
    logic rxbyteclkhs;
    logic rxdatahs;
    logic rxvalidhs;
    logic rxactivehs;
    logic rxsyncbhs;
    logic rxdata_lp;
    logic m_axis_tdata;
    logic m_axis_tvalid;
    logic m_axis_tready;
    logic m_axis_tuser;
    logic m_axis_tlast;
    logic pclk;
    logic prst_n;
    logic paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic pwdata;
    logic prdata;
    logic pready;
    logic pslverr;

    // DUT Instantiation
    mipi_csi2_rx uut (
        .rst_n(rst_n),
        .rxbyteclkhs(rxbyteclkhs),
        .rxdatahs(rxdatahs),
        .rxvalidhs(rxvalidhs),
        .rxactivehs(rxactivehs),
        .rxsyncbhs(rxsyncbhs),
        .rxdata_lp(rxdata_lp),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tlast(m_axis_tlast),
        .pclk(pclk),
        .prst_n(prst_n),
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
        rxbyteclkhs = 0;
        pclk = 0;
    end

    always #3.6 rxbyteclkhs = ~rxbyteclkhs;
    always #3.6 pclk = ~pclk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_mipi_csi2_rx.vcd");
        $dumpvars(0, tb_mipi_csi2_rx);

        // 1. Initialize all data inputs
        rxdatahs = 0;
        rxvalidhs = 0;
        rxactivehs = 0;
        rxsyncbhs = 0;
        rxdata_lp = 0;
        m_axis_tready = 0;
        paddr = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        pwdata = 0;

        // 2. Assert Resets
        #10;
        rst_n = 0; // Active low
        prst_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        rst_n = 1;
        prst_n = 1;
        #20;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
            rxdatahs = $random;
            rxvalidhs = $random;
            rxactivehs = $random;
            rxsyncbhs = $random;
            rxdata_lp = $random;
            m_axis_tready = $random;
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
