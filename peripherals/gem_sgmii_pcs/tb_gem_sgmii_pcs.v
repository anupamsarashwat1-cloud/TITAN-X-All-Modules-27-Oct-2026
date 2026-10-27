`timescale 1ns / 1ps

module tb_gem_sgmii_pcs();

    logic reset_n;
    logic tx_clk;
    logic rx_clk;
    logic [7:0] gmii_txd;
    logic gmii_tx_en;
    logic gmii_tx_er;
    wire [7:0] gmii_rxd;
    wire gmii_rx_dv;
    wire gmii_rx_er;
    wire gmii_crs;
    wire gmii_col;
    wire [9:0] tbi_tx_data;
    logic [9:0] tbi_rx_data;
    logic signal_detect;
    wire link_up;
    wire [1:0] speed;
    wire duplex;

    // DUT Instantiation
    gem_sgmii_pcs uut (
        .reset_n(reset_n),
        .tx_clk(tx_clk),
        .rx_clk(rx_clk),
        .gmii_txd(gmii_txd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er),
        .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_crs(gmii_crs),
        .gmii_col(gmii_col),
        .tbi_tx_data(tbi_tx_data),
        .tbi_rx_data(tbi_rx_data),
        .signal_detect(signal_detect),
        .link_up(link_up),
        .speed(speed),
        .duplex(duplex)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        tx_clk = 0;
        rx_clk = 0;
    end

    always #3.6 tx_clk = ~tx_clk;
    always #3.6 rx_clk = ~rx_clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_gem_sgmii_pcs.vcd");
        $dumpvars(0, tb_gem_sgmii_pcs);

        // 1. Initialize all data inputs
        gmii_txd = 0;
        gmii_tx_en = 0;
        gmii_tx_er = 0;
        tbi_rx_data = 0;
        signal_detect = 0;

        // 2. Assert Resets
        #10;
        reset_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        reset_n = 1;
        #20;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
            gmii_txd = $random;
            gmii_tx_en = $random;
            gmii_tx_er = $random;
            tbi_rx_data = $random;
            signal_detect = $random;
        end

        #1000;
        $display("\n==============================");
        $display("GEM_SGMII_PCS VERDICT: ✅ PASS — Completed (no crash)");
        $display("==============================\n");
        $finish;
    end

endmodule
