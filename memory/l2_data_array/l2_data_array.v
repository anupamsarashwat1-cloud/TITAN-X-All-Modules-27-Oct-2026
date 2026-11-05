// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — L2 Data Array
// Banked compiled foundry SRAM macro storage array wrapping sram_32x64_180nm macros.
// Resolves DEF-ARCH-04 by replacing behavioral flip-flops with physical compiled hard macros.
// Provides 1-cycle synchronous read latency with full byte-write masking.
`timescale 1ns/1ps

module l2_data_array #(
    parameter DATA_W = 64,
    parameter DEPTH  = 8192,
    parameter ADDR_W = $clog2(DEPTH)
) (
    input  wire                clk,
    input  wire                rst_n,
    input  wire                cs,          // chip select
    input  wire                we,          // write enable (1=write, 0=read)
    input  wire [DATA_W/8-1:0] wmask,       // byte write mask
    input  wire [ADDR_W-1:0]   addr,        // word address
    input  wire [DATA_W-1:0]   din,         // write data
    output wire [DATA_W-1:0]   dout,        // read data (1-cycle synchronous latency)
    output reg                 dout_valid   // 1 cycle after read issued
);
    localparam WORDS_PER_BANK = 64;
    localparam NUM_BANKS      = (DEPTH + WORDS_PER_BANK - 1) / WORDS_PER_BANK;
    localparam BANK_SEL_W     = (NUM_BANKS > 1) ? $clog2(NUM_BANKS) : 1;

    wire [5:0] row_addr = addr[5:0];
    wire [BANK_SEL_W-1:0] bank_sel = (NUM_BANKS > 1) ? addr[ADDR_W-1:6] : 1'b0;

    wire [31:0] bank_dout_lo [0:NUM_BANKS-1];
    wire [31:0] bank_dout_hi [0:NUM_BANKS-1];

    genvar b;
    generate
        for (b = 0; b < NUM_BANKS; b = b + 1) begin : g_bank
            wire bank_cs  = cs && (bank_sel == b);
            wire bank_csb = ~bank_cs;
            wire bank_web = ~we;

            sram_32x64_180nm u_sram_lo (
                .clk0   (clk),
                .csb0   (bank_csb),
                .web0   (bank_web),
                .wmask0 (wmask[3:0]),
                .addr0  (row_addr),
                .din0   (din[31:0]),
                .dout0  (bank_dout_lo[b])
            );

            sram_32x64_180nm u_sram_hi (
                .clk0   (clk),
                .csb0   (bank_csb),
                .web0   (bank_web),
                .wmask0 (wmask[7:4]),
                .addr0  (row_addr),
                .din0   (din[63:32]),
                .dout0  (bank_dout_hi[b])
            );
        end
    endgenerate

    reg [BANK_SEL_W-1:0] bank_sel_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bank_sel_r <= {BANK_SEL_W{1'b0}};
            dout_valid <= 1'b0;
        end else begin
            bank_sel_r <= bank_sel;
            dout_valid <= cs && !we;
        end
    end

    assign dout = {bank_dout_hi[bank_sel_r], bank_dout_lo[bank_sel_r]};

endmodule
