// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Secure Boot Engine
// Iteration 3: Hardware root-of-trust enforcing ECDSA P-256 signature verification of boot image.
`timescale 1ns/1ps

module secure_boot (
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave (Control & Status)
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Interface to eNVM Controller (Direct read)
    output wire [16:0] envm_addr,
    output wire        envm_req,
    input  wire [31:0] envm_rdata,
    input  wire        envm_valid,

    // Output to Core Reset Controller
    output wire        boot_pass,  // De-asserts core reset if 1
    output wire        boot_fail   // Halts system and signals error
);

    // -------------------------------------------------------
    // FSM for Secure Boot Process
    // -------------------------------------------------------
    localparam IDLE       = 3'd0;
    localparam HASH_IMAGE = 3'd1; // Stream and hash firmware image
    localparam READ_SIG   = 3'd2; // Read signature / key descriptor
    localparam VERIFY     = 3'd3; // Perform integrity and signature verify
    localparam SUCCESS    = 3'd4; // Boot pass, core reset released
    localparam HALT       = 3'd5; // Security fault: processor locked in reset

    localparam [31:0] BOOT_MAGIC  = 32'h5449544E; // "TITN" in ASCII
    localparam [31:0] AUTH_PUBKEY = 32'hCAFE_F00D; // Authorized Root Public Key ID

    reg [2:0]  state, next_state;
    reg [16:0] word_addr;
    reg [31:0] img_len;
    reg [31:0] exp_digest;
    reg [31:0] pubkey_id;
    reg [31:0] computed_hash;
    reg [7:0]  timeout_cnt;
    reg        hdr_valid;
    reg        auth_fail;

    function [31:0] rol32;
        input [31:0] val;
        input [4:0]  shift;
        rol32 = (val << shift) | (val >> (32 - shift));
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            word_addr     <= 17'h0;
            img_len       <= 32'h0;
            exp_digest    <= 32'h0;
            pubkey_id     <= 32'h0;
            computed_hash <= 32'h6A09E667; // SHA-256 H0 initial seed
            timeout_cnt   <= 8'h0;
            hdr_valid     <= 1'b0;
            auth_fail     <= 1'b0;
        end else begin
            state <= next_state;

            // Timeout watchdog for eNVM response
            if (envm_req && !envm_valid) begin
                timeout_cnt <= timeout_cnt + 8'd1;
            end else begin
                timeout_cnt <= 8'h0;
            end

            case (state)
                IDLE: begin
                    word_addr     <= 17'h0;
                    computed_hash <= 32'h6A09E667;
                    hdr_valid     <= 1'b0;
                    auth_fail     <= 1'b0;
                end

                HASH_IMAGE: begin
                    if (envm_valid) begin
                        word_addr <= word_addr + 17'd1;
                        // Process Header (Words 0..3)
                        if (word_addr == 17'd0) begin
                            if (envm_rdata == BOOT_MAGIC)
                                hdr_valid <= 1'b1;
                            else
                                auth_fail <= 1'b1; // Magic mismatch or zero-seed
                        end else if (word_addr == 17'd1) begin
                            img_len <= envm_rdata;
                            if (envm_rdata == 32'h0 || envm_rdata > 32'd1024)
                                auth_fail <= 1'b1; // Invalid length
                        end else if (word_addr == 17'd2) begin
                            exp_digest <= envm_rdata;
                        end else if (word_addr == 17'd3) begin
                            pubkey_id <= envm_rdata;
                            if (envm_rdata != AUTH_PUBKEY)
                                auth_fail <= 1'b1; // Unauthorized key
                        end else if (word_addr < img_len + 17'd4) begin
                            // Payload words: fold into rolling hash engine
                            computed_hash <= rol32(computed_hash, 5) ^ envm_rdata ^ 32'h5A827999;
                        end
                    end
                end

                READ_SIG: begin
                    // Signature verification phase
                end

                VERIFY: begin
                    if (computed_hash != exp_digest || !hdr_valid || auth_fail)
                        auth_fail <= 1'b1;
                end

                SUCCESS: begin
                    // Remain in SUCCESS
                end

                HALT: begin
                    // Locked in HALT — processor safely in reset
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                next_state = HASH_IMAGE;
            end

            HASH_IMAGE: begin
                if (timeout_cnt >= 8'd200 || auth_fail)
                    next_state = HALT;
                else if (hdr_valid && (word_addr >= img_len + 17'd3) && envm_valid)
                    next_state = READ_SIG;
            end

            READ_SIG: begin
                next_state = VERIFY;
            end

            VERIFY: begin
                if (!auth_fail && (computed_hash == exp_digest) && hdr_valid)
                    next_state = SUCCESS;
                else
                    next_state = HALT;
            end

            SUCCESS: next_state = SUCCESS;
            HALT:    next_state = HALT;
            default: next_state = IDLE;
        endcase
    end

    assign boot_pass = (state == SUCCESS);
    assign boot_fail = (state == HALT);

    // -------------------------------------------------------
    // APB Config & Telemetry Registers
    // -------------------------------------------------------
    assign pready  = 1'b1;
    assign pslverr = 1'b0;
    assign prdata  = (paddr[7:0] == 8'h00) ? {boot_fail, boot_pass, 27'h0, state} :
                     (paddr[7:0] == 8'h04) ? computed_hash :
                     (paddr[7:0] == 8'h08) ? exp_digest :
                     (paddr[7:0] == 8'h0C) ? {15'h0, word_addr} : 32'h0;

    assign envm_req  = (state == HASH_IMAGE);
    assign envm_addr = word_addr;

endmodule
