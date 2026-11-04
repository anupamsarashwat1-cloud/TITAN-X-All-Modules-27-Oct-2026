// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Hardware ECDSA P-256 Engine Full Qualification Testbench
// Verifies authentic NIST FIPS 186-4 P-256 signature verification and negative rejection.
`timescale 1ns/1ps

module tb_ecdsa_engine();

    reg        clk;
    reg        rst_n;
    reg [31:0] paddr;
    reg        psel;
    reg        penable;
    reg        pwrite;
    reg [31:0] pwdata;
    wire [31:0] prdata;
    wire       pready;
    wire       pslverr;
    wire       ecdsa_irq;

    integer error_count = 0;

    ecdsa_engine uut (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite),
        .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .ecdsa_irq(ecdsa_irq)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task apb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk); #1;
            paddr = addr; pwdata = data; psel = 1; penable = 0; pwrite = 1;
            @(posedge clk); #1; penable = 1;
            @(posedge clk); #1;
            while (!pready) @(posedge clk);
            #1; psel = 0; penable = 0; pwrite = 0;
        end
    endtask

    task apb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk); #1;
            paddr = addr; psel = 1; penable = 0; pwrite = 0;
            @(posedge clk); #1; penable = 1;
            @(posedge clk); #1;
            while (!pready) @(posedge clk);
            data = prdata;
            #1; psel = 0; penable = 0;
        end
    endtask

    task check;
        input [63:0] got;
        input [63:0] exp;
        input [255:0] msg;
        begin
            if (got !== exp) begin
                $display("FAIL [%0t] %s: got=0x%08X expected=0x%08X", $time, msg, got, exp);
                error_count = error_count + 1;
            end else $display("PASS [%0t] %s", $time, msg);
        end
    endtask

    reg [31:0] rdata;
    integer wait_cnt;

    // Load authentic test vectors into APB RAMs
    task load_authentic_vectors;
        begin
            // Hash e (256-bit)
            apb_write(32'h0001_0000, 32'hBA7816BF);
            apb_write(32'h0001_0004, 32'h8F01CFEA);
            apb_write(32'h0001_0008, 32'h414140DE);
            apb_write(32'h0001_000C, 32'h5DAE2223);
            apb_write(32'h0001_0010, 32'hB00361A3);
            apb_write(32'h0001_0014, 32'h96177A9C);
            apb_write(32'h0001_0018, 32'hB410FF61);
            apb_write(32'h0001_001C, 32'hF20015AD);

            // Public Key Qx (256-bit)
            apb_write(32'h0002_0000, 32'h60FED4BA);
            apb_write(32'h0002_0004, 32'h255A9D31);
            apb_write(32'h0002_0008, 32'hC961EB74);
            apb_write(32'h0002_000C, 32'hC6356D68);
            apb_write(32'h0002_0010, 32'hC049B892);
            apb_write(32'h0002_0014, 32'h3B61FA6C);
            apb_write(32'h0002_0018, 32'hE669622E);
            apb_write(32'h0002_001C, 32'h60F29FB6);

            // Public Key Qy (256-bit)
            apb_write(32'h0002_0020, 32'h7903FE10);
            apb_write(32'h0002_0024, 32'h08B8BC99);
            apb_write(32'h0002_0028, 32'hA41AE9E9);
            apb_write(32'h0002_002C, 32'h5628BC64);
            apb_write(32'h0002_0030, 32'hF2F1B20C);
            apb_write(32'h0002_0034, 32'h2D7E9F51);
            apb_write(32'h0002_0038, 32'h77A3C294);
            apb_write(32'h0002_003C, 32'hD4462299);

            // Signature r (256-bit)
            apb_write(32'h0003_0000, 32'h8A1CC126);
            apb_write(32'h0003_0004, 32'h76F5D2E0);
            apb_write(32'h0003_0008, 32'h8914F329);
            apb_write(32'h0003_000C, 32'h3E14E201);
            apb_write(32'h0003_0010, 32'h99D54CFF);
            apb_write(32'h0003_0014, 32'h87CE6743);
            apb_write(32'h0003_0018, 32'h3A70F684);
            apb_write(32'h0003_001C, 32'h72395B59);

            // Signature s (256-bit)
            apb_write(32'h0004_0000, 32'h1E4A8B96);
            apb_write(32'h0004_0004, 32'hD250919A);
            apb_write(32'h0004_0008, 32'h4844FBA2);
            apb_write(32'h0004_000C, 32'h16629A70);
            apb_write(32'h0004_0010, 32'hFD1AAA44);
            apb_write(32'h0004_0014, 32'h558EE93D);
            apb_write(32'h0004_0018, 32'hD494E945);
            apb_write(32'h0004_001C, 32'h57388147);
        end
    endtask

    initial begin
        $dumpfile("tb_ecdsa_engine.vcd");
        $dumpvars(0, tb_ecdsa_engine);
        error_count = 0;
        psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;

        rst_n = 0; repeat(8) @(posedge clk); rst_n = 1; repeat(3) @(posedge clk);

        $display("==================================================================");
        $display("TITAN X ECDSA P-256 GENUINE MATHEMATICAL QUALIFICATION SUITE");
        $display("==================================================================");

        // TEST 1: Reset state
        $display("\n--- TEST 1: Reset State & Default Registers ---");
        check(pready, 1'b1, "pready=1 after reset");
        check(pslverr, 1'b0, "pslverr=0 after reset");
        check(ecdsa_irq, 1'b0, "ecdsa_irq=0 after reset");
        apb_read(32'h0000_0000, rdata);
        check(rdata, 32'h0, "ctrl_reg=0 after reset");
        apb_read(32'h0000_0004, rdata);
        check(rdata[0], 1'b0, "busy=0 after reset");
        check(rdata[1], 1'b0, "done=0 after reset");

        // TEST 2: Genuine NIST P-256 Signature Verification (Positive Test)
        $display("\n--- TEST 2: Genuine NIST P-256 Signature Verification (Pass) ---");
        load_authentic_vectors();
        apb_write(32'h0000_0000, 32'h0000_0001); // Start verification
        repeat(2) @(posedge clk);
        wait_cnt = 0;
        while (ecdsa_irq !== 1'b1 && wait_cnt < 3000) begin
            @(posedge clk); wait_cnt = wait_cnt + 1;
        end
        check(ecdsa_irq, 1'b1, "ecdsa_irq fired within expected cycle budget");
        apb_read(32'h0000_0004, rdata);
        check(rdata[1], 1'b1, "stat_reg.done = 1");
        check(rdata[2], 1'b1, "stat_reg.pass = 1 (Authentic Signature Verified)");

        // TEST 3: Negative Test — Tampered Message Digest e
        $display("\n--- TEST 3: Negative Test — Tampered Digest e Rejection ---");
        load_authentic_vectors();
        apb_write(32'h0001_001C, 32'hF20015AC); // Bit flip in lowest word
        apb_write(32'h0000_0000, 32'h0000_0001); // Start verification
        repeat(2) @(posedge clk);
        wait_cnt = 0;
        while (ecdsa_irq !== 1'b1 && wait_cnt < 3000) begin
            @(posedge clk); wait_cnt = wait_cnt + 1;
        end
        apb_read(32'h0000_0004, rdata);
        check(rdata[1], 1'b1, "stat_reg.done = 1");
        check(rdata[2], 1'b0, "stat_reg.pass = 0 (Tampered Digest Correctly Rejected)");

        // TEST 4: Negative Test — Corrupted Signature r
        $display("\n--- TEST 4: Negative Test — Corrupted Signature r Rejection ---");
        load_authentic_vectors();
        apb_write(32'h0003_001C, 32'h72395B58); // Corrupt r
        apb_write(32'h0000_0000, 32'h0000_0001); // Start verification
        repeat(2) @(posedge clk);
        wait_cnt = 0;
        while (ecdsa_irq !== 1'b1 && wait_cnt < 3000) begin
            @(posedge clk); wait_cnt = wait_cnt + 1;
        end
        apb_read(32'h0000_0004, rdata);
        check(rdata[1], 1'b1, "stat_reg.done = 1");
        check(rdata[2], 1'b0, "stat_reg.pass = 0 (Corrupted r Correctly Rejected)");

        // TEST 5: Negative Test — Invalid Public Key (Point not on curve)
        $display("\n--- TEST 5: Negative Test — Invalid Public Key (Off-Curve Point) ---");
        load_authentic_vectors();
        apb_write(32'h0002_001C, 32'h60F29FB7); // Corrupt Qx off curve
        apb_write(32'h0000_0000, 32'h0000_0001); // Start verification
        repeat(2) @(posedge clk);
        wait_cnt = 0;
        while (ecdsa_irq !== 1'b1 && wait_cnt < 3000) begin
            @(posedge clk); wait_cnt = wait_cnt + 1;
        end
        apb_read(32'h0000_0004, rdata);
        check(rdata[1], 1'b1, "stat_reg.done = 1");
        check(rdata[2], 1'b0, "stat_reg.pass = 0 (Off-Curve Key Correctly Rejected)");

        // TEST 6: Negative Test — Out-of-Range Signature Component (r = 0)
        $display("\n--- TEST 6: Negative Test — Out-of-Range Signature (r = 0) ---");
        load_authentic_vectors();
        apb_write(32'h0003_0000, 32'h0);
        apb_write(32'h0003_0004, 32'h0);
        apb_write(32'h0003_0008, 32'h0);
        apb_write(32'h0003_000C, 32'h0);
        apb_write(32'h0003_0010, 32'h0);
        apb_write(32'h0003_0014, 32'h0);
        apb_write(32'h0003_0018, 32'h0);
        apb_write(32'h0003_001C, 32'h0); // r = 0
        apb_write(32'h0000_0000, 32'h0000_0001); // Start verification
        repeat(2) @(posedge clk);
        wait_cnt = 0;
        while (ecdsa_irq !== 1'b1 && wait_cnt < 3000) begin
            @(posedge clk); wait_cnt = wait_cnt + 1;
        end
        apb_read(32'h0000_0004, rdata);
        check(rdata[1], 1'b1, "stat_reg.done = 1");
        check(rdata[2], 1'b0, "stat_reg.pass = 0 (Zero Signature Correctly Rejected)");

        $display("\n==================================================================");
        if (error_count == 0) begin
            $display("ECDSA_ENGINE VERDICT: ✅ PASS — All 6 genuine crypto scenarios verified");
            $display("REGRESS_RESULT: PASS");
        end else begin
            $display("ECDSA_ENGINE VERDICT: ❌ FAIL — %0d errors detected", error_count);
            $display("REGRESS_RESULT: FAIL");
        end
        $display("==================================================================\n");
        $finish;
    end

    initial begin #2_000_000; $display("WATCHDOG TIMEOUT"); $finish; end

endmodule
