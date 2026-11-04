// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Hardware Root-of-Trust Secure Boot Engine
// Enforces NIST FIPS 180-4 SHA-256 integrity and NIST FIPS 186-4 ECDSA P-256
// cryptographic authentication over the signed firmware image before core reset release.
`timescale 1ns/1ps

module secure_boot (
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave (Control & Status Telemetry)
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
    output wire        boot_fail   // Halts system and keeps core locked in reset if 1
);

    // -------------------------------------------------------
    // Constants
    // -------------------------------------------------------
    localparam [31:0] BOOT_MAGIC  = 32'h5449544E; // "TITN" in ASCII
    localparam [31:0] AUTH_PUBKEY = 32'hCAFE_F00D; // Authorized Root Public Key ID

    // -------------------------------------------------------
    // FSM States
    // -------------------------------------------------------
    localparam S_IDLE              = 5'd0;
    localparam S_READ_HEADER       = 5'd1;
    localparam S_READ_PAYLOAD_REQ  = 5'd2;
    localparam S_LOAD_SHA_SETUP    = 5'd3;
    localparam S_SUCCESS           = 5'd4;
    localparam S_HALT              = 5'd5;
    localparam S_LOAD_SHA_ACCESS   = 5'd6;
    localparam S_START_SHA_SETUP   = 5'd7;
    localparam S_START_SHA_ACCESS  = 5'd8;
    localparam S_WAIT_SHA          = 5'd9;
    localparam S_READ_SHA_SETUP    = 5'd10;
    localparam S_READ_SHA_ACCESS   = 5'd11;
    localparam S_READ_SHA_WAIT     = 5'd12;
    localparam S_READ_SHA_LATCH    = 5'd13;
    localparam S_LOAD_ECDSA_SETUP  = 5'd14;
    localparam S_LOAD_ECDSA_ACCESS = 5'd15;
    localparam S_START_ECDSA_SETUP = 5'd16;
    localparam S_START_ECDSA_ACCESS= 5'd17;
    localparam S_WAIT_ECDSA        = 5'd18;
    localparam S_READ_STATUS_SETUP = 5'd19;
    localparam S_READ_STATUS_ACCESS= 5'd20;
    localparam S_READ_STATUS_CHECK = 5'd21;
    reg [4:0]  state;
    reg [16:0] word_addr;
    reg [31:0] img_len;
    reg [31:0] pubkey_id;
    reg [31:0] exp_digest [0:7];
    reg [31:0] pubkey_qx  [0:7];
    reg [31:0] pubkey_qy  [0:7];
    reg [31:0] sig_r      [0:7];
    reg [31:0] sig_s      [0:7];
    reg [31:0] computed_hash [0:7];
    reg [31:0] payload_word;

    reg [11:0] timeout_cnt;
    reg        hdr_valid;
    reg        auth_fail;
    reg [4:0]  payload_idx;
    reg [4:0]  sha_read_idx;
    reg [5:0]  ecdsa_load_idx;

    // -------------------------------------------------------
    // Hardware SHA-256 Engine Instance
    // -------------------------------------------------------
    reg        sha_psel, sha_penable, sha_pwrite;
    reg [7:0]  sha_paddr;
    reg [31:0] sha_pwdata;
    wire [31:0] sha_prdata;
    wire       sha_pready, sha_done;

    sha256_engine u_sha256 (
        .clk(clk),
        .rst_n(rst_n),
        .psel(sha_psel),
        .penable(sha_penable),
        .pwrite(sha_pwrite),
        .paddr(sha_paddr),
        .pwdata(sha_pwdata),
        .prdata(sha_prdata),
        .pready(sha_pready),
        .irq(sha_done)
    );

    // -------------------------------------------------------
    // Hardware ECDSA P-256 Engine Instance
    // -------------------------------------------------------
    reg        ecdsa_psel, ecdsa_penable, ecdsa_pwrite;
    reg [31:0] ecdsa_paddr, ecdsa_pwdata;
    wire [31:0] ecdsa_prdata;
    wire       ecdsa_pready, ecdsa_pslverr, ecdsa_irq;

    ecdsa_engine u_ecdsa (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(ecdsa_paddr),
        .psel(ecdsa_psel),
        .penable(ecdsa_penable),
        .pwrite(ecdsa_pwrite),
        .pwdata(ecdsa_pwdata),
        .prdata(ecdsa_prdata),
        .pready(ecdsa_pready),
        .pslverr(ecdsa_pslverr),
        .ecdsa_irq(ecdsa_irq)
    );

    // -------------------------------------------------------
    // Secure Boot FSM Execution
    // -------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            word_addr     <= 17'h0;
            img_len       <= 32'h0;
            pubkey_id     <= 32'h0;
            timeout_cnt   <= 12'h0;
            hdr_valid     <= 1'b0;
            auth_fail     <= 1'b0;
            payload_idx   <= 5'h0;
            sha_read_idx  <= 5'h0;
            ecdsa_load_idx<= 6'h0;
            payload_word  <= 32'h0;

            sha_psel      <= 1'b0;
            sha_penable   <= 1'b0;
            sha_pwrite    <= 1'b0;
            sha_paddr     <= 8'h0;
            sha_pwdata    <= 32'h0;

            ecdsa_psel    <= 1'b0;
            ecdsa_penable <= 1'b0;
            ecdsa_pwrite  <= 1'b0;
            ecdsa_paddr   <= 32'h0;
            ecdsa_pwdata  <= 32'h0;
        end else begin
            case (state)
                S_IDLE: begin
                    word_addr     <= 17'h0;
                    hdr_valid     <= 1'b0;
                    auth_fail     <= 1'b0;
                    timeout_cnt   <= 12'h0;
                    payload_idx   <= 5'h0;
                    sha_psel      <= 1'b0;
                    sha_penable   <= 1'b0;
                    ecdsa_psel    <= 1'b0;
                    ecdsa_penable <= 1'b0;
                    state         <= S_READ_HEADER;
                end

                S_READ_HEADER: begin
                    if (!envm_valid) begin
                        timeout_cnt <= timeout_cnt + 12'd1;
                        if (timeout_cnt >= 12'd1000) begin
                            auth_fail <= 1'b1;
                            state     <= S_HALT;
                        end
                    end else begin
                        timeout_cnt <= 12'h0;
                        word_addr   <= word_addr + 17'd1;
                        if (word_addr == 17'd0) begin
                            if (envm_rdata == BOOT_MAGIC)
                                hdr_valid <= 1'b1;
                            else begin
                                auth_fail <= 1'b1;
                                state     <= S_HALT;
                            end
                        end else if (word_addr == 17'd1) begin
                            img_len <= envm_rdata;
                            if (envm_rdata == 32'h0 || envm_rdata > 32'd1024) begin
                                auth_fail <= 1'b1;
                                state     <= S_HALT;
                            end
                        end else if (word_addr == 17'd2) begin
                            pubkey_id <= envm_rdata;
                            if (envm_rdata != AUTH_PUBKEY) begin
                                auth_fail <= 1'b1;
                                state     <= S_HALT;
                            end
                        end else if (word_addr >= 17'd3 && word_addr <= 17'd10) begin
                            exp_digest[word_addr - 17'd3] <= envm_rdata;
                        end else if (word_addr >= 17'd11 && word_addr <= 17'd18) begin
                            pubkey_qx[word_addr - 17'd11] <= envm_rdata;
                        end else if (word_addr >= 17'd19 && word_addr <= 17'd26) begin
                            pubkey_qy[word_addr - 17'd19] <= envm_rdata;
                        end else if (word_addr >= 17'd27 && word_addr <= 17'd34) begin
                            sig_r[word_addr - 17'd27] <= envm_rdata;
                        end else if (word_addr >= 17'd35 && word_addr <= 17'd42) begin
                            sig_s[word_addr - 17'd35] <= envm_rdata;
                            if (word_addr == 17'd42) begin
                                payload_idx <= 5'h0;
                                state       <= S_READ_PAYLOAD_REQ;
                            end
                        end
                    end
                end

                S_READ_PAYLOAD_REQ: begin
                    if (!envm_valid) begin
                        timeout_cnt <= timeout_cnt + 12'd1;
                        if (timeout_cnt >= 12'd1000) begin
                            auth_fail <= 1'b1;
                            state     <= S_HALT;
                        end
                    end else begin
                        timeout_cnt  <= 12'h0;
                        payload_word <= envm_rdata;
                        word_addr    <= word_addr + 17'd1;
                        state        <= S_LOAD_SHA_SETUP;
                    end
                end

                S_LOAD_SHA_SETUP: begin
                    sha_psel    <= 1'b1;
                    sha_penable <= 1'b0;
                    sha_pwrite  <= 1'b1;
                    sha_paddr   <= (payload_idx << 2);
                    sha_pwdata  <= payload_word;
                    state       <= S_LOAD_SHA_ACCESS;
                end

                S_LOAD_SHA_ACCESS: begin
                    sha_penable <= 1'b1;
                    sha_psel    <= 1'b1;
                    payload_idx <= payload_idx + 5'd1;
                    if (payload_idx + 5'd1 < img_len) begin
                        state <= S_READ_PAYLOAD_REQ;
                    end else begin
                        state <= S_START_SHA_SETUP;
                    end
                end

                S_START_SHA_SETUP: begin
                    sha_psel    <= 1'b1;
                    sha_penable <= 1'b0;
                    sha_pwrite  <= 1'b1;
                    sha_paddr   <= 8'h60;
                    sha_pwdata  <= 32'h1;
                    state       <= S_START_SHA_ACCESS;
                end

                S_START_SHA_ACCESS: begin
                    sha_penable <= 1'b1;
                    timeout_cnt <= 12'h0;
                    state       <= S_WAIT_SHA;
                end

                S_WAIT_SHA: begin
                    sha_psel    <= 1'b0;
                    sha_penable <= 1'b0;
                    sha_pwrite  <= 1'b0;
                    timeout_cnt <= timeout_cnt + 12'd1;
                    if (timeout_cnt >= 12'd300) begin
                        auth_fail <= 1'b1;
                        state     <= S_HALT;
                    end else if (sha_done) begin
                        timeout_cnt  <= 12'h0;
                        sha_read_idx <= 5'h0;
                        state        <= S_READ_SHA_SETUP;
                    end
                end

                S_READ_SHA_SETUP: begin
                    sha_psel    <= 1'b1;
                    sha_penable <= 1'b0;
                    sha_pwrite  <= 1'b0;
                    sha_paddr   <= 8'h40 + (sha_read_idx << 2);
                    state       <= S_READ_SHA_ACCESS;
                end

                S_READ_SHA_ACCESS: begin
                    sha_penable <= 1'b1;
                    state       <= S_READ_SHA_WAIT;
                end

                S_READ_SHA_WAIT: begin
                    // During this cycle, sha_psel=1 and sha_penable=1
                    // At the clock edge entering S_READ_SHA_LATCH, sha256_engine updates prdata
                    state       <= S_READ_SHA_LATCH;
                end

                S_READ_SHA_LATCH: begin
                    // Now sha_prdata has the clocked value
                    computed_hash[sha_read_idx] <= sha_prdata;
                    sha_psel    <= 1'b0;
                    sha_penable <= 1'b0;
                    if (sha_read_idx < 5'd7) begin
                        sha_read_idx <= sha_read_idx + 5'd1;
                        state        <= S_READ_SHA_SETUP;
                    end else begin
                        ecdsa_load_idx <= 6'h0;
                        state          <= S_LOAD_ECDSA_SETUP;
                    end
                end

                S_LOAD_ECDSA_SETUP: begin
                    ecdsa_psel    <= 1'b1;
                    ecdsa_penable <= 1'b0;
                    ecdsa_pwrite  <= 1'b1;
                    if (ecdsa_load_idx < 6'd8) begin
                        ecdsa_paddr  <= 32'h0000_0100 + (ecdsa_load_idx << 2);
                        ecdsa_pwdata <= computed_hash[ecdsa_load_idx];
                    end else if (ecdsa_load_idx < 6'd16) begin
                        ecdsa_paddr  <= 32'h0000_0200 + ((ecdsa_load_idx - 6'd8) << 2);
                        ecdsa_pwdata <= pubkey_qx[ecdsa_load_idx - 6'd8];
                    end else if (ecdsa_load_idx < 6'd24) begin
                        ecdsa_paddr  <= 32'h0000_0220 + ((ecdsa_load_idx - 6'd16) << 2);
                        ecdsa_pwdata <= pubkey_qy[ecdsa_load_idx - 6'd16];
                    end else if (ecdsa_load_idx < 6'd32) begin
                        ecdsa_paddr  <= 32'h0000_0300 + ((ecdsa_load_idx - 6'd24) << 2);
                        ecdsa_pwdata <= sig_r[ecdsa_load_idx - 6'd24];
                    end else begin
                        ecdsa_paddr  <= 32'h0000_0400 + ((ecdsa_load_idx - 6'd32) << 2);
                        ecdsa_pwdata <= sig_s[ecdsa_load_idx - 6'd32];
                    end
                    state <= S_LOAD_ECDSA_ACCESS;
                end

                S_LOAD_ECDSA_ACCESS: begin
                    ecdsa_penable  <= 1'b1;
                    ecdsa_load_idx <= ecdsa_load_idx + 6'd1;
                    if (ecdsa_load_idx + 6'd1 < 6'd40) begin
                        state <= S_LOAD_ECDSA_SETUP;
                    end else begin
                        state <= S_START_ECDSA_SETUP;
                    end
                end

                S_START_ECDSA_SETUP: begin
                    ecdsa_psel    <= 1'b1;
                    ecdsa_penable <= 1'b0;
                    ecdsa_pwrite  <= 1'b1;
                    ecdsa_paddr   <= 32'h0000_0000;
                    ecdsa_pwdata  <= 32'h0000_0001;
                    state         <= S_START_ECDSA_ACCESS;
                end

                S_START_ECDSA_ACCESS: begin
                    ecdsa_penable <= 1'b1;
                    timeout_cnt   <= 12'h0;
                    state         <= S_WAIT_ECDSA;
                end

                S_WAIT_ECDSA: begin
                    ecdsa_psel    <= 1'b0;
                    ecdsa_penable <= 1'b0;
                    ecdsa_pwrite  <= 1'b0;
                    timeout_cnt   <= timeout_cnt + 12'd1;

                    if (timeout_cnt >= 12'd3500) begin
                        auth_fail <= 1'b1;
                        state     <= S_HALT;
                    end else if (ecdsa_irq) begin
                        state <= S_READ_STATUS_SETUP;
                    end
                end

                S_READ_STATUS_SETUP: begin
                    ecdsa_psel    <= 1'b1;
                    ecdsa_penable <= 1'b0;
                    ecdsa_pwrite  <= 1'b0;
                    ecdsa_paddr   <= 32'h0000_0004;
                    state         <= S_READ_STATUS_ACCESS;
                end

                S_READ_STATUS_ACCESS: begin
                    ecdsa_penable <= 1'b1;
                    state         <= S_READ_STATUS_CHECK;
                end

                S_READ_STATUS_CHECK: begin
                    ecdsa_psel    <= 1'b0;
                    ecdsa_penable <= 1'b0;
                    if (computed_hash[0] == exp_digest[0] &&
                        computed_hash[1] == exp_digest[1] &&
                        computed_hash[2] == exp_digest[2] &&
                        computed_hash[3] == exp_digest[3] &&
                        computed_hash[4] == exp_digest[4] &&
                        computed_hash[5] == exp_digest[5] &&
                        computed_hash[6] == exp_digest[6] &&
                        computed_hash[7] == exp_digest[7] &&
                        ecdsa_prdata[2]  == 1'b1 &&
                        hdr_valid && !auth_fail) begin
                        state <= S_SUCCESS;
                    end else begin
                        auth_fail <= 1'b1;
                        state     <= S_HALT;
                    end
                end

                S_SUCCESS: begin
                    // Processor reset release
                end

                S_HALT: begin
                    // Security fault: locked in HALT
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    assign boot_pass = (state == S_SUCCESS);
    assign boot_fail = (state == S_HALT);

    // -------------------------------------------------------
    // APB Config & Telemetry Registers
    // -------------------------------------------------------
    assign pready  = 1'b1;
    assign pslverr = 1'b0;
    assign prdata  = (paddr[7:0] == 8'h00) ? {boot_fail, boot_pass, 25'h0, state} :
                     (paddr[7:0] == 8'h04) ? computed_hash[0] :
                     (paddr[7:0] == 8'h08) ? exp_digest[0] :
                     (paddr[7:0] == 8'h0C) ? {15'h0, word_addr} : 32'h0;

    assign envm_req  = (state == S_READ_HEADER || state == S_READ_PAYLOAD_REQ);
    assign envm_addr = word_addr;

endmodule
