// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Secure Boot Comprehensive Verification Testbench
// Independent Reproduction of Root-of-Trust Authenticity & Negative Fault Rejection

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

    // Helper: Reset DUT
    task reset_dut();
        begin
            rst_n = 0;
            paddr = 0; psel = 0; penable = 0; pwrite = 0; pwdata = 0;
            envm_rdata = 0; envm_enable_valid = 1;
            repeat(4) @(posedge clk);
            #1 rst_n = 1;
            @(posedge clk);
        end
    endtask

    // Simulated eNVM Memory Block (Combinational response aligned with titan_x_top)
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
        envm_mem[0] = 32'h5449544E; // Magic: "TITN"
        envm_mem[1] = 32'd4;        // Length: 4 payload words
        envm_mem[2] = 32'h08687AC0; // Expected Rolling Hash for payload
        envm_mem[3] = 32'hCAFE_F00D; // Authorized Root Public Key ID
        envm_mem[4] = 32'hDEAD_BEEF; // Payload 0
        envm_mem[5] = 32'h1234_5678; // Payload 1
        envm_mem[6] = 32'hCAFE_BABE; // Payload 2
        envm_mem[7] = 32'h0000_0000; // Payload 3

        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 200) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_pass && !boot_fail) begin
            $display("PASS [Scenario 1]: Authentic image verified successfully (boot_pass=1, boot_fail=0)");
        end else begin
            $display("FAIL [Scenario 1]: Expected boot_pass=1, got boot_pass=%b, boot_fail=%b", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // Check APB telemetry
        apb_read(status_val, 32'h00);
        if (status_val[2:0] == 3'd4) begin
            $display("PASS [Scenario 1 APB]: Status register reports SUCCESS state (3'd4)");
        end else begin
            $display("FAIL [Scenario 1 APB]: Expected status 3'd4, got %h", status_val);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 2: NEGATIVE TEST — Modified/Tampered Firmware Image
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 2: Negative Test (Modified Firmware Payload) ---");
        // Tamper payload word 6 (bit flip 0xCAFEBABE -> 0xCAFEBABA)
        envm_mem[6] = 32'hCAFE_BABA;

        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 200) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 2]: Tampered firmware rejected (boot_fail=1, processor locked in reset)");
        end else begin
            $display("FAIL [Scenario 2]: Security vulnerability! Tampered firmware produced boot_pass=%b", boot_pass);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 3: NEGATIVE TEST — Bad Magic / Constant eNVM Zeroes
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 3: Negative Test (Zero-Valued / Corrupted eNVM) ---");
        envm_mem[0] = 32'h0000_0000; // All zeroes (e.g. unprogrammed eNVM)
        envm_mem[1] = 32'h0000_0000;
        envm_mem[2] = 32'h0000_0000;
        envm_mem[3] = 32'h0000_0000;

        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 200) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 3]: Zero-valued eNVM rejected (boot_fail=1, core reset held safely)");
        end else begin
            $display("FAIL [Scenario 3]: Zero-valued eNVM improperly released reset: boot_pass=%b", boot_pass);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 4: NEGATIVE TEST — Unauthorized Public Key ID
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 4: Negative Test (Unauthorized Public Key ID) ---");
        envm_mem[0] = 32'h5449544E; // Valid magic
        envm_mem[1] = 32'd4;
        envm_mem[2] = 32'h08687AC0; // Valid hash
        envm_mem[3] = 32'hDEAD_BEEF; // Rogue / unauthorized public key!
        envm_mem[4] = 32'hDEAD_BEEF;
        envm_mem[5] = 32'h1234_5678;
        envm_mem[6] = 32'hCAFE_BABE;
        envm_mem[7] = 32'h0000_0000;

        reset_dut();

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 200) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 4]: Unauthorized public key rejected (boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 4]: Unauthorized key bypassed verification: boot_pass=%b", boot_pass);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 5: NEGATIVE TEST — Memory Timeout / Offline Storage
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 5: Negative Test (eNVM Memory Hang / Timeout) ---");
        reset_dut();
        // Force valid off to simulate unresponsive eNVM
        envm_valid = 1'b0;

        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 300) begin
            @(posedge clk);
            envm_valid = 1'b0; // suppress response
            step_cnt = step_cnt + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 5]: Memory timeout handled safely (boot_fail=1, processor locked in reset)");
        end else begin
            $display("FAIL [Scenario 5]: Timeout did not halt boot: boot_pass=%b, boot_fail=%b", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 6: NEGATIVE TEST — Zero-Length Firmware Image
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 6: Negative Test (Zero-Length Firmware) ---");
        envm_mem[0] = 32'h5449544E; // Valid magic
        envm_mem[1] = 32'h00000000; // Zero length
        envm_mem[2] = 32'h08687AC0;
        envm_mem[3] = 32'hCAFE_F00D;

        reset_dut();
        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 200) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 6]: Zero-length firmware rejected (boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 6]: Zero-length firmware produced boot_pass=%b", boot_pass);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 7: NEGATIVE TEST — Out-of-Bounds Image Length (>1024 words)
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 7: Negative Test (Out-of-Bounds Image Length) ---");
        envm_mem[0] = 32'h5449544E; // Valid magic
        envm_mem[1] = 32'd2048;     // Exceeds 1024-word hardware limit
        envm_mem[2] = 32'h08687AC0;
        envm_mem[3] = 32'hCAFE_F00D;

        reset_dut();
        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 200) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 7]: Oversized image rejected (boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 7]: Oversized image produced boot_pass=%b", boot_pass);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 8: NEGATIVE TEST — Hash Digest Mismatch
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 8: Negative Test (Digest Mismatch) ---");
        envm_mem[0] = 32'h5449544E; // Valid magic
        envm_mem[1] = 32'd4;        // 4 words
        envm_mem[2] = 32'hBAD0_D16E; // Corrupted expected hash
        envm_mem[3] = 32'hCAFE_F00D; // Valid key
        envm_mem[4] = 32'hDEAD_BEEF;
        envm_mem[5] = 32'h1234_5678;
        envm_mem[6] = 32'hCAFE_BABE;
        envm_mem[7] = 32'h0000_0000;

        reset_dut();
        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 200) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_fail && !boot_pass) begin
            $display("PASS [Scenario 8]: Digest mismatch rejected (boot_fail=1)");
        end else begin
            $display("FAIL [Scenario 8]: Digest mismatch produced boot_pass=%b", boot_pass);
            errors = errors + 1;
        end

        // ---------------------------------------------------------------
        // TEST 9: POSITIVE RECOVERY — Reset Recovery with Authentic Image
        // ---------------------------------------------------------------
        $display("\n--- SCENARIO 9: Reset Recovery Test (Post-Fault Hardware Reset) ---");
        // Restore authentic image
        envm_mem[0] = 32'h5449544E; // Magic: "TITN"
        envm_mem[1] = 32'd4;        // Length: 4 payload words
        envm_mem[2] = 32'h08687AC0; // Expected Rolling Hash for payload
        envm_mem[3] = 32'hCAFE_F00D; // Authorized Root Public Key ID
        envm_mem[4] = 32'hDEAD_BEEF;
        envm_mem[5] = 32'h1234_5678;
        envm_mem[6] = 32'hCAFE_BABE;
        envm_mem[7] = 32'h0000_0000;

        reset_dut();
        step_cnt = 0;
        while (!boot_pass && !boot_fail && step_cnt < 200) begin
            @(posedge clk);
            step_cnt = step_cnt + 1;
        end

        if (boot_pass && !boot_fail) begin
            $display("PASS [Scenario 9]: Clean recovery after hardware reset (boot_pass=1, boot_fail=0)");
        end else begin
            $display("FAIL [Scenario 9]: Failed to recover after reset: boot_pass=%b, boot_fail=%b", boot_pass, boot_fail);
            errors = errors + 1;
        end

        // Final Scorecard
        $display("\n==================================================================");
        if (errors == 0) begin
            $display("SECURE_BOOT VERDICT: ✅ PASS — All 9 security scenarios verified");
            $display("REGRESS_RESULT: PASS");
        end else begin
            $display("SECURE_BOOT VERDICT: ❌ FAIL — %0d security test failures", errors);
            $display("REGRESS_RESULT: FAIL");
        end
        $display("==================================================================\n");
        $finish;
    end

    initial begin
        #10_000_000;
        $display("WATCHDOG TIMEOUT in tb_secure_boot");
        $finish;
    end

endmodule
