`timescale 1ns / 1ps

module tb_pcie_pipe_if();

    logic pclk;
    logic reset_n;
    logic tx_data;
    logic tx_datak;
    logic rx_data;
    logic rx_datak;
    logic rx_valid;
    logic rx_elecidle;
    logic rx_status;
    logic tx_rate;
    logic power_down;
    logic tx_elecidle;
    logic tx_compliance;
    logic rx_polarity;
    logic pipe_tx_data;
    logic pipe_tx_datak;
    logic pipe_rx_data;
    logic pipe_rx_datak;
    logic pipe_tx_rate;
    logic pipe_tx_elecidle;
    logic pipe_tx_compliance;
    logic pipe_rx_polarity;
    logic pipe_power_down;
    logic pipe_rx_valid;
    logic pipe_rx_elecidle;
    logic pipe_rx_status;
    logic pipe_phy_status;

    // DUT Instantiation
    pcie_pipe_if uut (
        .pclk(pclk),
        .reset_n(reset_n),
        .tx_data(tx_data),
        .tx_datak(tx_datak),
        .rx_data(rx_data),
        .rx_datak(rx_datak),
        .rx_valid(rx_valid),
        .rx_elecidle(rx_elecidle),
        .rx_status(rx_status),
        .tx_rate(tx_rate),
        .power_down(power_down),
        .tx_elecidle(tx_elecidle),
        .tx_compliance(tx_compliance),
        .rx_polarity(rx_polarity),
        .pipe_tx_data(pipe_tx_data),
        .pipe_tx_datak(pipe_tx_datak),
        .pipe_rx_data(pipe_rx_data),
        .pipe_rx_datak(pipe_rx_datak),
        .pipe_tx_rate(pipe_tx_rate),
        .pipe_tx_elecidle(pipe_tx_elecidle),
        .pipe_tx_compliance(pipe_tx_compliance),
        .pipe_rx_polarity(pipe_rx_polarity),
        .pipe_power_down(pipe_power_down),
        .pipe_rx_valid(pipe_rx_valid),
        .pipe_rx_elecidle(pipe_rx_elecidle),
        .pipe_rx_status(pipe_rx_status),
        .pipe_phy_status(pipe_phy_status)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        pclk = 0;
    end

    always #3.6 pclk = ~pclk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_pcie_pipe_if.vcd");
        $dumpvars(0, tb_pcie_pipe_if);

        // 1. Initialize all data inputs
        tx_data = 0;
        tx_datak = 0;
        tx_rate = 0;
        power_down = 0;
        tx_elecidle = 0;
        tx_compliance = 0;
        rx_polarity = 0;
        pipe_rx_data = 0;
        pipe_rx_datak = 0;
        pipe_rx_valid = 0;
        pipe_rx_elecidle = 0;
        pipe_rx_status = 0;
        pipe_phy_status = 0;

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
            tx_data = $random;
            tx_datak = $random;
            tx_rate = $random;
            power_down = $random;
            tx_elecidle = $random;
            tx_compliance = $random;
            rx_polarity = $random;
            pipe_rx_data = $random;
            pipe_rx_datak = $random;
            pipe_rx_valid = $random;
            pipe_rx_elecidle = $random;
            pipe_rx_status = $random;
            pipe_phy_status = $random;
        end

        #1000;
        $finish;
    end

endmodule
