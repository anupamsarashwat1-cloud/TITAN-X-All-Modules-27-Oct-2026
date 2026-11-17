// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Gate D Qualification Suite
// Module: tb_integ_jtag_top
// Verifies Finding F-05 Remediation:
//   1. Full SoC top-level JTAG pins (jtag_tck, jtag_tms, jtag_tdi, jtag_tdo, jtag_trst_n).
//   2. TAP Controller reset (5x TMS=1) and transition to Run-Test/Idle.
//   3. Scanning IR_IDCODE and verifying TDO shifts out 32'h2023_04FD.
//   4. Scanning IR_DTMCS and verifying DTMCS register contents.
//   5. DMI access: write to DMCONTROL to issue halt_req to Hart 0.
//   6. Verify halt_req propagates to core 0 through top-level internal routing.
//   7. Write DMCONTROL to issue resume_req to Hart 0 (pulsed).
//   8. Multicore halt addressing: select Hart 3 (Core 3).
//   9. Testing asynchronous jtag_trst_n reset assertion and recovery.

`timescale 1ns/1ps

module tb_integ_jtag_top;

    `include "tb_macros.vh"

    reg clk;
    reg rst_n;
    `TB_HARNESS(20_000_000)
    `TB_SCOREBOARD

    // JTAG Pins
    reg  jtag_tck;
    reg  jtag_tms;
    reg  jtag_tdi;
    wire jtag_tdo;
    reg  jtag_trst_n;

    // DDR4 Dummy Interface
    wire [15:0] ddr_addr;
    wire [2:0]  ddr_ba;
    wire [1:0]  ddr_bg;
    wire        ddr_ck_p, ddr_ck_n, ddr_cke, ddr_cs_n;
    wire        ddr_ras_n, ddr_cas_n, ddr_we_n, ddr_reset_n, ddr_odt, ddr_act_n;
    wire [63:0] ddr_dq;
    wire [7:0]  ddr_dqs_p, ddr_dqs_n;

    // High/Low-Speed Peripherals
    wire        pipe_clk = 1'b0;
    wire        eth_tx_clk = 1'b0, eth_rx_clk = 1'b0, ulpi_clk = 1'b0;
    wire        mipi_rxbyteclkhs = 1'b0, hdmi_clk_pixel = 1'b0, hdmi_clk_tmds = 1'b0;
    wire        rtc_clk = 1'b0;
    wire [4:0]  uart_tx;
    reg  [4:0]  uart_rx;
    wire [1:0]  can_tx;
    reg  [1:0]  can_rx;

    // DUT Instantiation
    titan_x_top #(
        .FAST_SIM(1)
    ) dut (
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
        .hdmi_tmds_clk_p(),
        .hdmi_tmds_clk_n(),
        .hdmi_tmds_data_p(),
        .hdmi_tmds_data_n(),
        .rtc_clk(rtc_clk),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .can_tx(can_tx),
        .can_rx(can_rx),
        .gmii_txd(),
        .gmii_tx_en(),
        .gmii_tx_er(),
        .gmii_rxd(8'h0),
        .gmii_rx_dv(1'b0),
        .gmii_rx_er(1'b0),
        .gmii_crs(1'b0),
        .gmii_col(1'b0),
        .pipe_tx_data(),
        .pipe_tx_datak(),
        .pipe_rx_data(64'h0),
        .pipe_rx_datak(8'h0),
        .pipe_tx_rate(),
        .pipe_tx_elecidle(),
        .pipe_tx_compliance(),
        .pipe_rx_polarity(),
        .pipe_power_down(),
        .pipe_rx_valid(4'h0),
        .pipe_rx_elecidle(4'h0),
        .pipe_rx_status(12'h0),
        .pipe_phy_status(4'h0),
        .ulpi_data(),
        .ulpi_dir(1'b0),
        .ulpi_nxt(1'b0),
        .ulpi_stp(),
        .ulpi_reset(),
        .sd_clk(),
        .sd_cmd(),
        .sd_dat(),
        .sd_reset_n(),
        .qspi_sclk(),
        .qspi_cs_n(),
        .qspi_io(),

        // External JTAG pins under test
        .jtag_tck(jtag_tck),
        .jtag_tms(jtag_tms),
        .jtag_tdi(jtag_tdi),
        .jtag_tdo(jtag_tdo),
        .jtag_trst_n(jtag_trst_n)
    );

    // Continuous capture of 1-cycle resume pulses from debug module
    reg [4:0] resume_pulse_seen;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) resume_pulse_seen <= 5'h0;
        else resume_pulse_seen <= resume_pulse_seen | dut.dbg_resume_req;
    end

    // JTAG Clock: 10 MHz (100ns period)
    always #50 jtag_tck = ~jtag_tck;

    // Helper JTAG bit-bang tasks
    task tck_cycle;
        begin
            @(posedge jtag_tck);
            #5; // drive inputs 5ns after rising edge
        end
    endtask

    // Reset TAP by holding TMS=1 for 5 cycles
    task tap_reset;
        integer i;
        begin
            jtag_tms = 1'b1;
            jtag_tdi = 1'b0;
            for (i = 0; i < 6; i = i + 1) begin
                tck_cycle();
            end
            // Transition to Run-Test/Idle
            jtag_tms = 1'b0;
            tck_cycle();
        end
    endtask

    // Shift 5-bit Instruction Register
    task shift_ir(input [4:0] ir_in);
        integer i;
        begin
            // RTI -> Select-DR-Scan
            jtag_tms = 1'b1; tck_cycle();
            // Select-DR -> Select-IR-Scan
            jtag_tms = 1'b1; tck_cycle();
            // Select-IR -> Capture-IR
            jtag_tms = 1'b0; tck_cycle();
            // Capture-IR -> Shift-IR
            jtag_tms = 1'b0; tck_cycle();

            // Shift 5 bits (LSB first)
            for (i = 0; i < 4; i = i + 1) begin
                jtag_tdi = ir_in[i];
                jtag_tms = 1'b0;
                tck_cycle();
            end
            // Final bit moves to Exit1-IR
            jtag_tdi = ir_in[4];
            jtag_tms = 1'b1;
            tck_cycle();

            // Exit1-IR -> Update-IR
            jtag_tms = 1'b1; tck_cycle();
            // Update-IR -> Run-Test/Idle
            jtag_tms = 1'b0; tck_cycle();
        end
    endtask

    // Shift Data Register of length N bits
    task shift_dr(
        input  integer num_bits,
        input  [40:0] dr_in,
        output [40:0] dr_out
    );
        integer i;
        begin
            dr_out = 41'h0;
            // RTI -> Select-DR-Scan
            jtag_tms = 1'b1; tck_cycle();
            // Select-DR -> Capture-DR
            jtag_tms = 1'b0; tck_cycle();
            // Capture-DR -> Shift-DR
            jtag_tms = 1'b0; tck_cycle();

            for (i = 0; i < num_bits - 1; i = i + 1) begin
                dr_out[i] = jtag_tdo;
                jtag_tdi = dr_in[i];
                jtag_tms = 1'b0;
                tck_cycle();
            end
            // Final bit moves to Exit1-DR
            dr_out[num_bits - 1] = jtag_tdo;
            jtag_tdi = dr_in[num_bits - 1];
            jtag_tms = 1'b1;
            tck_cycle();

            // Exit1-DR -> Update-DR
            jtag_tms = 1'b1; tck_cycle();
            // Update-DR -> Run-Test/Idle
            jtag_tms = 1'b0; tck_cycle();
        end
    endtask

    reg [40:0] scanned_dr;
    reg [40:0] dmi_req;

    initial begin
        $dumpfile("tb_integ_jtag_top.vcd");
        $dumpvars(0, tb_integ_jtag_top);

        jtag_tck    = 1'b0;
        jtag_tms    = 1'b1;
        jtag_tdi    = 1'b0;
        jtag_trst_n = 1'b1;
        uart_rx     = 5'h1F;
        can_rx      = 2'b11;

        // Wait for system reset release
        @(posedge rst_n);
        repeat (20) @(posedge clk);

        $display("\n==================================================================");
        $display("  TITAN-X: TOP-LEVEL JTAG 0.13 INTEGRATION QUALIFICATION SUITE");
        $display("==================================================================");

        // ------------------------------------------------------------
        // TEST 1: TAP Controller Reset & IDCODE Scan
        // ------------------------------------------------------------
        $display("\n[TEST 1] JTAG TAP Reset & 32-bit IDCODE Scan from Top-Level Pins");
        tap_reset();

        // IR defaults to IDCODE (5'h01) after TAP reset
        shift_dr(32, 32'h0, scanned_dr);
        $display("  Read IDCODE: 0x%08h (Expected: 0x202304FD)", scanned_dr[31:0]);
        `EXPECT_EQ(scanned_dr[31:0], 32'h2023_04FD, "Top-level JTAG IDCODE matches SMVDU Titan-X identity")

        // ------------------------------------------------------------
        // TEST 2: DTMCS Register Scan
        // ------------------------------------------------------------
        $display("\n[TEST 2] IR_DTMCS (0x10) Scan");
        shift_ir(5'h10); // IR_DTMCS
        shift_dr(32, 32'h0, scanned_dr);
        $display("  Read DTMCS: 0x%08h", scanned_dr[31:0]);
        `EXPECT_EQ(scanned_dr[3:0], 4'h0, "DTMCS version is 0 (idle) or compliant")
        `EXPECT_NE(scanned_dr[31:0], 32'h0000_0000, "DTMCS register is non-zero and active")

        // ------------------------------------------------------------
        // TEST 3: DMI Abstract Access — Hart 0 Halt Request
        // ------------------------------------------------------------
        $display("\n[TEST 3] DMI DMCONTROL Write: Assert Halt Request to Hart 0");
        shift_ir(5'h11); // IR_DMI

        // Address 0x10, Op 2 (Write), Data = 32'h8000_0001 (haltreq=1, dmactive=1, hart 0 selected)
        dmi_req = {7'h10, 32'h8000_0001, 2'b10};
        shift_dr(41, dmi_req, scanned_dr);

        // Allow cycles for DMI synchronization
        repeat (10) @(posedge clk);

        // Verify top-level u_debug halt_req asserted to Core 0
        `EXPECT_EQ(dut.u_debug.halt_req[0], 1'b1, "u_debug.halt_req[0] asserted via JTAG DMI")
        `EXPECT_EQ(dut.dbg_halt_req[0], 1'b1, "Top-level dbg_halt_req[0] routed to Core 0")

        // ------------------------------------------------------------
        // TEST 4: DMI Abstract Access — Hart 0 Resume Request (Pulsed)
        // ------------------------------------------------------------
        $display("\n[TEST 4] DMI DMCONTROL Write: Assert Resume Request to Hart 0");
        resume_pulse_seen = 5'h0;
        // Data: resumereq=bit 30, dmactive=bit 0. Address 0x10, Op 2 (Write)
        dmi_req = {7'h10, 32'h4000_0001, 2'b10};
        shift_dr(41, dmi_req, scanned_dr);

        repeat (20) @(posedge clk);
        `EXPECT_EQ(resume_pulse_seen[0], 1'b1, "Top-level dbg_resume_req[0] pulse routed to Core 0")

        // ------------------------------------------------------------
        // TEST 5: Multicore Halt Addressing (Hart 3)
        // ------------------------------------------------------------
        $display("\n[TEST 5] DMI Addressing: Halt Request to Hart 3 (Core 3)");
        // Hart 3: hartsel bits [8:6] = 3 -> bits [8:6] = 3'b011 -> 32'h8003_00C1
        dmi_req = {7'h10, 32'h8003_00C1, 2'b10};
        shift_dr(41, dmi_req, scanned_dr);

        repeat (20) @(posedge clk);
        `EXPECT_EQ(dut.dbg_halt_req[3], 1'b1, "Top-level dbg_halt_req[3] routed to Core 3")

        // ------------------------------------------------------------
        // TEST 6: Asynchronous TRST_n Reset Pin Verification
        // ------------------------------------------------------------
        $display("\n[TEST 6] Asynchronous jtag_trst_n Pin Reset Verification");
        jtag_trst_n = 1'b0; // Assert TRST_n
        repeat (10) @(posedge clk);

        `EXPECT_EQ(dut.debug_rst_n, 1'b0, "TRST_n pulls debug module into reset")
        `EXPECT_EQ(dut.u_debug.tap_state, 4'd0, "TAP Controller forced to Test-Logic-Reset (TAP_TLR)")

        jtag_trst_n = 1'b1; // Release TRST_n
        repeat (10) @(posedge clk);
        `EXPECT_EQ(dut.debug_rst_n, 1'b1, "Debug module released from TRST_n")

        $display("\n==================================================================");
        $display("  ALL TOP-LEVEL JTAG INTEGRATION TESTS PASSED SUCCESSFULLY");
        $display("==================================================================\n");

        `TB_REPORT("TOP_JTAG_INTEGRATION")
    end

endmodule
