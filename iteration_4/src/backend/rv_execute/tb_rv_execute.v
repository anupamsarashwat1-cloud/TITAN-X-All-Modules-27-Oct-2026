`timescale 1ns / 1ps

module tb_rv_execute();

    logic clk;
    logic rst_n;
    logic stall;
    logic flush;
    logic pc_in;
    logic rs1_data;
    logic rs2_data;
    logic imm;
    logic rd_in;
    logic rs1_addr;
    logic rs2_addr;
    logic funct3;
    logic funct7;
    logic opcode;
    logic alu_op;
    logic mem_read;
    logic mem_write;
    logic reg_write;
    logic branch;
    logic jal;
    logic jalr;
    logic is_amo;
    logic amo_funct5;
    logic valid_in;
    logic fwd_mem_data;
    logic fwd_mem_valid;
    logic fwd_mem_rd;
    logic fwd_wb_data;
    logic fwd_wb_valid;
    logic fwd_wb_rd;
    logic fpu_result;
    logic fpu_valid;
    logic fpu_done;
    logic alu_result;
    logic rs2_out;
    logic rd_out;
    logic funct3_out;
    logic opcode_out;
    logic mem_read_out;
    logic mem_write_out;
    logic reg_write_out;
    logic is_amo_out;
    logic amo_funct5_out;
    logic valid_out;
    logic mul_div_stall;
    logic branch_taken;
    logic branch_target;
    logic lr_addr;
    logic lr_valid;

    // DUT Instantiation
    rv_execute uut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush),
        .pc_in(pc_in),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .imm(imm),
        .rd_in(rd_in),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .funct3(funct3),
        .funct7(funct7),
        .opcode(opcode),
        .alu_op(alu_op),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .reg_write(reg_write),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .is_amo(is_amo),
        .amo_funct5(amo_funct5),
        .valid_in(valid_in),
        .fwd_mem_data(fwd_mem_data),
        .fwd_mem_valid(fwd_mem_valid),
        .fwd_mem_rd(fwd_mem_rd),
        .fwd_wb_data(fwd_wb_data),
        .fwd_wb_valid(fwd_wb_valid),
        .fwd_wb_rd(fwd_wb_rd),
        .fpu_result(fpu_result),
        .fpu_valid(fpu_valid),
        .fpu_done(fpu_done),
        .alu_result(alu_result),
        .rs2_out(rs2_out),
        .rd_out(rd_out),
        .funct3_out(funct3_out),
        .opcode_out(opcode_out),
        .mem_read_out(mem_read_out),
        .mem_write_out(mem_write_out),
        .reg_write_out(reg_write_out),
        .is_amo_out(is_amo_out),
        .amo_funct5_out(amo_funct5_out),
        .valid_out(valid_out),
        .mul_div_stall(mul_div_stall),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .lr_addr(lr_addr),
        .lr_valid(lr_valid)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_execute.vcd");
        $dumpvars(0, tb_rv_execute);

        // 1. Initialize all data inputs
        stall = 0;
        flush = 0;
        pc_in = 0;
        rs1_data = 0;
        rs2_data = 0;
        imm = 0;
        rd_in = 0;
        rs1_addr = 0;
        rs2_addr = 0;
        funct3 = 0;
        funct7 = 0;
        opcode = 0;
        alu_op = 0;
        mem_read = 0;
        mem_write = 0;
        reg_write = 0;
        branch = 0;
        jal = 0;
        jalr = 0;
        is_amo = 0;
        amo_funct5 = 0;
        valid_in = 0;
        fwd_mem_data = 0;
        fwd_mem_valid = 0;
        fwd_mem_rd = 0;
        fwd_wb_data = 0;
        fwd_wb_valid = 0;
        fwd_wb_rd = 0;
        fpu_result = 0;
        fpu_valid = 0;
        fpu_done = 0;

        // 2. Assert Resets
        #10;
        rst_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        rst_n = 1;
        #20;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
            stall = $random;
            flush = $random;
            pc_in = $random;
            rs1_data = $random;
            rs2_data = $random;
            imm = $random;
            rd_in = $random;
            rs1_addr = $random;
            rs2_addr = $random;
            funct3 = $random;
            funct7 = $random;
            opcode = $random;
            alu_op = $random;
            mem_read = $random;
            mem_write = $random;
            reg_write = $random;
            branch = $random;
            jal = $random;
            jalr = $random;
            is_amo = $random;
            amo_funct5 = $random;
            valid_in = $random;
            fwd_mem_data = $random;
            fwd_mem_valid = $random;
            fwd_mem_rd = $random;
            fwd_wb_data = $random;
            fwd_wb_valid = $random;
            fwd_wb_rd = $random;
            fpu_result = $random;
            fpu_valid = $random;
            fpu_done = $random;
        end

        #1000;
        $finish;
    end

endmodule
