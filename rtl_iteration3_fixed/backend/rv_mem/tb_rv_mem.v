`timescale 1ns / 1ps

module tb_rv_mem();

    logic clk;
    logic rst_n;
    logic flush;
    logic alu_result;
    logic rs2_data;
    logic rd_in;
    logic funct3;
    logic opcode;
    logic mem_read;
    logic mem_write;
    logic reg_write;
    logic valid_in;
    logic dmem_awvalid;
    logic dmem_awready;
    logic dmem_awaddr;
    logic dmem_wvalid;
    logic dmem_wready;
    logic dmem_wdata;
    logic dmem_wstrb;
    logic dmem_bvalid;
    logic dmem_bready;
    logic dmem_arvalid;
    logic dmem_arready;
    logic dmem_araddr;
    logic dmem_rvalid;
    logic dmem_rready;
    logic dmem_rdata;
    logic dmem_rresp;
    logic result;
    logic rd_out;
    logic reg_write_out;
    logic valid_out;
    logic fwd_mem_data;
    logic fwd_mem_rd;
    logic fwd_mem_valid;
    logic mem_stall;

    // DUT Instantiation
    rv_mem uut (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .alu_result(alu_result),
        .rs2_data(rs2_data),
        .rd_in(rd_in),
        .funct3(funct3),
        .opcode(opcode),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .reg_write(reg_write),
        .valid_in(valid_in),
        .dmem_awvalid(dmem_awvalid),
        .dmem_awready(dmem_awready),
        .dmem_awaddr(dmem_awaddr),
        .dmem_wvalid(dmem_wvalid),
        .dmem_wready(dmem_wready),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_bvalid(dmem_bvalid),
        .dmem_bready(dmem_bready),
        .dmem_arvalid(dmem_arvalid),
        .dmem_arready(dmem_arready),
        .dmem_araddr(dmem_araddr),
        .dmem_rvalid(dmem_rvalid),
        .dmem_rready(dmem_rready),
        .dmem_rdata(dmem_rdata),
        .dmem_rresp(dmem_rresp),
        .result(result),
        .rd_out(rd_out),
        .reg_write_out(reg_write_out),
        .valid_out(valid_out),
        .fwd_mem_data(fwd_mem_data),
        .fwd_mem_rd(fwd_mem_rd),
        .fwd_mem_valid(fwd_mem_valid),
        .mem_stall(mem_stall)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_mem.vcd");
        $dumpvars(0, tb_rv_mem);

        // 1. Initialize all data inputs
        flush = 0;
        alu_result = 0;
        rs2_data = 0;
        rd_in = 0;
        funct3 = 0;
        opcode = 0;
        mem_read = 0;
        mem_write = 0;
        reg_write = 0;
        valid_in = 0;
        dmem_awready = 0;
        dmem_wready = 0;
        dmem_bvalid = 0;
        dmem_arready = 0;
        dmem_rvalid = 0;
        dmem_rdata = 0;
        dmem_rresp = 0;

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
            flush = $random;
            alu_result = $random;
            rs2_data = $random;
            rd_in = $random;
            funct3 = $random;
            opcode = $random;
            mem_read = $random;
            mem_write = $random;
            reg_write = $random;
            valid_in = $random;
            dmem_awready = $random;
            dmem_wready = $random;
            dmem_bvalid = $random;
            dmem_arready = $random;
            dmem_rvalid = $random;
            dmem_rdata = $random;
            dmem_rresp = $random;
        end

        #1000;
        $finish;
    end

endmodule
