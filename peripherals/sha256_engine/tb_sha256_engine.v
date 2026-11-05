// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — SHA-256 Engine Directed Self-Checking Testbench
// Register map (paddr[7:0]):
//   0x00-0x3C = msg_block[0..15] (W: 512-bit message block, 16x32b words)
//                                 R: readback of msg_block words
//   0x40-0x5C = hash[0..7] (R: 256-bit hash output, 8x32b words)
//   0x60 = start register (W: bit 0=start, bit 1=init_hash, bit 2=auto_pad)
//   0x64 = msg_len_bytes (W: total message length in bytes for auto-padding)
//   0x80+ = status: prdata = {30'h0, done, active}
// SHA-256 initial hash values (H0-H7) are the standard IV constants
`timescale 1ns/1ps

module tb_sha256_engine();

    reg        clk;
    reg        rst_n;
    reg        psel;
    reg        penable;
    reg        pwrite;
    reg [7:0]  paddr;
    reg [31:0] pwdata;
    wire[31:0] prdata;
    wire       pready;
    wire       irq;

    integer error_count;

    sha256_engine uut (
        .clk(clk), .rst_n(rst_n),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready),
        .irq(irq)
    );

    initial clk = 0;
    always #3.6 clk = ~clk;

    task apb_write;
        input [7:0]  addr;
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
        input  [7:0]  addr;
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

    task check_nonzero;
        input [31:0] got;
        input [255:0] msg;
        begin
            if (got === 32'h0) begin
                $display("FAIL [%0t] %s = 0 (expected non-zero)", $time, msg);
                error_count = error_count + 1;
            end else $display("PASS [%0t] %s = 0x%08X (non-zero)", $time, msg, got);
        end
    endtask

    task check_hash256;
        input [255:0] exp;
        input [255:0] name;
        reg [31:0] h [0:7];
        reg [255:0] got;
        integer hi;
        begin
            for (hi = 0; hi < 8; hi = hi + 1)
                apb_read(8'h40 + (hi << 2), h[hi]);
            got = {h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]};
            if (got !== exp) begin
                $display("FAIL [%0t] NIST CAVP %s: got=%064X expected=%064X", $time, name, got, exp);
                error_count = error_count + 1;
            end else begin
                $display("PASS [%0t] NIST CAVP %s: %064X (matches OpenSSL/hashlib)", $time, name, got);
            end
        end
    endtask

    reg [31:0] rdata;
    integer i;
    integer wait_cnt;

    initial begin
        $dumpfile("tb_sha256_engine.vcd");
        $dumpvars(0, tb_sha256_engine);
        error_count = 0;
        psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;

        // Reset
        rst_n = 0; repeat(8) @(posedge clk); rst_n = 1; repeat(3) @(posedge clk);

        // TEST 1: pready + irq reset state
        $display("\n--- TEST 1: Reset state ---");
        check(pready, 1'b1, "pready=1 after reset");
        check(irq, 1'b0, "irq=0 after reset");

        // TEST 2: Hash initial values after reset
        // SHA-256 IV: H0=0x6a09e667, H1=0xbb67ae85 ...
        $display("\n--- TEST 2: Initial hash values (SHA-256 IV) ---");
        apb_read(8'h40, rdata);  // hash[0]
        check(rdata, 32'h6a09e667, "hash[0]=0x6a09e667 (H0 IV)");
        apb_read(8'h44, rdata);  // hash[1]
        check(rdata, 32'hbb67ae85, "hash[1]=0xBB67AE85 (H1 IV)");

        // TEST 3: Message block write/readback
        $display("\n--- TEST 3: Message block write/readback ---");
        apb_write(8'h00, 32'h8000_0000);  // msg_block[0] = SHA-256 padding header
        apb_write(8'h04, 32'hDEAD_BEEF);  // msg_block[1] = test data
        apb_read (8'h00, rdata);
        check(rdata, 32'h8000_0000, "msg_block[0] readback");
        apb_read (8'h04, rdata);
        check(rdata, 32'hDEAD_BEEF, "msg_block[1] readback");

        // TEST 4: Write all-zeros message block (empty message SHA-256 padding, legacy mode)
        $display("\n--- TEST 4: Load zero-length message block ---");
        for (i = 0; i < 16; i = i + 1)
            apb_write(i*4, 32'h0);
        // Set message 0: 0x80000000 (padding), word 15: 0x00000000 (length=0 bits)
        apb_write(8'h00, 32'h8000_0000);  // msg_block[0]: 0x80 padding
        $display("  Zero-length message block loaded");

        // TEST 5: Start SHA-256 compression
        $display("\n--- TEST 5: Start compression ---");
        apb_write(8'h60, 32'h0000_0001);  // start=1

        wait_cnt = 0;
        while (irq !== 1'b1 && wait_cnt < 200) begin
            @(posedge clk); wait_cnt = wait_cnt + 1;
        end
        if (irq === 1'b1)
            $display("PASS [%0t] irq=1 (done) after SHA-256 compression (%0d cycles)", $time, wait_cnt);
        else begin
            $display("FAIL [%0t] SHA-256 done never fired in 200 cycles", $time);
            error_count = error_count + 1;
        end

        // TEST 6: SHA-256 hash output is non-zero after compression
        $display("\n--- TEST 6: Hash output non-zero after compression ---");
        apb_read(8'h40, rdata);  // hash[0]
        check_nonzero(rdata, "hash[0] non-zero after compression");
        apb_read(8'h44, rdata);  // hash[1]
        check_nonzero(rdata, "hash[1] non-zero after compression");

        // TEST 7: irq clears on next cycle (done is pulsed, not latched)
        $display("\n--- TEST 7: irq deasserts after one cycle ---");
        @(posedge clk); @(posedge clk);
        $display("  irq = %b (expected to deassert per RTL: done <= 1'b0)", irq);
        check(irq, 1'b0, "irq=0 one cycle after done pulse");

        // -----------------------------------------------------------------
        // NIST CAVP FIPS 180-4 AUTOMATED PADDING VERIFICATION (DEF-SEC-04)
        // -----------------------------------------------------------------
        $display("\n--- TEST 8: NIST CAVP Empty String (0 bytes, auto-pad) ---");
        apb_write(8'h64, 32'd0); // msg_len_bytes = 0
        apb_write(8'h60, 32'h7); // start=1, init_hash=1, auto_pad=1
        while (!irq) @(posedge clk);
        check_hash256(256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855, "Empty Message");

        $display("\n--- TEST 9: NIST CAVP 'abc' (3 bytes, auto-pad) ---");
        apb_write(8'h00, 32'h6162_6300); // "abc"
        apb_write(8'h64, 32'd3); // msg_len_bytes = 3
        apb_write(8'h60, 32'h7); // start=1, init_hash=1, auto_pad=1
        while (!irq) @(posedge clk);
        check_hash256(256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad, "'abc'");

        $display("\n--- TEST 10: NIST CAVP 56-byte message (2-block auto-pad) ---");
        // "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" (56 bytes)
        apb_write(8'h00, 32'h61626364);
        apb_write(8'h04, 32'h62636465);
        apb_write(8'h08, 32'h63646566);
        apb_write(8'h0C, 32'h64656667);
        apb_write(8'h10, 32'h65666768);
        apb_write(8'h14, 32'h66676869);
        apb_write(8'h18, 32'h6768696a);
        apb_write(8'h1C, 32'h68696a6b);
        apb_write(8'h20, 32'h696a6b6c);
        apb_write(8'h24, 32'h6a6b6c6d);
        apb_write(8'h28, 32'h6b6c6d6e);
        apb_write(8'h2C, 32'h6c6d6e6f);
        apb_write(8'h30, 32'h6d6e6f70);
        apb_write(8'h34, 32'h6e6f7071);
        apb_write(8'h64, 32'd56); // msg_len_bytes = 56
        apb_write(8'h60, 32'h7);  // start=1, init_hash=1, auto_pad=1
        while (!irq) @(posedge clk);
        check_hash256(256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1, "56-byte CAVP");

        $display("\n--- TEST 11: NIST CAVP 64-byte message (2-block auto-pad) ---");
        // '1234567890123456789012345678901234567890123456789012345678901234'
        apb_write(8'h00, 32'h31323334);
        apb_write(8'h04, 32'h35363738);
        apb_write(8'h08, 32'h39303132);
        apb_write(8'h0C, 32'h33343536);
        apb_write(8'h10, 32'h37383930);
        apb_write(8'h14, 32'h31323334);
        apb_write(8'h18, 32'h35363738);
        apb_write(8'h1C, 32'h39303132);
        apb_write(8'h20, 32'h33343536);
        apb_write(8'h24, 32'h37383930);
        apb_write(8'h28, 32'h31323334);
        apb_write(8'h2C, 32'h35363738);
        apb_write(8'h30, 32'h39303132);
        apb_write(8'h34, 32'h33343536);
        apb_write(8'h38, 32'h37383930);
        apb_write(8'h3C, 32'h31323334);
        apb_write(8'h64, 32'd64); // msg_len_bytes = 64
        apb_write(8'h60, 32'h7);  // start=1, init_hash=1, auto_pad=1
        while (!irq) @(posedge clk);
        check_hash256(256'h676491965ed3ec50cb7a63ee96315480a95c54426b0b72bca8a0d4ad1285ad55, "64-byte CAVP");

        $display("\n--- TEST 12: Multi-block 120-byte message chaining (auto-pad) ---");
        // 120 bytes of 0x41 ('A')
        for (i = 0; i < 16; i = i + 1)
            apb_write(i*4, 32'h41414141);
        apb_write(8'h60, 32'h3); // Block 0: start=1, init_hash=1, auto_pad=0
        while (!irq) @(posedge clk);
        for (i = 0; i < 14; i = i + 1)
            apb_write(i*4, 32'h41414141);
        apb_write(8'h64, 32'd120); // total 120 bytes
        apb_write(8'h60, 32'h5);   // Block 1+2: start=1, init_hash=0, auto_pad=1
        while (!irq) @(posedge clk);
        check_hash256(256'ha4f4256159ea6fb23b27eb8c5eb9cfb9083475985f355a85c78de8f2fef2b3ac, "120-byte Chaining");

        $display("\n==============================");
        if (error_count == 0)
            $display("SHA256_ENGINE VERDICT: ✅ PASS — All tests passed (including NIST CAVP vectors)");
        else
            $display("SHA256_ENGINE VERDICT: ❌ FAIL — %0d errors detected", error_count);
        $display("==============================\n");
        $finish;
    end

    initial begin #2_000_000; $display("WATCHDOG TIMEOUT"); $finish; end

endmodule
