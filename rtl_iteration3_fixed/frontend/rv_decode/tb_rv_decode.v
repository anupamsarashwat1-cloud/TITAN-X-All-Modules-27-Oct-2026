`timescale 1ns / 1ps

module tb_rv_decode();

    logic clk;
    logic rst_n;
    logic stall;
    logic flush;
    logic pc_in;
    logic instr_in;
    logic valid_in;
    logic wb_rd;
    logic wb_data;
    logic wb_we;
    logic pc_out;
    logic rs1_data;
    logic rs2_data;
    logic imm;
    logic rd;
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
    logic valid_out;

    // DUT Instantiation
    rv_decode uut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush),
        .pc_in(pc_in),
        .instr_in(instr_in),
        .valid_in(valid_in),
        .wb_rd(wb_rd),
        .wb_data(wb_data),
        .wb_we(wb_we),
        .pc_out(pc_out),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .imm(imm),
        .rd(rd),
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
        .valid_out(valid_out)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_decode.vcd");
        $dumpvars(0, tb_rv_decode);

        // 1. Initialize all data inputs
        stall = 0;
        flush = 0;
        pc_in = 0;
        instr_in = 0;
        valid_in = 0;
        wb_rd = 0;
        wb_data = 0;
        wb_we = 0;

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
            instr_in = $random;
            valid_in = $random;
            wb_rd = $random;
            wb_data = $random;
            wb_we = $random;
        end

        #1000;
        $finish;
    end

endmodule
