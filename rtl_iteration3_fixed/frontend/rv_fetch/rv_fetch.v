// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — RISC-V Instruction Fetch Stage (RV64I)
`timescale 1ns/1ps
`include "params.vh"

module rv_fetch #(
    parameter RESET_PC = `RESET_PC
) (
    input  wire        clk,
    input  wire        rst_n,
    // Hazard/control
    input  wire        stall,
    input  wire        flush,
    input  wire        branch_taken,
    input  wire [63:0] branch_target,
    // Instruction memory (AXI4-Lite AR/R)
    output reg  [63:0] imem_addr,
    output reg         imem_arvalid,
    input  wire        imem_arready,
    input  wire [31:0] imem_rdata,
    input  wire        imem_rvalid,
    input  wire [1:0]  imem_rresp,
    // To decode stage
    output reg  [63:0] pc_out,
    output reg  [31:0] instr_out,
    output reg         valid_out
);
    reg [63:0] pc;

    // Fetch FSM
    localparam F_IDLE  = 2'd0;
    localparam F_REQ   = 2'd1;
    localparam F_WAIT  = 2'd2;
    reg [1:0] fstate;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc           <= RESET_PC;
            imem_addr    <= RESET_PC;
            imem_arvalid <= 1'b0;
            pc_out       <= 64'h0;
            instr_out    <= 32'h0000_0013; // NOP
            valid_out    <= 1'b0;
            fstate       <= F_REQ;
        end else begin
            if (flush || branch_taken) begin
                pc           <= branch_target;
                imem_addr    <= branch_target;
                imem_arvalid <= 1'b1;
                valid_out    <= 1'b0;
                fstate       <= F_WAIT;
            end else if (!stall) begin
                case (fstate)
                    F_REQ: begin
                        imem_addr    <= pc;
                        imem_arvalid <= 1'b1;
                        fstate       <= F_WAIT;
                    end
                    F_WAIT: begin
                        if (imem_arready) imem_arvalid <= 1'b0;
                        if (imem_rvalid) begin
                            pc_out    <= pc;
                            instr_out <= imem_rdata;
                            valid_out <= (imem_rresp == 2'b00);
                            pc        <= pc + 64'd4;
                            fstate    <= F_REQ;
                        end
                    end
                    default: fstate <= F_REQ;
                endcase
            end
        end
    end
endmodule
