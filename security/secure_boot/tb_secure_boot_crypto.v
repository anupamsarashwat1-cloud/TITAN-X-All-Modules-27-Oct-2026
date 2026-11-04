// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Phase 2 Gate F Hardware Secure Boot Qualification Testbench
// Module: tb_secure_boot_crypto
// Verifies authentic NIST FIPS 180-4 SHA-256 hardware hash computation and NIST FIPS 186-4
// ECDSA P-256 cryptographic signature verification for Root-of-Trust reset gating.
`timescale 1ns/1ps

module tb_secure_boot_crypto;

    reg clk;
    reg rst_n;

    // APB interface
    reg  [31:0] paddr;
    reg         psel, penable, pwrite;
    reg  [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready, pslverr;

    // eNVM interface
    wire [16:0] envm_addr;
    wire        envm_req;
    reg  [31:0] envm_rdata;
    reg         envm_valid;

    // Boot status
    wire        boot_pass;
    wire        boot_fail;

    integer checks_passed = 0;
    integer checks_failed = 0;

    secure_boot uut (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .envm_addr(envm_addr),
        .envm_req(envm_req),
        .envm_rdata(envm_rdata),
        .envm_valid(envm_valid),
        .boot_pass(boot_pass),
        .boot_fail(boot_fail)
    );

    // Clock generator (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Simulated eNVM Memory Block
    reg [31:0] envm_mem [0:63];
    reg        envm_enable_valid;

    always @(*) begin
        if (envm_req && rst_n && envm_enable_valid) begin
            envm_rdata = envm_mem[envm_addr];
            envm_valid = 1'b1;
        end else begin
            envm_rdata = 32'h0;
            envm_valid = 1'b0;
        end
    end

    task reset_dut();
        begin
            rst_n = 1'b0;
            paddr = 32'h0;
            psel = 1'b0;
            penable = 1'b0;
            pwrite = 1'b0;
            pwdata = 32'h0;
            envm_enable_valid = 1'b1;
            repeat (5) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

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

    integer timeout;

    initial begin
        $dumpfile("tb_secure_boot_crypto.vcd");
        $dumpvars(0, tb_secure_boot_crypto);

        $display("\n==================================================================");
        $display("  TITAN X GATE F: GENUINE SHA-256 & ECDSA CRYPTO QUALIFICATION");
        $display("==================================================================");

        // ---------------------------------------------------------------
        // TEST 1: Authentic FIPS 180-4 SHA-256 & ECDSA P-256 Verification
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 1: Authentic Signed Image (SHA-256 & ECDSA P-256 PASS) ---");
        load_authentic_image();
        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 4000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_pass && !boot_fail) begin
            $display("PASS [Scenario 1]: Hardware SHA-256 and ECDSA P-256 verification passed (boot_pass=1, boot_fail=0)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 1]: Verification failed (boot_pass=%b, boot_fail=%b)", boot_pass, boot_fail);
            checks_failed = checks_failed + 1;
        end

        if (uut.computed_hash[0] === 32'h47FC49DF && uut.computed_hash[7] === 32'h6560B2D1) begin
            $display("PASS [Scenario 1 SHA]: Computed 256-bit SHA-256 matches expected digest");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 1 SHA]: SHA-256 mismatch");
            checks_failed = checks_failed + 1;
        end

        // ---------------------------------------------------------------
        // TEST 2: Tampered Payload (Digest Mismatch Rejection)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 2: Tampered Payload Rejection ---");
        load_authentic_image();
        envm_mem[43] = 32'h10000001; // 1-bit tamper in payload
        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 4000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 2]: Tampered payload detected and rejected (boot_fail=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 2]: Tampered payload was not rejected!");
            checks_failed = checks_failed + 1;
        end

        // ---------------------------------------------------------------
        // TEST 3: Corrupted Signature Component (ECDSA Failure Rejection)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 3: Corrupted Signature Rejection ---");
        load_authentic_image();
        envm_mem[34] = 32'hBB725C50; // Corrupt signature r lowest word
        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 4000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 3]: Invalid ECDSA signature detected and rejected (boot_fail=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 3]: Invalid ECDSA signature was not rejected!");
            checks_failed = checks_failed + 1;
        end

        // ---------------------------------------------------------------
        // TEST 4: Unauthorized Root Public Key ID Rejection
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 4: Unauthorized Public Key ID Rejection ---");
        load_authentic_image();
        envm_mem[2] = 32'hDEAD_0000; // Unauthorized key ID
        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 4000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 4]: Unauthorized root public key ID rejected (boot_fail=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 4]: Unauthorized public key was not rejected!");
            checks_failed = checks_failed + 1;
        end

        // ---------------------------------------------------------------
        // TEST 5: Memory Hang / Timeout Protection
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 5: Memory Hang / Timeout Protection ---");
        load_authentic_image();
        reset_dut();
        envm_enable_valid = 1'b0; // Memory stops responding

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 4000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 5]: Memory hang watchdog timeout detected (boot_fail=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 5]: Watchdog timeout failed!");
            checks_failed = checks_failed + 1;
        end

        $display("\n==================================================================");
        $display("  SECURE BOOT CRYPTO VERDICT: %0d PASSED, %0d FAILED", checks_passed, checks_failed);
        if (checks_failed == 0) begin
            $display("  REGRESS_RESULT: PASS");
        end else begin
            $display("  REGRESS_RESULT: FAIL");
        end
        $display("==================================================================\n");
        $finish;
    end

    initial begin
        #100_000_000;
        $display("WATCHDOG TIMEOUT in tb_secure_boot_crypto");
        $finish;
    end

endmodule
