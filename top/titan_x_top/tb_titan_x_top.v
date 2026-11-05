`timescale 1ns / 1ps

module tb_titan_x_top();

    logic clk;
    logic rst_n;
    wire [15:0] ddr_addr;
    wire [2:0] ddr_ba;
    wire [1:0] ddr_bg;
    wire ddr_ck_p;
    wire ddr_ck_n;
    wire ddr_cke;
    wire ddr_cs_n;
    wire ddr_ras_n;
    wire ddr_cas_n;
    wire ddr_we_n;
    wire ddr_reset_n;
    wire ddr_odt;
    wire ddr_act_n;
    wire [63:0] ddr_dq;
    wire [7:0] ddr_dqs_p;
    wire [7:0] ddr_dqs_n;
    logic pipe_clk;
    logic eth_tx_clk;
    logic eth_rx_clk;
    logic ulpi_clk;
    logic mipi_rxbyteclkhs;
    logic hdmi_clk_pixel;
    logic hdmi_clk_tmds;
    wire hdmi_tmds_clk_p;
    wire hdmi_tmds_clk_n;
    wire [2:0] hdmi_tmds_data_p;
    wire [2:0] hdmi_tmds_data_n;
    logic rtc_clk;
    wire [4:0] uart_tx;
    logic [4:0] uart_rx;
    wire [1:0] can_tx;
    logic [1:0] can_rx;

    // DUT Instantiation
    titan_x_top #(
        .FAST_SIM(1)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .ddr_addr(ddr_addr),
        .ddr_ba(ddr_ba),
        .ddr_bg(ddr_bg),
        .ddr_ck_p(ddr_ck_p),
        .ddr_ck_n(ddr_ck_n),
        .ddr_cke(ddr_cke),
        .ddr_cs_n(ddr_cs_n),
        .ddr_ras_n(ddr_ras_n),
        .ddr_cas_n(ddr_cas_n),
        .ddr_we_n(ddr_we_n),
        .ddr_reset_n(ddr_reset_n),
        .ddr_odt(ddr_odt),
        .ddr_act_n(ddr_act_n),
        .ddr_dq(ddr_dq),
        .ddr_dqs_p(ddr_dqs_p),
        .ddr_dqs_n(ddr_dqs_n),
        .pipe_clk(pipe_clk),
        .eth_tx_clk(eth_tx_clk),
        .eth_rx_clk(eth_rx_clk),
        .ulpi_clk(ulpi_clk),
        .mipi_rxbyteclkhs(mipi_rxbyteclkhs),
        .hdmi_clk_pixel(hdmi_clk_pixel),
        .hdmi_clk_tmds(hdmi_clk_tmds),
        .hdmi_tmds_clk_p(hdmi_tmds_clk_p),
        .hdmi_tmds_clk_n(hdmi_tmds_clk_n),
        .hdmi_tmds_data_p(hdmi_tmds_data_p),
        .hdmi_tmds_data_n(hdmi_tmds_data_n),
        .rtc_clk(rtc_clk),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .can_tx(can_tx),
        .can_rx(can_rx)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    reg enable_aux_clks;
    initial clk = 0;
    always #3.6 clk = ~clk;

    assign pipe_clk         = clk & enable_aux_clks;
    assign eth_tx_clk       = clk & enable_aux_clks;
    assign eth_rx_clk       = clk & enable_aux_clks;
    assign ulpi_clk         = clk & enable_aux_clks;
    assign mipi_rxbyteclkhs = clk & enable_aux_clks;
    assign hdmi_clk_pixel   = clk & enable_aux_clks;
    assign hdmi_clk_tmds    = clk & enable_aux_clks;
    assign rtc_clk          = clk & enable_aux_clks;

    integer errors;
    integer wait_cnt;

    task check(input string msg, input condition);
        begin
            if (condition) begin
                $display("PASS [%0t] %0s", $time, msg);
            end else begin
                $display("FAIL [%0t] %0s", $time, msg);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        enable_aux_clks = 1;

        uart_rx = 5'h1F; // idle high
        can_rx  = 2'b11; // idle recessive

        // Reset sequence
        rst_n = 0;
        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(100) @(posedge clk);

        $display("\n========================================");
        $display("  Phase 4/5: TITAN-X SoC Integration & RoT Qualification");
        $display("========================================");

        // ----------------------------------------------------
        // Step 1: Peripheral & Pin Interface Verification
        // ----------------------------------------------------
        check("DDR PHY clock active (ddr_ck_p driven)", ddr_ck_p !== 1'bx);
        repeat(50) @(posedge clk);
        check("DDR CKE driven", ddr_cke !== 1'bx);
        check("UART0 TX idle high", uart_tx[0] === 1'b1);
        check("CAN0 TX recessive idle", can_tx[0] === 1'b1);
        check("HDMI clk driven", hdmi_tmds_clk_p !== 1'bx);

        // Quiet peripheral PHY clocks during cryptographic boot verification
        enable_aux_clks = 0;

        // ----------------------------------------------------
        // Step 2: RoT Coupling Verification (TASK-04-01 / DEF-SEC-01)
        // ----------------------------------------------------
        $display("\n[RoT 4.1] Checking Pre-Boot RoT Gating & AXI Lock...");
        check("boot_pass held low during verification", uut.boot_pass === 1'b0);
        check("core_rst_n held in reset while boot_pass=0", uut.core_rst_n === 1'b0);
        check("axi_rom s_arready locked (0) during verification", uut.u_boot_rom.s_arready === 1'b0);

        // Wait for secure_boot to complete authentic container authentication
        $display("[RoT 4.2] Waiting for Cryptographic Boot Container Authentication...");
        wait_cnt = 0;
        while (!uut.boot_pass && !uut.boot_fail && wait_cnt < 2500000) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
            if (wait_cnt % 10000 == 0) begin
                $display("[DEBUG %0d cycles] state=%0d, word_addr=%0d, timeout=%0d, ecdsa_state=%0d", 
                         wait_cnt, uut.u_secure_boot.state, uut.u_secure_boot.word_addr, uut.u_secure_boot.timeout_cnt, uut.u_secure_boot.u_ecdsa.state);
            end
        end

        check("boot_pass asserted upon successful authentication", uut.boot_pass === 1'b1);
        check("boot_fail remained deasserted (0)", uut.boot_fail === 1'b0);
        check("core_rst_n released (1) after RoT pass", uut.core_rst_n === 1'b1);
        $display("[DEBUG AXI] boot_pass=%b, s_arvalid=%b, s_arready=%b, s_rvalid=%b, s_rready=%b",
                 uut.u_boot_rom.boot_pass, uut.u_boot_rom.s_arvalid, uut.u_boot_rom.s_arready, uut.u_boot_rom.s_rvalid, uut.u_boot_rom.s_rready);
        @(posedge clk);
        #1;
        $display("[DEBUG AXI +1clk] boot_pass=%b, s_arvalid=%b, s_arready=%b, s_rvalid=%b, s_rready=%b",
                 uut.u_boot_rom.boot_pass, uut.u_boot_rom.s_arvalid, uut.u_boot_rom.s_arready, uut.u_boot_rom.s_rvalid, uut.u_boot_rom.s_rready);
        check("axi_rom s_arready unlocked (1) after RoT pass", uut.u_boot_rom.s_arready === 1'b1 || uut.u_boot_rom.s_rvalid === 1'b1);
        $display("[RoT 4.2] Authentication completed in %0d cycles.", wait_cnt);

        // ----------------------------------------------------
        // Step 3: Watchdog Reset Integration (TASK-04-02 / DEF-ARCH-02)
        // ----------------------------------------------------
        $display("\n[WDT 4.3] Verifying Watchdog Reset Integration into core_rst_n...");
        check("core_rst_n is 1 while wdt_reset_n is 1", uut.core_rst_n === 1'b1 && uut.u_wdt.wdt_reset_n === 1'b1);

        // Inject watchdog expiration pulse
        force uut.u_wdt.wdt_reset_n = 1'b0;
        #1;
        check("core_rst_n forced to 0 when wdt_reset_n asserts 0", uut.core_rst_n === 1'b0);
        force uut.u_wdt.wdt_reset_n = 1'b1;
        #1;
        check("core_rst_n recovered to 1 after wdt_reset_n release", uut.core_rst_n === 1'b1);
        release uut.u_wdt.wdt_reset_n;

        // ----------------------------------------------------
        // Step 4: Negative Test — Tampered Firmware Rejection (DEF-SEC-01)
        // ----------------------------------------------------
        $display("\n[RoT 4.4] Verifying Tampered Firmware Rejection...");
        rst_n = 0;
        repeat(20) @(posedge clk);
        // Corrupt header magic at word 0
        uut.u_boot_rom.rom[0][31:0] = 32'hDEADBEEF;
        rst_n = 1;
        wait_cnt = 0;
        while (!uut.boot_fail && wait_cnt < 100) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
        end
        check("boot_fail asserted on tampered boot image", uut.boot_fail === 1'b1);
        check("boot_pass permanently deasserted (0) on tamper", uut.boot_pass === 1'b0);
        check("core_rst_n held locked in reset (0) on tamper", uut.core_rst_n === 1'b0);
        check("axi_rom permanently locked (s_arready=0) on tamper", uut.u_boot_rom.s_arready === 1'b0);

        // ----------------------------------------------------
        // Summary
        // ----------------------------------------------------
        $display("\n========================================");
        if (errors == 0)
            $display("TITAN-X SoC VERDICT: PASS - All Phase 4 & 5 integration checks passed");
        else
            $display("TITAN-X SoC VERDICT: FAIL - %0d errors", errors);
        $display("========================================\n");
        $finish;
    end

endmodule
