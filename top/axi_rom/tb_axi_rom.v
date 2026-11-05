// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — AXI Read-Only Boot ROM Directed Self-Checking Testbench
// Validates Hardware Root-of-Trust coupling, pre-boot direct authentication port,
// and AXI read-lock enforcement prior to boot_pass assertion.
`timescale 1ns/1ps

module tb_axi_rom();

    parameter AW = 40;
    parameter DW = 64;
    parameter IDW = 4;
    parameter DEPTH = 1024;
    parameter PAYLOAD_OFFSET = 43;

    reg             clk;
    reg             rst_n;
    reg             boot_pass;

    // Pre-boot port
    reg             rom_preboot_en;
    reg  [16:0]     rom_preboot_addr;
    wire [31:0]     rom_preboot_rdata;
    wire            rom_preboot_valid;

    // AXI4 Read-Only Slave Interface
    reg             s_arvalid;
    wire            s_arready;
    reg  [AW-1:0]   s_araddr;
    reg  [IDW-1:0]  s_arid;
    wire            s_rvalid;
    reg             s_rready;
    wire [DW-1:0]   s_rdata;
    wire [1:0]      s_rresp;
    wire            s_rlast;
    wire [IDW-1:0]  s_rid;

    integer pass_count = 0;
    integer fail_count = 0;

    // DUT Instantiation
    axi_rom #(
        .DEPTH(DEPTH),
        .AW(AW),
        .DW(DW),
        .IDW(IDW),
        .PAYLOAD_OFFSET(PAYLOAD_OFFSET)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .boot_pass(boot_pass),
        .rom_preboot_en(rom_preboot_en),
        .rom_preboot_addr(rom_preboot_addr),
        .rom_preboot_rdata(rom_preboot_rdata),
        .rom_preboot_valid(rom_preboot_valid),
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_araddr(s_araddr),
        .s_arid(s_arid),
        .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .s_rlast(s_rlast),
        .s_rid(s_rid)
    );

    always #5.0 clk = ~clk;

    task check(input [255:0] test_name, input condition);
        begin
            if (condition) begin
                $display("PASS [%0t] %0s", $time, test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0t] %0s", $time, test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        boot_pass = 0;
        rom_preboot_en = 0;
        rom_preboot_addr = 0;
        s_arvalid = 0;
        s_araddr = 0;
        s_arid = 0;
        s_rready = 0;

        #25;
        // Test 1: Reset active - AXI slave locked
        check("TEST 1: Reset state - s_arready=0, s_rvalid=0, s_rlast=0", 
              (s_arready == 1'b0) && (s_rvalid == 1'b0) && (s_rlast == 1'b0));

        rst_n = 1;
        repeat (3) @(posedge clk);

        // Test 2: Pre-boot RoT Authentication Port Reads
        rom_preboot_en = 1;
        rom_preboot_addr = 17'd0; // Magic "TITN"
        #1;
        check("TEST 2: Pre-boot read word 0 returns Magic 0x5449544E", rom_preboot_rdata == 32'h5449544E && rom_preboot_valid == 1);

        rom_preboot_addr = 17'd1; // Image length = 16
        #1;
        check("TEST 3: Pre-boot read word 1 returns Image Length 16", rom_preboot_rdata == 32'h00000010);

        rom_preboot_addr = 17'd2; // Key ID = 0xCAFEF00D
        #1;
        check("TEST 4: Pre-boot read word 2 returns Key ID 0xCAFEF00D", rom_preboot_rdata == 32'hCAFEF00D);

        rom_preboot_addr = 17'd43; // First payload word
        #1;
        check("TEST 5: Pre-boot read word 43 returns Payload[0] 0x10000000", rom_preboot_rdata == 32'h10000000);
        rom_preboot_en = 0;

        // Test 6: AXI Bus Lock Enforcement (boot_pass == 0)
        @(posedge clk);
        s_araddr <= 40'h00_0000_0000;
        s_arid   <= 4'h1;
        s_arvalid <= 1'b1;
        s_rready  <= 1'b1;
        repeat (5) @(posedge clk);
        check("TEST 6: AXI Bus locked while boot_pass=0 (s_arready stays 0)", s_arready == 1'b0 && s_rvalid == 1'b0);
        s_arvalid <= 1'b0;
        s_rready <= 1'b0;

        // Test 7: Assert boot_pass=1 (Authentication Successful)
        @(posedge clk);
        boot_pass <= 1'b1;
        @(posedge clk);
        #1;
        check("TEST 7: AXI Bus unlocked upon boot_pass=1 (s_arready asserts 1)", s_arready == 1'b1);

        // Test 8: Read CPU address 0x0 (translates to verified payload at word 43)
        @(posedge clk);
        s_araddr <= 40'h00_0000_0000;
        s_arid   <= 4'h1;
        s_arvalid <= 1'b1;
        s_rready  <= 1'b0;
        while (!s_arready) @(posedge clk);
        @(posedge clk);
        s_arvalid <= 1'b0;
        while (!s_rvalid) @(posedge clk);
        #1;
        check("TEST 8: CPU fetch 0x0 returns payload words 44:43", s_rdata == {32'h10000004, 32'h10000000});
        check("TEST 9: AXI ID tag forwarded correctly (s_rid=1)", s_rid == 4'h1);
        check("TEST 10: AXI response is OKAY (s_rresp=2'b00)", s_rresp == 2'b00);
        check("TEST 11: Burst last asserted (s_rlast=1)", s_rlast == 1'b1);
        @(posedge clk);
        s_rready <= 1'b1;
        @(posedge clk);
        s_rready <= 1'b0;

        // Test 12: Read CPU address 0x8 (translates to payload words 46:45)
        @(posedge clk);
        s_araddr <= 40'h00_0000_0008;
        s_arid   <= 4'h5;
        s_arvalid <= 1'b1;
        while (!s_arready) @(posedge clk);
        @(posedge clk);
        s_arvalid <= 1'b0;
        while (!s_rvalid) @(posedge clk);
        #1;
        check("TEST 12: CPU fetch 0x8 returns payload words 46:45", s_rdata == {32'h1000000C, 32'h10000008});
        check("TEST 13: AXI ID tag forwarded correctly (s_rid=5)", s_rid == 4'h5);
        check("TEST 14: Burst last asserted on word 1", s_rlast == 1'b1);
        @(posedge clk);
        s_rready <= 1'b1;
        @(posedge clk);
        s_rready <= 1'b0;

        // Test 15: Bus returns to ready state after read completion
        #1;
        check("TEST 15: Bus returns to ready state after read completion", 
              (s_arready == 1'b1) && (s_rvalid == 1'b0));

        $display("\n==============================");
        if (fail_count == 0 && pass_count >= 15) begin
            $display("AXI_ROM VERDICT: PASS - All %0d tests green", pass_count);
        end else begin
            $display("AXI_ROM VERDICT: FAIL - %0d failed, %0d passed", fail_count, pass_count);
        end
        $display("==============================\n");
        $finish;
    end

endmodule
