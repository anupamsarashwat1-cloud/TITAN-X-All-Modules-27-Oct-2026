`timescale 1ns / 1ps

module tb_hdmi_ctrl();

    logic clk_pixel;
    logic clk_tmds;
    logic rst_n;
    logic s_axis_tdata;
    logic s_axis_tvalid;
    logic s_axis_tready;
    logic s_axis_tuser;
    logic s_axis_tlast;
    logic tmds_clk_p;
    logic tmds_clk_n;
    logic tmds_data_p;
    logic tmds_data_n;
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
    hdmi_ctrl uut (
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_tmds),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p),
        .tmds_data_n(tmds_data_n),
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
        clk_pixel = 0;
        clk_tmds = 0;
        pclk = 0;
    end

    always #3.6 clk_pixel = ~clk_pixel;
    always #3.6 clk_tmds = ~clk_tmds;
    always #3.6 pclk = ~pclk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_hdmi_ctrl.vcd");
        $dumpvars(0, tb_hdmi_ctrl);

        // 1. Initialize all data inputs
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        s_axis_tuser = 0;
        s_axis_tlast = 0;
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
            s_axis_tdata = $random;
            s_axis_tvalid = $random;
            s_axis_tuser = $random;
            s_axis_tlast = $random;
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
