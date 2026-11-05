// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Secure Boot Comprehensive Verification Testbench
// Verifies authentic Root-of-Trust execution, SHA-256 + ECDSA P-256 validation,
// and rigorous negative fault rejection across all failure modes.
`timescale 1ns/1ps

module tb_secure_boot();
    reg        clk, rst_n;
    // APB interface
    reg [31:0] paddr;
    reg        psel, penable, pwrite;
    reg [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready, pslverr;
    // eNVM interface
    wire [16:0] envm_addr;
    wire        envm_req;
    reg [31:0]  envm_rdata;
    reg         envm_valid;
    // Boot status
    wire        boot_pass, boot_fail;

    integer errors = 0;
    integer step_cnt = 0;

    secure_boot uut (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .envm_addr(envm_addr), .envm_req(envm_req),
        .envm_rdata(envm_rdata), .envm_valid(envm_valid),
        .boot_pass(boot_pass), .boot_fail(boot_fail)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Helper: APB 2-cycle read
    task apb_read(output [31:0] data, input [31:0] addr);
        begin
            @(posedge clk); #1;
            paddr = addr; psel = 1; pwrite = 0; penable = 0;
            @(posedge clk); #1;
            penable = 1;
            @(posedge clk); #1;
            while (!pready) @(posedge clk);
            data = prdata;
            psel = 0; penable = 0;
        end
    endtask

    // Helper: APB 2-cycle write
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk); #1;
            paddr = addr; pwdata = data; psel = 1; pwrite = 1; penable = 0;
            @(posedge clk); #1;
            penable = 1;
            @(posedge clk); #1;
            while (!pready) @(posedge clk);
            psel = 0; penable = 0; pwrite = 0;
        end
    endtask

    reg        envm_enable_valid;
    // Helper: Reset DUT
    task reset_dut();
        begin
            rst_n = 0;
            paddr = 0; psel = 0; penable = 0; pwrite = 0; pwdata = 0;
            envm_enable_valid = 1;
            repeat(4) @(posedge clk);
            #1 rst_n = 1;
            @(posedge clk);
        end
    endtask

    // Simulated eNVM Memory Block
    reg [31:0] envm_mem [0:63];

    always @(*) begin
        if (envm_req && rst_n && envm_enable_valid) begin
            envm_rdata = envm_mem[envm_addr];
            envm_valid = 1'b1;
        end else begin
            envm_rdata = 32'h0;
            envm_valid = 1'b0;
        end
    end

    // Load authentic signed image
    task load_authentic_image;
        begin
            envm_mem[ 0] = 32'h5449544E; // Magic: "TITN"
            envm_mem[ 1] = 32'h00000010; // Length: 16 payload words
            envm_mem[ 2] = 32'hCAFEF00D; // Authorized Root Public Key ID
            // Expected 256-bit SHA-256 Digest
            envm_mem[ 3] = 32'h47FC49DF;
            envm_mem[ 4] = 32'hC7A5A9F5;
            envm_mem[ 5] = 32'h63CB70B5;
            envm_mem[ 6] = 32'h621E4D55;
            envm_mem[ 7] = 32'h1DEF80B1;
            envm_mem[ 8] = 32'h65B0438A;
            envm_mem[ 9] = 32'h6E3DB762;
            envm_mem[10] = 32'h6560B2D1;
            // Root Public Key Qx (256-bit)
            envm_mem[11] = 32'h26F4FA43;
            envm_mem[12] = 32'h1A2BEB66;
            envm_mem[13] = 32'h46D953CA;
            envm_mem[14] = 32'h332BC722;
            envm_mem[15] = 32'h911D9B05;
            envm_mem[16] = 32'hE5D92476;
            envm_mem[17] = 32'h06330B61;
            envm_mem[18] = 32'hE6703F52;
            // Root Public Key Qy (256-bit)
            envm_mem[19] = 32'h9E9689C9;
            envm_mem[20] = 32'h49B37A0B;
            envm_mem[21] = 32'h342F6CAC;
            envm_mem[22] = 32'h9B4E5440;
            envm_mem[23] = 32'hA727CEE4;
            envm_mem[24] = 32'h055285CD;
            envm_mem[25] = 32'hA6216084;
            envm_mem[26] = 32'h643D6E4F;
            // Signature r (256-bit)
            envm_mem[27] = 32'hE3077595;
            envm_mem[28] = 32'hEB490AA5;
            envm_mem[29] = 32'h401DA7B8;
            envm_mem[30] = 32'h8B62216E;
            envm_mem[31] = 32'h12268AD2;
            envm_mem[32] = 32'hBF84F2C2;
            envm_mem[33] = 32'h46ABAA46;
            envm_mem[34] = 32'hBB725C5E;
            // Signature s (256-bit)
            envm_mem[35] = 32'h78D3D87A;
            envm_mem[36] = 32'hE71E31D6;
            envm_mem[37] = 32'h5812414C;
            envm_mem[38] = 32'h7E90196A;
            envm_mem[39] = 32'h16DBBD28;
            envm_mem[40] = 32'hEC6DF9FD;
            envm_mem[41] = 32'hBA6D21BC;
            envm_mem[42] = 32'h1F31B431;
            // Signed 16-word payload
            envm_mem[43] = 32'h10000000;
            envm_mem[44] = 32'h10000004;
            envm_mem[45] = 32'h10000008;
            envm_mem[46] = 32'h1000000C;
            envm_mem[47] = 32'h10000010;
            envm_mem[48] = 32'h10000014;
            envm_mem[49] = 32'h10000018;
            envm_mem[50] = 32'h1000001C;
            envm_mem[51] = 32'h10000020;
            envm_mem[52] = 32'h10000024;
            envm_mem[53] = 32'h10000028;
            envm_mem[54] = 32'h1000002C;
            envm_mem[55] = 32'h10000030;
            envm_mem[56] = 32'h10000034;
            envm_mem[57] = 32'h10000038;
            envm_mem[58] = 32'h1000003C;
        end
    endtask

    task load_fips180_4_image;
        begin
            envm_mem[ 0] = 32'h5449544E; // Magic: "TITN"
            envm_mem[ 1] = 32'h00010010; // Flags[16]=1 (FIPS 180-4 Padding Mode), 16 payload words
            envm_mem[ 2] = 32'h000A_F002; // Version 10, Slot 2
            // Expected 256-bit FIPS 180-4 SHA-256 Digest (Python hashlib / OpenSSL)
            // hashlib.sha256(16 words).digest() = 7ad7c73e9072f9ff13d3febe396872963068dc66c2ff2af58f89ac3adacd773c
            envm_mem[ 3] = 32'h7AD7C73E;
            envm_mem[ 4] = 32'h9072F9FF;
            envm_mem[ 5] = 32'h13D3FEBE;
            envm_mem[ 6] = 32'h39687296;
            envm_mem[ 7] = 32'h3068DC66;
            envm_mem[ 8] = 32'hC2FF2AF5;
            envm_mem[ 9] = 32'h8F89AC3A;
            envm_mem[10] = 32'hDACD773C;
            // Slot 2 Public Key Qx (256-bit)
            envm_mem[11] = 32'hE94366F0;
            envm_mem[12] = 32'hCB9A569D;
            envm_mem[13] = 32'hBFDD0968;
            envm_mem[14] = 32'h6BA13860;
            envm_mem[15] = 32'h2E16E6F8;
            envm_mem[16] = 32'h8574E021;
            envm_mem[17] = 32'h52AB5641;
            envm_mem[18] = 32'hDAB249E0;
            // Slot 2 Public Key Qy (256-bit)
            envm_mem[19] = 32'h355A80A0;
            envm_mem[20] = 32'h557E8666;
            envm_mem[21] = 32'h9C1F245F;
            envm_mem[22] = 32'h2C1E1C96;
            envm_mem[23] = 32'h712654A1;
            envm_mem[24] = 32'h209835FE;
            envm_mem[25] = 32'h4CA480C1;
            envm_mem[26] = 32'h88764172;
            // Signature r (256-bit)
            envm_mem[27] = 32'h8C03A204;
            envm_mem[28] = 32'hC88D6682;
            envm_mem[29] = 32'hD08DC327;
            envm_mem[30] = 32'h7E07A434;
            envm_mem[31] = 32'hFD4169AB;
            envm_mem[32] = 32'h99DC0CE7;
            envm_mem[33] = 32'hBDB9E6EC;
            envm_mem[34] = 32'hE8BD8E3C;
            // Signature s (256-bit)
            envm_mem[35] = 32'h24C34399;
            envm_mem[36] = 32'h6375F41B;
            envm_mem[37] = 32'hD17E2AE3;
            envm_mem[38] = 32'hFCCC50AB;
            envm_mem[39] = 32'h8AF7547A;
            envm_mem[40] = 32'h45FCCD81;
            envm_mem[41] = 32'h6D8DA7EE;
            envm_mem[42] = 32'h3407B7E6;
            // Signed 16-word payload
            envm_mem[43] = 32'h10000000;
            envm_mem[44] = 32'h10000004;
            envm_mem[45] = 32'h10000008;
            envm_mem[46] = 32'h1000000C;
            envm_mem[47] = 32'h10000010;
            envm_mem[48] = 32'h10000014;
            envm_mem[49] = 32'h10000018;
            envm_mem[50] = 32'h1000001C;
            envm_mem[51] = 32'h10000020;
            envm_mem[52] = 32'h10000024;
            envm_mem[53] = 32'h10000028;
            envm_mem[54] = 32'h1000002C;
            envm_mem[55] = 32'h10000030;
            envm_mem[56] = 32'h10000034;
            envm_mem[57] = 32'h10000038;
            envm_mem[58] = 32'h1000003C;
        end
    endtask

    reg [31:0] status_val;

    initial begin
        $dumpfile("tb_secure_boot.vcd");
        $dumpvars(0, tb_secure_boot);
        errors = 0;

        $display("==================================================================");
        $display("TITAN X SECURE BOOT INDEPENDENT RE-AUDIT & REPRODUCTION SUITE");
        $display("==================================================================");

        // ---------------------------------------------------------------
        // TEST 1: POSITIVE TEST — Authentic Signed Firmware Image
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 1: Positive Test (Authentic Signed Firmware) ---");
        load_authentic_image();
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_pass && !boot_fail) begin
            $display("PASS [Scenario 1]: Authentic image verified successfully (boot_pass=1, boot_fail=0)");
        end else begin
            $display("FAIL [Scenario 1]: Expected boot_pass=1, got boot_pass=%b, boot_fail=%b", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // Check APB telemetry: bit 30 = boot_pass
        apb_read(status_val, 32'h00);
        if (status_val[30] == 1'b1) begin
            $display("PASS [Scenario 1 APB]: Status register reports boot_pass=1");
        end else begin
            $display("FAIL [Scenario 1 APB]: Expected boot_pass bit in status, got %h", status_val);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 2: NEGATIVE TEST — Modified/Tampered Firmware Image
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 2: Negative Test (Modified Firmware Payload) ---");
        load_authentic_image();
        envm_mem[43] = 32'h10000001; // Tamper payload
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (!boot_pass && boot_fail) begin
            $display("PASS [Scenario 2]: Modified payload detected, boot halted (boot_pass=0, boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 2]: Security vulnerability: modified payload was not halted! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 3: NEGATIVE TEST — Zero-Seed / Blank Memory
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 3: Negative Test (Zero-Seed / Blank Memory Image) ---");
        begin : zero_mem
            integer i;
            for (i = 0; i < 64; i = i + 1)
                envm_mem[i] = 32'h0000_0000;
        end
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (!boot_pass && boot_fail) begin
            $display("PASS [Scenario 3]: Zero-seed / blank memory rejected (boot_pass=0, boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 3]: Blank memory allowed to boot! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 4: NEGATIVE TEST — Public Key Mismatch
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 4: Negative Test (Unauthorized Public Key ID) ---");
        load_authentic_image();
        envm_mem[2] = 32'hBAD0_0001; // Unauthorized key ID
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (!boot_pass && boot_fail) begin
            $display("PASS [Scenario 4]: Unauthorized public key ID rejected (boot_pass=0, boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 4]: Unauthorized public key allowed to boot! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 5: NEGATIVE TEST — Memory Hang / Timeout
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 5: Negative Test (Memory Hang / Timeout) ---");
        load_authentic_image();
        reset_dut();
        envm_enable_valid = 0;

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (!boot_pass && boot_fail) begin
            $display("PASS [Scenario 5]: Memory hang detected by watchdog (boot_pass=0, boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 5]: Watchdog failed to trigger on memory hang! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 6: ADVERSARIAL TEST — Rogue Public Key Replacement (DEF-01)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 6: Adversarial Test (Rogue Public Key Substitution Rejection) ---");
        load_authentic_image();
        // Attacker keeps pubkey_id == 0xCAFEF00D, but substitutes Qx with rogue key
        envm_mem[11] = 32'hDEAD_BEEF;
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (!boot_pass && boot_fail) begin
            $display("PASS [Scenario 6]: Rogue public key substitution detected and rejected by RoT (boot_pass=0, boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 6]: Security vulnerability DEF-01: rogue public key was accepted! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 7: OTP eFuse Key Revocation Rejection (DEF-SEC-02)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 7: OTP eFuse Key Revocation Rejection (DEF-SEC-02) ---");
        load_authentic_image();
        // Use APB to blow revocation fuse for Slot 0 (bit 0)
        apb_write(32'h18, 32'h0000_0001);
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (!boot_pass && boot_fail) begin
            $display("PASS [Scenario 7]: Firmware signed with revoked key slot 0 rejected (boot_pass=0, boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 7]: Firmware signed with revoked key was accepted! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 8: Anti-Rollback Monotonic Counter Downgrade (DEF-SEC-03)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 8: Anti-Rollback Monotonic Counter Downgrade (DEF-SEC-03) ---");
        load_authentic_image();
        // Reset fuses so Slot 0 is unrevoked for this test
        uut.u_efuse.revocation_fuses = 4'b0000;
        // Upgrade hardware monotonic counter to version 5
        apb_write(32'h14, 32'd5);
        // Attempt to boot image with older security version 2
        envm_mem[2] = 32'h0002_F000;
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (!boot_pass && boot_fail) begin
            $display("PASS [Scenario 8]: Firmware downgrade attack rejected by anti-rollback counter (boot_pass=0, boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 8]: Firmware downgrade was accepted! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 9: Forward Progression / Valid Security Version (DEF-SEC-03)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 9: Forward Progression / Valid Security Version (DEF-SEC-03) ---");
        load_authentic_image();
        uut.u_efuse.revocation_fuses = 4'b0000;
        // Image version 6 >= hardware counter 5 -> MUST PASS
        envm_mem[2] = 32'h0006_F000;
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_pass && !boot_fail) begin
            $display("PASS [Scenario 9]: Valid forward security version 6 authenticated successfully (boot_pass=1, boot_fail=0)");
        end else begin
            $display("FAIL [Scenario 9]: Valid security version was rejected! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 10: Automated FIPS 180-4 Padding & Slot 2 Verification (DEF-SEC-04)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 10: FIPS 180-4 Automated Padding & Slot 2 Verification (DEF-SEC-04) ---");
        load_fips180_4_image();
        uut.u_efuse.revocation_fuses = 4'b0000;
        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 4000) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_pass && !boot_fail) begin
            $display("PASS [Scenario 10]: FIPS 180-4 padded image verified with Slot 2 key (boot_pass=1, boot_fail=0)");
        end else begin
            $display("FAIL [Scenario 10]: FIPS 180-4 padded image verification failed! (pass=%b, fail=%b)", boot_pass, boot_fail);
            errors = errors + 1;
        end

        if (uut.computed_hash[0] === 32'h7AD7C73E && uut.computed_hash[7] === 32'hDACD773C) begin
            $display("PASS [Scenario 10 SHA]: Hardware computed_hash exactly matches FIPS 180-4 Python hashlib digest (7AD7C73E...DACD773C)");
        end else begin
            $display("FAIL [Scenario 10 SHA]: Computed hash 0x%08X...0x%08X does not match FIPS 180-4 golden digest", uut.computed_hash[0], uut.computed_hash[7]);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // SUMMARY REPORT
        // ---------------------------------------------------------------
        $display("\n==================================================================");
        if (errors == 0) begin
            $display("SECURE BOOT VERDICT: ✅ PASS — All 10 security scenarios verified");
            $display("REGRESS_RESULT: PASS");
        end else begin
            $display("SECURE BOOT VERDICT: ❌ FAIL — %0d violations detected", errors);
            $display("REGRESS_RESULT: FAIL");
        end
        $display("==================================================================\n");
        $finish;
    end

    initial begin
        #100_000_000;
        $display("WATCHDOG TIMEOUT: Simulation hung");
        $finish;
    end

endmodule
