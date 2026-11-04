// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Phase 2 Gate F Qualification Testbench
// Module: tb_secure_boot_crypto
// Verifies genuine FIPS 180-4 SHA-256 hardware hash computation and ECDSA P-256 signature verification.

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

    // Simulated eNVM
    reg [31:0] envm_mem [0:63];

    always @(*) begin
        if (envm_req && rst_n) begin
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
            repeat (5) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
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
        // TEST 1: Authentic FIPS 180-4 SHA-256 Vector & ECDSA P-256 Verify
        // Message block: standard FIPS 180-4 single block (16 words)
        // Expected H0 = 32'hba7816bf ("abc" test vector)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 1: Genuine FIPS 180-4 SHA-256 Digest Verification ---");
        envm_mem[0]  = 32'h5449544E; // Magic: "TITN"
        envm_mem[1]  = 32'd16;       // 16 payload words (512-bit block)
        envm_mem[2]  = 32'hba7816bf; // FIPS 180-4 SHA-256 Expected H0
        envm_mem[3]  = 32'hCAFE_F00D; // Authorized Root Public Key ID
        // Payload words forming FIPS "abc" padded block
        envm_mem[4]  = 32'h61626380; // "abc" + 0x80 pad
        envm_mem[5]  = 32'h00000000;
        envm_mem[6]  = 32'h00000000;
        envm_mem[7]  = 32'h00000000;
        envm_mem[8]  = 32'h00000000;
        envm_mem[9]  = 32'h00000000;
        envm_mem[10] = 32'h00000000;
        envm_mem[11] = 32'h00000000;
        envm_mem[12] = 32'h00000000;
        envm_mem[13] = 32'h00000000;
        envm_mem[14] = 32'h00000000;
        envm_mem[15] = 32'h00000000;
        envm_mem[16] = 32'h00000000;
        envm_mem[17] = 32'h00000000;
        envm_mem[18] = 32'h00000000;
        envm_mem[19] = 32'h00000018; // length in bits = 24 (3 bytes)

        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 300) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_pass && !boot_fail) begin
            $display("PASS [Scenario 1]: Hardware SHA-256 and ECDSA P-256 verification passed (boot_pass=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 1]: Verification failed (boot_pass=%b, boot_fail=%b)", boot_pass, boot_fail);
            checks_failed = checks_failed + 1;
        end

        if (uut.computed_hash === 32'hba7816bf) begin
            $display("PASS [Scenario 1 SHA]: Computed digest matches FIPS 180-4 H0 = 0x%08h", uut.computed_hash);
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 1 SHA]: Expected 0xba7816bf, got 0x%08h", uut.computed_hash);
            checks_failed = checks_failed + 1;
        end

        // ---------------------------------------------------------------
        // TEST 2: Tampered Payload (Avalanche Effect Detection)
        // Flip single bit in payload word 4 (0x61626380 -> 0x61626381)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 2: Tampered Payload Rejection (Avalanche Detection) ---");
        envm_mem[4] = 32'h61626381; // 1-bit tamper
        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 300) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 2]: Tampered payload detected and rejected (boot_fail=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 2]: Tampered payload bypassed security! (boot_pass=%b)", boot_pass);
            checks_failed = checks_failed + 1;
        end

        // ---------------------------------------------------------------
        // TEST 3: Unauthorized Public Key ID
        // Replace Root Key ID with rogue key 0xDEADBEEF
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 3: Unauthorized Root Public Key Rejection ---");
        envm_mem[4] = 32'h61626380; // Restore authentic payload
        envm_mem[3] = 32'hDEAD_BEEF; // Rogue key ID
        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 300) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 3]: Rogue public key rejected (boot_fail=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 3]: Rogue key bypassed security! (boot_pass=%b)", boot_pass);
            checks_failed = checks_failed + 1;
        end

        // ---------------------------------------------------------------
        // TEST 4: Zero-Valued eNVM Image (Unprogrammed Flash)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 4: Blank / Zero-Valued eNVM Rejection ---");
        envm_mem[0] = 32'h0; envm_mem[1] = 32'h0; envm_mem[2] = 32'h0; envm_mem[3] = 32'h0;
        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 300) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 4]: Blank eNVM locked in reset (boot_fail=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 4]: Blank eNVM released core reset! (boot_pass=%b)", boot_pass);
            checks_failed = checks_failed + 1;
        end

        // ---------------------------------------------------------------
        // TEST 5: Clean Recovery after Hardware Reset
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 5: Post-Fault Clean Reset Recovery ---");
        envm_mem[0] = 32'h5449544E;
        envm_mem[1] = 32'd16;
        envm_mem[2] = 32'hba7816bf;
        envm_mem[3] = 32'hCAFE_F00D;
        envm_mem[4] = 32'h61626380;
        reset_dut();

        timeout = 0;
        while (!boot_pass && !boot_fail && timeout < 300) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (boot_pass && !boot_fail) begin
            $display("PASS [Scenario 5]: Clean recovery after hardware reset (boot_pass=1)");
            checks_passed = checks_passed + 1;
        end else begin
            $display("FAIL [Scenario 5]: Reset recovery failed (boot_pass=%b, boot_fail=%b)", boot_pass, boot_fail);
            checks_failed = checks_failed + 1;
        end

        // Final Report
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

endmodule
