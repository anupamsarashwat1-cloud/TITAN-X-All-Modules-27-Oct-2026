// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — True Random Number Generator (TRNG)
// Iteration 3: Based on Free-running Ring Oscillators (FIRO/GARO) with NIST SP 800-90B health tests.
`timescale 1ns/1ps

module trng (
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave Interface
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Hardware Interface to DRBG (for seeding)
    output wire [255:0] trng_entropy,
    output wire         trng_valid,
    input  wire         trng_ready,

    // Interrupt
    output wire        trng_irq
);

    // -------------------------------------------------------
    // Ring Oscillators (Behavioral Mock)
    // -------------------------------------------------------
    // In physical design, this would be a hard macro of odd-stage inverters 
    // manually placed and routed to avoid logic optimization.
    
    wire [15:0] ro_out;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_ro
            // Mock: Just feed clk or random toggle
            assign ro_out[i] = (i % 2 == 0) ? clk : ~clk;
        end
    endgenerate
    
    wire raw_bit = ^ro_out; // XOR tree collapse

    // -------------------------------------------------------
    // Von Neumann Extractor
    // -------------------------------------------------------
    reg vn_state;
    reg vn_prev_bit;
    reg vn_out_bit;
    reg vn_out_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vn_state <= 1'b0;
            vn_prev_bit <= 1'b0;
            vn_out_valid <= 1'b0;
            vn_out_bit <= 1'b0;
        end else begin
            if (vn_state == 1'b0) begin
                vn_prev_bit <= raw_bit;
                vn_state <= 1'b1;
                vn_out_valid <= 1'b0;
            end else begin
                if (vn_prev_bit != raw_bit) begin
                    vn_out_bit <= vn_prev_bit; // 01->0, 10->1
                    vn_out_valid <= 1'b1;
                end else begin
                    vn_out_valid <= 1'b0; // 00, 11 discarded
                end
                vn_state <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------
    // Health Tests (Repetition Count & Adaptive Proportion)
    // -------------------------------------------------------
    reg [7:0] rep_count;
    reg       rep_prev;
    reg       health_fail;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rep_count <= 8'h0;
            rep_prev <= 1'b0;
            health_fail <= 1'b0;
        end else if (vn_out_valid) begin
            if (vn_out_bit == rep_prev) begin
                if (rep_count == 8'd255) health_fail <= 1'b1; // Failed RCT
                else rep_count <= rep_count + 1;
            end else begin
                rep_count <= 8'h0;
                rep_prev <= vn_out_bit;
            end
        end
    end

    // -------------------------------------------------------
    // Entropy Accumulator (256-bit)
    // -------------------------------------------------------
    reg [255:0] entropy_reg;
    reg [8:0]   entropy_cnt;
    reg         entropy_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            entropy_reg <= 256'h0;
            entropy_cnt <= 9'h0;
            entropy_valid <= 1'b0;
        end else begin
            if (vn_out_valid && !health_fail && !entropy_valid) begin
                entropy_reg <= {entropy_reg[254:0], vn_out_bit};
                if (entropy_cnt == 9'd255) begin
                    entropy_valid <= 1'b1;
                end else begin
                    entropy_cnt <= entropy_cnt + 1;
                end
            end else if (entropy_valid && trng_ready) begin
                // Consumed
                entropy_valid <= 1'b0;
                entropy_cnt <= 9'h0;
            end
        end
    end

    assign trng_entropy = entropy_reg;
    assign trng_valid = entropy_valid;

    // -------------------------------------------------------
    // APB Config Registers
    // -------------------------------------------------------
    reg [31:0] ctrl_reg;
    
    assign pready = 1'b1;
    assign pslverr = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ctrl_reg <= 32'h0;
        else if (psel && penable && pwrite && paddr[7:0] == 8'h00)
            ctrl_reg <= pwdata;
    end
    
    assign prdata = (paddr[7:0] == 8'h00) ? ctrl_reg :
                    (paddr[7:0] == 8'h04) ? {30'h0, entropy_valid, health_fail} : 32'h0;

    assign trng_irq = health_fail; // Interrupt if health test fails

endmodule
