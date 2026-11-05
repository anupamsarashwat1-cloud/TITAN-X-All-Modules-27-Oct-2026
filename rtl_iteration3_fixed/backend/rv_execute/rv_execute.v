// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — RV64GC Execute / ALU Stage
// Iteration 3: Adds M-extension (MUL/DIV) + A-extension (Atomics)
// Target: SCL 180nm, 125-200 MHz
`timescale 1ns/1ps
`include "params.vh"
`include "isa_pkg.vh"

module rv_execute (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,
    // From decode
    input  wire [63:0] pc_in,
    input  wire [63:0] rs1_data,
    input  wire [63:0] rs2_data,
    input  wire [63:0] imm,
    input  wire [4:0]  rd_in,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire [6:0]  opcode,
    input  wire [4:0]  alu_op,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire        reg_write,
    input  wire        branch,
    input  wire        jal,
    input  wire        jalr,
    input  wire        is_amo,      // A-extension: AMO instruction
    input  wire [4:0]  amo_funct5,  // AMO operation code [31:27]
    input  wire        valid_in,
    // Forwarding from MEM and WB
    input  wire [63:0] fwd_mem_data,
    input  wire        fwd_mem_valid,
    input  wire [4:0]  fwd_mem_rd,
    input  wire [63:0] fwd_wb_data,
    input  wire        fwd_wb_valid,
    input  wire [4:0]  fwd_wb_rd,
    // FPU result (registered from rv_fpu, arrives same cycle as ex stage)
    input  wire [63:0] fpu_result,
    input  wire        fpu_valid,
    input  wire        fpu_done,
    // To MEM stage
    output reg  [63:0] alu_result,
    output reg  [63:0] rs2_out,
    output reg  [4:0]  rd_out,
    output reg  [2:0]  funct3_out,
    output reg  [6:0]  opcode_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         reg_write_out,
    output reg         is_amo_out,
    output reg  [4:0]  amo_funct5_out,
    output reg         valid_out,
    // Stall to fetch/decode (MUL/DIV multi-cycle)
    output wire        mul_div_stall,
    // Branch resolution (back to fetch)
    output reg         branch_taken,
    output reg  [63:0] branch_target,
    // LR/SC reservation (exported to memory stage)
    output reg  [63:0] lr_addr,
    output reg         lr_valid
);

    // -------------------------------------------------------
    // Forwarding MUXes
    // -------------------------------------------------------
    wire [63:0] src1 = (fwd_mem_valid && (fwd_mem_rd == rs1_addr) && (rs1_addr != 5'h0)) ? fwd_mem_data :
                       (fwd_wb_valid  && (fwd_wb_rd  == rs1_addr) && (rs1_addr != 5'h0)) ? fwd_wb_data  :
                       rs1_data;

    wire [63:0] src2_reg = (fwd_mem_valid && (fwd_mem_rd == rs2_addr) && (rs2_addr != 5'h0)) ? fwd_mem_data :
                           (fwd_wb_valid  && (fwd_wb_rd  == rs2_addr) && (rs2_addr != 5'h0)) ? fwd_wb_data  :
                           rs2_data;

    // ALU source B: immediate for I/S/B/U/J, register for R-type
    wire use_imm = (opcode == `OP_IMM)   || (opcode == `OP_IMM64) ||
                   (opcode == `OP_LOAD)  || (opcode == `OP_LOAD_FP) ||
                   (opcode == `OP_STORE) || (opcode == `OP_STORE_FP) ||
                   (opcode == `OP_BRANCH)||
                   (opcode == `OP_JAL)   || (opcode == `OP_JALR)  ||
                   (opcode == `OP_LUI)   || (opcode == `OP_AUIPC);

    wire [63:0] src2 = use_imm ? imm : src2_reg;

    // -------------------------------------------------------
    // Integer ALU (combinational)
    // -------------------------------------------------------
    reg [63:0] alu_res_comb;
    always @(*) begin
        case (alu_op)
            `ALU_ADD:    alu_res_comb = src1 + src2;
            `ALU_SUB:    alu_res_comb = src1 - src2;
            `ALU_SLT:    alu_res_comb = ($signed(src1) < $signed(src2)) ? 64'd1 : 64'd0;
            `ALU_SLTU:   alu_res_comb = (src1 < src2) ? 64'd1 : 64'd0;
            `ALU_XOR:    alu_res_comb = src1 ^ src2;
            `ALU_OR:     alu_res_comb = src1 | src2;
            `ALU_AND:    alu_res_comb = src1 & src2;
            `ALU_SLL:    alu_res_comb = src1 << src2[5:0];
            `ALU_SRL:    alu_res_comb = src1 >> src2[5:0];
            `ALU_SRA:    alu_res_comb = $signed(src1) >>> src2[5:0];
            `ALU_LUI:    alu_res_comb = src2;
            `ALU_AUIPC:  alu_res_comb = pc_in + src2;
            `ALU_COPY_B: alu_res_comb = src2;
            // MUL/DIV: handled in mul_div unit; pass through to avoid latches
            default:     alu_res_comb = src1 + src2;
        endcase
    end

    // -------------------------------------------------------
    // M-Extension: 2-Cycle Pipelined Multiplier
    // -------------------------------------------------------
    wire is_mul = (alu_op == `ALU_MUL)  || (alu_op == `ALU_MULH) ||
                  (alu_op == `ALU_MULHSU)|| (alu_op == `ALU_MULHU);
    wire is_div = (alu_op == `ALU_DIV)  || (alu_op == `ALU_DIVU) ||
                  (alu_op == `ALU_REM)  || (alu_op == `ALU_REMU);
    wire is_mext = is_mul || is_div;

    // Multiplier: 2-stage pipeline (Stage 1: booth encode, Stage 2: accumulate)
    // 128-bit product for MULH variants
    reg [127:0] mul_stage1_product;
    reg [4:0]   mul_stage1_op;
    reg         mul_stage1_valid;
    reg [63:0]  mul_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_stage1_product <= 128'h0;
            mul_stage1_op      <= 5'h0;
            mul_stage1_valid   <= 1'b0;
        end else if (is_mul && valid_in && !stall) begin
            // Stage 1: compute 128-bit product
            case (alu_op)
                `ALU_MUL,
                `ALU_MULH:   mul_stage1_product <= $signed(src1) * $signed(src2);
                `ALU_MULHSU: mul_stage1_product <= $signed(src1) * $unsigned(src2);
                `ALU_MULHU:  mul_stage1_product <= src1 * src2;
                default:     mul_stage1_product <= 128'h0;
            endcase
            mul_stage1_op    <= alu_op;
            mul_stage1_valid <= 1'b1;
        end else begin
            mul_stage1_valid <= 1'b0;
        end
    end

    always @(*) begin
        case (mul_stage1_op)
            `ALU_MUL:    mul_result = mul_stage1_product[63:0];
            `ALU_MULH,
            `ALU_MULHSU,
            `ALU_MULHU:  mul_result = mul_stage1_product[127:64];
            default:     mul_result = mul_stage1_product[63:0];
        endcase
    end

    // Divider: non-restoring radix-2, 64-cycle maximum
    reg [63:0]  div_dividend, div_divisor;
    reg [63:0]  div_quotient, div_remainder;
    reg [5:0]   div_cycle;
    reg         div_busy, div_signed;
    reg         div_is_rem;
    reg         div_neg_q, div_neg_r;
    reg [63:0]  div_result;
    reg         div_done;

    // Absolute values for signed division
    wire [63:0] src1_abs = ($signed(src1) < 0) ? (~src1 + 64'd1) : src1;
    wire [63:0] src2_abs = ($signed(src2) < 0) ? (~src2 + 64'd1) : src2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_busy      <= 1'b0;
            div_cycle     <= 6'd0;
            div_quotient  <= 64'h0;
            div_remainder <= 64'h0;
            div_done      <= 1'b0;
        end else begin
            div_done <= 1'b0;
            if (is_div && valid_in && !stall && !div_busy) begin
                // Start division
                div_dividend  <= (alu_op == `ALU_DIV || alu_op == `ALU_REM) ? src1_abs : src1;
                div_divisor   <= (alu_op == `ALU_DIV || alu_op == `ALU_REM) ? src2_abs : src2;
                div_quotient  <= 64'h0;
                div_remainder <= 64'h0;
                div_cycle     <= 6'd0;
                div_busy      <= 1'b1;
                div_signed    <= (alu_op == `ALU_DIV || alu_op == `ALU_REM);
                div_is_rem    <= (alu_op == `ALU_REM || alu_op == `ALU_REMU);
                div_neg_q     <= ((alu_op == `ALU_DIV) &&
                                  ($signed(src1) < 0) ^ ($signed(src2) < 0) &&
                                  (src2 != 64'h0));
                div_neg_r     <= ((alu_op == `ALU_REM) && ($signed(src1) < 0));
            end else if (div_busy) begin
                // Non-restoring shift-subtract
                if (div_cycle < 6'd63) begin
                    div_cycle <= div_cycle + 6'd1;
                    // Shift left: {remainder, quotient} << 1
                    div_remainder <= {div_remainder[62:0], div_dividend[63]};
                    div_dividend  <= {div_dividend[62:0], 1'b0};
                    if ({div_remainder[62:0], div_dividend[63]} >= div_divisor) begin
                        div_remainder <= {div_remainder[62:0], div_dividend[63]} - div_divisor;
                        div_quotient  <= {div_quotient[62:0], 1'b1};
                    end else begin
                        div_quotient  <= {div_quotient[62:0], 1'b0};
                    end
                end else begin
                    div_busy <= 1'b0;
                    div_done <= 1'b1;
                    // Handle division by zero
                    if (div_divisor == 64'h0) begin
                        div_quotient  <= 64'hFFFF_FFFF_FFFF_FFFF;
                        div_remainder <= div_dividend;
                    end
                end
            end
        end
    end

    always @(*) begin
        if (div_is_rem) begin
            div_result = div_neg_r ? (~div_remainder + 64'd1) : div_remainder;
        end else begin
            div_result = div_neg_q ? (~div_quotient + 64'd1) : div_quotient;
        end
    end

    // MUL/DIV stall: assert while divider is running or mul pipeline pending
    assign mul_div_stall = div_busy || (is_mul && valid_in);

    // Final M-ext result mux
    wire [63:0] mext_result = is_div ? div_result : mul_result;

    // -------------------------------------------------------
    // A-Extension: LR/SC Reservation
    // -------------------------------------------------------
    // LR: set reservation; SC: check reservation
    // AMO arithmetic operations handled in memory stage (read-modify-write)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lr_addr  <= 64'h0;
            lr_valid <= 1'b0;
        end else if (is_amo && valid_in && (amo_funct5 == `AMO_LR) && !stall) begin
            lr_addr  <= src1;     // LR: address = rs1
            lr_valid <= 1'b1;
        end else if (is_amo && valid_in && (amo_funct5 == `AMO_SC) && !stall) begin
            // SC clears reservation regardless of success/failure
            lr_valid <= 1'b0;
        end
    end

    // -------------------------------------------------------
    // Branch Decision (combinational)
    // -------------------------------------------------------
    reg branch_comb;
    always @(*) begin
        branch_comb = 1'b0;
        if (branch) begin
            case (funct3)
                3'b000: branch_comb = (src1 == src2_reg);
                3'b001: branch_comb = (src1 != src2_reg);
                3'b100: branch_comb = ($signed(src1) < $signed(src2_reg));
                3'b101: branch_comb = ($signed(src1) >= $signed(src2_reg));
                3'b110: branch_comb = (src1 < src2_reg);
                3'b111: branch_comb = (src1 >= src2_reg);
                default: branch_comb = 1'b0;
            endcase
        end else if (jal || jalr) begin
            branch_comb = 1'b1;
        end
    end

    wire [63:0] branch_tgt = jalr ? ((src1 + imm) & ~64'd1) : (pc_in + imm);

    // -------------------------------------------------------
    // Result Mux: Integer / M-ext / FPU
    // -------------------------------------------------------
    wire is_fp_op = (opcode == `OP_FP)    || (opcode == `OP_FMADD) ||
                    (opcode == `OP_FMSUB)  || (opcode == `OP_FNMSUB) ||
                    (opcode == `OP_FNMADD);

    wire [63:0] final_alu_res = (jal || jalr)   ? (pc_in + 64'd4)  :
                                 is_fp_op         ? fpu_result        :
                                 is_mext          ? mext_result        :
                                                    alu_res_comb;

    // -------------------------------------------------------
    // Pipeline Register
    // -------------------------------------------------------
    wire flush_ex_1, flush_ex_2, flush_ex_3, flush_ex_4;
    BUFX4 u_buf_flush_ex1 ( .A(flush), .Y(flush_ex_1) );
    BUFX4 u_buf_flush_ex2 ( .A(flush), .Y(flush_ex_2) );
    BUFX4 u_buf_flush_ex3 ( .A(flush), .Y(flush_ex_3) );
    BUFX4 u_buf_flush_ex4 ( .A(flush), .Y(flush_ex_4) );

    // Block 1: alu_result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result    <= 64'h0;
        end else if (flush_ex_1) begin
            alu_result    <= 64'h0;
        end else if (!stall && !mul_div_stall) begin
            alu_result    <= final_alu_res;
        end
    end

    // Block 2: rs2_out
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rs2_out       <= 64'h0;
        end else if (flush_ex_2) begin
            rs2_out       <= 64'h0;
        end else if (!stall && !mul_div_stall) begin
            rs2_out       <= src2_reg;
        end
    end
    
    // Block 3: branch_target
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            branch_target <= 64'h0;
        end else if (flush_ex_3) begin
            branch_target <= 64'h0;
        end else if (!stall && !mul_div_stall) begin
            branch_target <= branch_tgt;
        end
    end

    // Block 4: Control and Branch outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_out        <= 5'h0;
            funct3_out    <= 3'h0;
            opcode_out    <= 7'h0;
            mem_read_out  <= 1'b0;
            mem_write_out <= 1'b0;
            reg_write_out <= 1'b0;
            is_amo_out    <= 1'b0;
            amo_funct5_out<= 5'h0;
            valid_out     <= 1'b0;
            branch_taken  <= 1'b0;
        end else if (flush_ex_4) begin
            rd_out        <= 5'h0;
            funct3_out    <= 3'h0;
            opcode_out    <= 7'h0;
            mem_read_out  <= 1'b0;
            mem_write_out <= 1'b0;
            reg_write_out <= 1'b0;
            is_amo_out    <= 1'b0;
            amo_funct5_out<= 5'h0;
            valid_out     <= 1'b0;
            branch_taken  <= 1'b0;
        end else if (!stall && !mul_div_stall) begin
            rd_out        <= rd_in;
            funct3_out    <= funct3;
            opcode_out    <= opcode;
            mem_read_out  <= mem_read;
            mem_write_out <= mem_write;
            reg_write_out <= reg_write && (!is_fp_op || fpu_done);
            is_amo_out    <= is_amo;
            amo_funct5_out<= amo_funct5;
            valid_out     <= valid_in;
            branch_taken  <= branch_comb && valid_in;
        end
    end

endmodule
