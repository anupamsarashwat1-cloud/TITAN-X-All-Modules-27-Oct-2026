// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Top-Level Testbench
// Iteration 3: Comprehensive system integration test.
`timescale 1ns/1ps

module tb_titan_x_top;

    // Clocks and Resets
    logic clk;
    logic rtc_clk;
    logic rst_n;
    
    // External interfaces mock
    logic [15:0] ddr_addr;
    logic [2:0]  ddr_ba;
    logic [1:0]  ddr_bg;
    logic        ddr_ck_p, ddr_ck_n, ddr_cke, ddr_cs_n;
    logic        ddr_odt, ddr_act_n, ddr_ras_n, ddr_cas_n, ddr_we_n, ddr_reset_n;
    wire [63:0]  ddr_dq;
    wire [7:0]   ddr_dqs_p, ddr_dqs_n;
    
    logic        pcie_clk, pipe_clk;
    logic [63:0] pcie_rx_p, pcie_rx_n;
    
    logic        eth_tx_clk, eth_rx_clk;
    logic [7:0]  eth_rxd;
    logic        eth_rx_dv, eth_rx_er, eth_crs, eth_col;
    
    logic        mipi_rxbyteclkhs;
    logic [31:0] mipi_rxdatahs;
    logic [3:0]  mipi_rxvalidhs, mipi_rxactivehs;
    
    logic        hdmi_clk_pixel, hdmi_clk_tmds;
    
    wire         sd_cmd;
    wire [7:0]   sd_dat;
    
    logic        ulpi_clk;
    wire [7:0]   ulpi_data;
    logic        ulpi_dir, ulpi_nxt;
    
    wire         qspi_cs_n;
    wire [3:0]   qspi_io;
    
    logic [4:0]  uart_rx;
    logic [1:0]  can_rx;
    
    logic [255:0] trng_seed;
    logic         trng_seed_valid;

    // Instantiate Top
    titan_x_top u_dut (
        .clk(clk), .rtc_clk(rtc_clk), .rst_n(rst_n),
        .ddr_addr(ddr_addr), .ddr_ba(ddr_ba), .ddr_bg(ddr_bg),
        .ddr_ck_p(ddr_ck_p), .ddr_ck_n(ddr_ck_n), .ddr_cke(ddr_cke), .ddr_cs_n(ddr_cs_n),
        .ddr_odt(ddr_odt), .ddr_act_n(ddr_act_n), .ddr_ras_n(ddr_ras_n), .ddr_cas_n(ddr_cas_n),
        .ddr_we_n(ddr_we_n), .ddr_reset_n(ddr_reset_n),
        .ddr_dq(ddr_dq), .ddr_dqs_p(ddr_dqs_p), .ddr_dqs_n(ddr_dqs_n),
        .pipe_clk(pipe_clk),
        .eth_tx_clk(eth_tx_clk), .eth_rx_clk(eth_rx_clk),
        .mipi_rxbyteclkhs(mipi_rxbyteclkhs),
        .hdmi_clk_pixel(hdmi_clk_pixel), .hdmi_clk_tmds(hdmi_clk_tmds),
        .hdmi_tmds_clk_p(), .hdmi_tmds_clk_n(), .hdmi_tmds_data_p(), .hdmi_tmds_data_n(),
        .ulpi_clk(ulpi_clk),
        .uart_rx(uart_rx), .uart_tx(),
        .can_tx(), .can_rx(can_rx)
    );

    // Clock Generation
    initial begin
        clk = 0; rtc_clk = 0; pcie_clk = 0; pipe_clk = 0;
        eth_tx_clk = 0; eth_rx_clk = 0; mipi_rxbyteclkhs = 0;
        hdmi_clk_pixel = 0; hdmi_clk_tmds = 0; ulpi_clk = 0;
    end
    always #2.5 clk = ~clk;             // 200 MHz core
    always #15258 rtc_clk = ~rtc_clk;   // ~32.768 kHz
    always #5.0 pcie_clk = ~pcie_clk;   // 100 MHz reference
    always #2.0 pipe_clk = ~pipe_clk;   // 250 MHz PIPE
    always #4.0 eth_tx_clk = ~eth_tx_clk; // 125 MHz
    always #4.0 eth_rx_clk = ~eth_rx_clk;
    always #1.0 mipi_rxbyteclkhs = ~mipi_rxbyteclkhs; // 500 MHz
    always #6.7 hdmi_clk_pixel = ~hdmi_clk_pixel;     // ~74.25 MHz
    always #0.67 hdmi_clk_tmds = ~hdmi_clk_tmds;      // ~742.5 MHz
    always #8.3 ulpi_clk = ~ulpi_clk;                 // 60 MHz

    // Test Sequence
    initial begin
        $display("=================================================");
        $display("SMVDU-TITAN-X SoC Integration Testbench Starting...");
        $display("=================================================");
        
        // Initialize Inputs
        rst_n = 0;
        uart_rx = 5'h1F; can_rx = 2'h3;
        
        // Reset Sequence
        #100 rst_n = 1;
        $display("[%0t] System Reset Released.", $time);
        
        // Let secure boot process (behavioral mock takes ~1000 cycles)
        #5000;
        $display("[%0t] Secure Boot assumed passed. Cores are out of reset.", $time);
        
        // Provide TRNG Seed
        #100;
        trng_seed_valid = 1;
        #10 trng_seed_valid = 0;
        $display("[%0t] TRNG Seed Provided.", $time);
        
        // Wait for system to stabilize or complete
        // We monitor the DDR memory write or UART writes
    end

    // Monitor for completion
    always @(posedge clk) begin
        // Monitor UART writes
        if (u_dut.psel_uart0 && u_dut.penable && u_dut.pwrite) begin
            $write("%c", u_dut.pwdata[7:0]);
        end
        // Monitor DDR write for completion marker
        if (u_dut.axs_wvalid[0] && u_dut.axs_wready[0]) begin
            if (u_dut.axs_wdata[0*64 +: 32] == 32'hDEADBEEF) begin
                $display("\n=================================================");
                $display("Test Passed: SoC Top Level successfully integrated and booted C code!");
                $display("=================================================");
                $finish;
            end
        end
    end

    // Safety timeout
    initial begin
        #500000;
        $display("Timeout reached!");
        $finish;
    end

endmodule
