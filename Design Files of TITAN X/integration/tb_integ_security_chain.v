// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Integration Test: Security Chain (self-checking rewrite)
// DRBG: APB BFM drives instantiate/generate/reseed; entropy forced by TB
//       (TB plays the TRNG role until the real TRNG is integrated).
// secure_boot: FSM observed through boot_pass/boot_fail and its APB status.
// Every test checks exact register values or state transitions.
`timescale 1ns/1ps

`include "tb_bfms.vh"

module tb_integ_security_chain;

    `include "tb_macros.vh"

    reg clk;
    reg rst_n;
    `TB_HARNESS(50_000_000)

    `TB_SCOREBOARD

    // ---------------- shared APB bus ----------------
    wire [31:0] paddr, pwdata;
    wire        psel, penable, pwrite;
    wire [31:0] prdata_drbg, prdata_boot;
    wire        drbg_irq;
    // Block selects decode the REGION nibble (bits [31:28]): 0x1 -> DRBG,
    // 0x2 -> secure_boot. (The original decoded bits [11:8], which are 0x0
    // for every 0x1000_xxxx/0x2000_xxxx address — neither engine was ever
    // selected and all reads returned the mux default zero.)
    wire        psel_drbg = psel && (paddr[31:28] == 4'h1);
    wire        psel_boot = psel && (paddr[31:28] == 4'h2);
    wire [31:0] prdata_mux = psel_drbg ? prdata_drbg :
                            psel_boot ? prdata_boot : 32'h0;

    // ---------------- DRBG ----------------
    reg [255:0] entropy =
        256'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210_A5A5_5A5A_DEAD_BEEF_CAFE_BABE;
    reg         trng_valid;

    apb_master_bfm u_apb (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite),
        .pwdata(pwdata), .prdata(prdata_mux), .pready(1'b1), .pslverr(1'b0)
    );

    drbg u_drbg (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel_drbg), .penable(penable), .pwrite(pwrite),
        .pwdata(pwdata), .prdata(prdata_drbg), .pready(), .pslverr(),
        .trng_entropy(entropy), .trng_valid(trng_valid), .trng_ready(),
        .drbg_irq(drbg_irq)
    );

    // ---------------- secure_boot ----------------
    wire        boot_pass, boot_fail;
    wire        envm_req;
    wire [16:0] envm_addr;
    reg         envm_valid;
    reg [31:0] envm_image [0:58];
    initial begin
        envm_image[ 0] = 32'h5449544E; // Magic: "TITN"
        envm_image[ 1] = 32'h00000010; // Length: 16 payload words
        envm_image[ 2] = 32'hCAFEF00D; // Authorized Root Public Key ID
        // Expected 256-bit SHA-256 Digest
        envm_image[ 3] = 32'h47FC49DF;
        envm_image[ 4] = 32'hC7A5A9F5;
        envm_image[ 5] = 32'h63CB70B5;
        envm_image[ 6] = 32'h621E4D55;
        envm_image[ 7] = 32'h1DEF80B1;
        envm_image[ 8] = 32'h65B0438A;
        envm_image[ 9] = 32'h6E3DB762;
        envm_image[10] = 32'h6560B2D1;
        // Root Public Key Qx (256-bit)
        envm_image[11] = 32'h26F4FA43;
        envm_image[12] = 32'h1A2BEB66;
        envm_image[13] = 32'h46D953CA;
        envm_image[14] = 32'h332BC722;
        envm_image[15] = 32'h911D9B05;
        envm_image[16] = 32'hE5D92476;
        envm_image[17] = 32'h06330B61;
        envm_image[18] = 32'hE6703F52;
        // Root Public Key Qy (256-bit)
        envm_image[19] = 32'h9E9689C9;
        envm_image[20] = 32'h49B37A0B;
        envm_image[21] = 32'h342F6CAC;
        envm_image[22] = 32'h9B4E5440;
        envm_image[23] = 32'hA727CEE4;
        envm_image[24] = 32'h055285CD;
        envm_image[25] = 32'hA6216084;
        envm_image[26] = 32'h643D6E4F;
        // Signature r (256-bit)
        envm_image[27] = 32'hE3077595;
        envm_image[28] = 32'hEB490AA5;
        envm_image[29] = 32'h401DA7B8;
        envm_image[30] = 32'h8B62216E;
        envm_image[31] = 32'h12268AD2;
        envm_image[32] = 32'hBF84F2C2;
        envm_image[33] = 32'h46ABAA46;
        envm_image[34] = 32'hBB725C5E;
        // Signature s (256-bit)
        envm_image[35] = 32'h78D3D87A;
        envm_image[36] = 32'hE71E31D6;
        envm_image[37] = 32'h5812414C;
        envm_image[38] = 32'h7E90196A;
        envm_image[39] = 32'h16DBBD28;
        envm_image[40] = 32'hEC6DF9FD;
        envm_image[41] = 32'hBA6D21BC;
        envm_image[42] = 32'h1F31B431;
        // Signed 16-word payload
        envm_image[43] = 32'h10000000;
        envm_image[44] = 32'h10000004;
        envm_image[45] = 32'h10000008;
        envm_image[46] = 32'h1000000C;
        envm_image[47] = 32'h10000010;
        envm_image[48] = 32'h10000014;
        envm_image[49] = 32'h10000018;
        envm_image[50] = 32'h1000001C;
        envm_image[51] = 32'h10000020;
        envm_image[52] = 32'h10000024;
        envm_image[53] = 32'h10000028;
        envm_image[54] = 32'h1000002C;
        envm_image[55] = 32'h10000030;
        envm_image[56] = 32'h10000034;
        envm_image[57] = 32'h10000038;
        envm_image[58] = 32'h1000003C;
    end
    wire [31:0] envm_rdata = (envm_addr < 17'd59) ? envm_image[envm_addr] : 32'h0;

    secure_boot u_boot (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel_boot), .penable(penable), .pwrite(pwrite),
        .pwdata(pwdata), .prdata(prdata_boot), .pready(), .pslverr(),
        .envm_addr(envm_addr), .envm_req(envm_req), .envm_rdata(envm_rdata),
        .envm_valid(envm_valid),
        .boot_pass(boot_pass), .boot_fail(boot_fail)
    );

    // feed eNVM read-valids while the boot engine reads
    always @(posedge clk) envm_valid <= envm_req;

    initial begin
        // $dumpfile("tb_integ_security_chain.vcd");
        // $dumpvars(0, tb_integ_security_chain);
    end

    // ---------------- tests ----------------
    reg [31:0] rd;
    reg [1:0]  apb_resp;
    integer guard;

    task apb_w(input [31:0] a, input [31:0] d);
        begin u_apb.apb_write(a, d, apb_resp); end
    endtask

    task apb_r(input [31:0] a);
        begin u_apb.apb_read(a, rd, apb_resp); end
    endtask

    initial begin
        repeat (30) @(posedge clk);

        // S1: clean initial state
        apb_r(32'h1000_0004);
        `EXPECT_EQ(rd[1:0], 2'b00, "DRBG idle busy=0 done=0")

        // S2: instantiate with known entropy -> done + irq
        apb_w(32'h1000_0000, 32'h0000_0001);   // CTRL.instantiate
        trng_valid = 1'b1;
        guard = 0;
        while (u_drbg.stat_reg[1] !== 1'b1 && guard < 50) begin @(posedge clk); guard = guard+1; end
        trng_valid = 1'b0;
        `EXPECT_TRUE(u_drbg.stat_reg[1] === 1'b1, "instantiate sets DONE")
        `EXPECT_TRUE(drbg_irq === 1'b1, "drbg_irq reflects DONE")
        `EXPECT_EQ(u_drbg.reseed_counter, 32'd1, "reseed counter=1")
        `EXPECT_EQ(u_drbg.Key, ~entropy, "Key=~entropy")

        // S3: first GENERATE returns original V words (V increments after capture)
        apb_r(32'h1000_0004);                  // clears done
        apb_w(32'h1000_0000, 32'h0000_0004);   // CTRL.generate
        guard = 0;
        while (u_drbg.stat_reg[1] !== 1'b1 && guard < 50) begin @(posedge clk); guard = guard+1; end
        `EXPECT_TRUE(u_drbg.stat_reg[1] === 1'b1, "generate sets DONE")
        apb_r(32'h1000_0010);
        `EXPECT_EQ(rd, entropy[31:0], "gen out[0]==V[31:0]")
        apb_r(32'h1000_002c);
        `EXPECT_EQ(rd, entropy[255:224], "gen out[7]==V[255:224]")
        `EXPECT_EQ(u_drbg.V, entropy + 256'h1, "V incremented")

        // S4: second generate returns incremented words — determinism check
        apb_r(32'h1000_0004);
        apb_w(32'h1000_0000, 32'h0000_0004);
        guard = 0;
        while (u_drbg.stat_reg[1] !== 1'b1 && guard < 50) begin @(posedge clk); guard = guard+1; end
        apb_r(32'h1000_0010);
        `EXPECT_EQ(rd, entropy[31:0] + 32'h1, "second gen out[0]==V+1")

        // S5: reseed path re-sets done and resets counter
        apb_r(32'h1000_0004);
        apb_w(32'h1000_0000, 32'h0000_0002);   // CTRL.reseed
        trng_valid = 1'b1;
        guard = 0;
        while (u_drbg.stat_reg[1] !== 1'b1 && guard < 50) begin @(posedge clk); guard = guard+1; end
        trng_valid = 1'b0;
        `EXPECT_TRUE(u_drbg.stat_reg[1] === 1'b1, "reseed sets DONE")
        `EXPECT_EQ(u_drbg.reseed_counter, 32'd1, "reseed resets counter")

        // S6: secure boot reaches SUCCESS with fed eNVM valids (mock verifier)
        guard = 0;
        while (boot_pass !== 1'b1 && guard < 2000000) begin @(posedge clk); guard = guard+1; end
        `EXPECT_TRUE(boot_pass === 1'b1, "secure_boot asserts boot_pass")
        `EXPECT_TRUE(boot_fail === 1'b0, "secure_boot never asserts boot_fail")
        if (boot_pass === 1'b1) begin
            apb_r(32'h2000_0000);
            `EXPECT_EQ(rd[2:0], 3'd4, "boot APB status==SUCCESS")
        end

        `TB_REPORT("SEC_CHAIN")
    end

endmodule
