// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — RV64GC Core Top
// Iteration 3: Integrates Integer Pipeline, FPU, BPU, MMU, I-Cache, D-Cache
`timescale 1ns/1ps
`include "params.vh"
`include "isa_pkg.vh"

module rv_core_top #(
    parameter HART_ID  = 0,
    parameter RESET_PC = `RESET_PC
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        irq_m_ext,   // External IRQ
    input  wire        irq_m_timer, // Timer IRQ
    input  wire        irq_m_soft,  // Software IRQ

    // AXI4 Master: Instruction Cache Refill
    output wire        imem_arvalid,
    input  wire        imem_arready,
    output wire [39:0] imem_araddr,
    output wire [7:0]  imem_arlen,
    output wire [2:0]  imem_arsize,
    output wire [1:0]  imem_arburst,
    input  wire        imem_rvalid,
    output wire        imem_rready,
    input  wire [63:0] imem_rdata,
    input  wire        imem_rlast,
    input  wire [1:0]  imem_rresp,

    // AXI4 Master: Data Cache Refill / Eviction / MMU PTW
    // Here we multiplex D-cache and PTW to a single core data port,
    // or assume the crossbar handles them. Let's provide unified AXI lines
    // for D-side. For simplicity, we assume D-Cache handles PTW traffic
    // or we expose them separately. We'll expose D-cache AXI.
    output wire        dmem_awvalid,
    input  wire        dmem_awready,
    output wire [39:0] dmem_awaddr,
    output wire [7:0]  dmem_awlen,
    output wire [2:0]  dmem_awsize,
    output wire [1:0]  dmem_awburst,
    output wire        dmem_wvalid,
    input  wire        dmem_wready,
    output wire [63:0] dmem_wdata,
    output wire [7:0]  dmem_wstrb,
    output wire        dmem_wlast,
    input  wire        dmem_bvalid,
    output wire        dmem_bready,
    input  wire [1:0]  dmem_bresp,

    output wire        dmem_arvalid,
    input  wire        dmem_arready,
    output wire [39:0] dmem_araddr,
    output wire [7:0]  dmem_arlen,
    output wire [2:0]  dmem_arsize,
    output wire [1:0]  dmem_arburst,
    output wire        dmem_arlock,
    input  wire        dmem_rvalid,
    output wire        dmem_rready,
    input  wire [63:0] dmem_rdata,
    input  wire        dmem_rlast,
    input  wire [1:0]  dmem_rresp,

    // L2 Snoop Port
    input  wire        snoop_valid,
    input  wire [39:0] snoop_addr,
    input  wire [1:0]  snoop_type,
    output wire        snoop_ack,
    output wire        snoop_data_valid,
    output wire [511:0] snoop_data,

    // Debug control
    input  wire        halt_req,
    input  wire        resume_req,
    output wire        hart_halted,
    output wire        hart_running
);

    // -------------------------------------------------------
    // Core state and CSR wires
    // -------------------------------------------------------
    wire [1:0]  priv_mode = 2'b11; // 11=M
    wire [63:0] satp = 64'h0;
    wire [63:0] pmpcfg0 = 64'h0, pmpcfg2 = 64'h0;
    wire [37:0] pmpaddr [0:7];

    // -------------------------------------------------------
    // Pipeline control wires
    // -------------------------------------------------------
    wire        stall, flush_fe;
    wire [63:0] branch_target;
    wire        branch_taken;
    wire        exception;
    wire [63:0] exception_target;

    assign flush_fe = branch_taken || exception;
    
    wire flush_de_raw = branch_taken || exception || stall;

    // Explicit manual buffering to split the 300+ fanout of the flush signal
    // This instantiates actual physical cells from the library, ensuring ABC 
    // cannot merge them during logic synthesis.
    wire flush_de_1, flush_de_2, flush_de_3, flush_de_4;
    BUFX4 u_buf_flush1 ( .A(flush_de_raw), .Y(flush_de_1) );
    BUFX4 u_buf_flush2 ( .A(flush_de_raw), .Y(flush_de_2) );
    BUFX4 u_buf_flush3 ( .A(flush_de_raw), .Y(flush_de_3) );
    BUFX4 u_buf_flush4 ( .A(flush_de_raw), .Y(flush_de_4) );

    // -------------------------------------------------------
    // BPU
    // -------------------------------------------------------
    wire        pred_taken;
    wire [63:0] pred_target;
    wire        pred_valid;

    // -------------------------------------------------------
    // MMU & I-Cache (Frontend)
    // -------------------------------------------------------
    wire [63:0] fetch_va;
    wire        fetch_req;
    wire [39:0] fetch_pa;
    wire        fetch_trans_valid, fetch_trans_busy;
    wire        fetch_page_fault;

    rv_mmu u_immu (
        .clk           (clk),
        .rst_n         (rst_n),
        .satp          (satp),
        .priv_mode     (priv_mode),
        .va_req        (fetch_va),
        .req_valid     (fetch_req),
        .req_r         (1'b0),
        .req_w         (1'b0),
        .req_x         (1'b1),
        .pa_out        (fetch_pa),
        .trans_valid   (fetch_trans_valid),
        .trans_busy    (fetch_trans_busy),
        .page_fault    (fetch_page_fault),
        // PTW AXI not fully wired here; assume unified or arbiter outside
        // For compilation integrity, tie off PTW AXI ports
        .ptw_arready   (1'b0),
        .ptw_rvalid    (1'b0),
        .ptw_rdata     (64'h0),
        .ptw_rresp     (2'h0),
        .sfence_vma    (1'b0),
        .sfence_asid_en(1'b0),
        .sfence_va_en  (1'b0),
        .sfence_va_val (64'h0),
        .sfence_asid_val(64'h0)
    );

    wire [31:0] icache_rdata;
    wire        icache_valid;
    wire        icache_stall;

    rv_icache u_icache (
        .clk           (clk),
        .rst_n         (rst_n),
        .cpu_addr      (fetch_pa),
        .cpu_req       (fetch_req && fetch_trans_valid && !fetch_page_fault),
        .cpu_rdata     (icache_rdata),
        .cpu_valid     (icache_valid),
        .cpu_stall     (icache_stall),
        .invalidate    (1'b0),
        .m_arvalid     (imem_arvalid),
        .m_arready     (imem_arready),
        .m_araddr      (imem_araddr),
        .m_arlen       (imem_arlen),
        .m_arsize      (imem_arsize),
        .m_arburst     (imem_arburst),
        .m_rvalid      (imem_rvalid),
        .m_rready      (imem_rready),
        .m_rdata       (imem_rdata),
        .m_rlast       (imem_rlast),
        .m_rresp       (imem_rresp)
    );

    // -------------------------------------------------------
    // Fetch Stage
    // -------------------------------------------------------
    // Uses icache_rdata. A full fetch unit would issue fetch_va,
    // query BPU, and handle icache responses.
    wire [63:0] fe_pc;
    wire [31:0] fe_instr = icache_rdata;
    wire        fe_valid = icache_valid;
    
    // (Simplified fetch generation for top-level integration completeness)
    reg [63:0] pc_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc_reg <= RESET_PC;
        else if (exception) pc_reg <= exception_target;
        else if (branch_taken) pc_reg <= branch_target;
        else if (pred_taken && pred_valid) pc_reg <= pred_target;
        else if (fe_valid && !stall) pc_reg <= pc_reg + 4;
    end
    assign fetch_va = pc_reg;
    assign fetch_req = 1'b1;
    assign fe_pc = pc_reg;

    // -------------------------------------------------------
    // Decode Stage
    // -------------------------------------------------------
    wire [63:0] de_pc, de_rs1, de_rs2, de_imm;
    wire [4:0]  de_rd, de_rs1a, de_rs2a, de_fop;
    wire [2:0]  de_f3, de_frm, de_fmt;
    wire [6:0]  de_f7, de_op;
    wire [4:0]  de_aluop;
    wire [4:0]  de_amo_f5;
    wire        de_memr, de_memw, de_regw, de_branch, de_jal, de_jalr, de_is_amo, de_valid;
    
    rv_decode u_decode (
        .clk       (clk),         .rst_n    (rst_n),
        .stall     (stall),       
        .flush     (flush_de_1),
        .pc_in     (fe_pc),       .instr_in (fe_instr),    .valid_in (fe_valid),
        .wb_rd     (5'h0),        .wb_data  (64'h0),       .wb_we    (1'b0), // Wire to WB
        .pc_out    (de_pc),       .rs1_data (de_rs1),      .rs2_data (de_rs2),
        .imm       (de_imm),      .rd       (de_rd),
        .rs1_addr  (de_rs1a),     .rs2_addr (de_rs2a),
        .funct3    (de_f3),       .funct7   (de_f7),       .opcode   (de_op),
        .alu_op    (de_aluop),    .mem_read (de_memr),     .mem_write(de_memw),
        .reg_write (de_regw),     .branch   (de_branch),   .jal      (de_jal),
        .jalr      (de_jalr),     .valid_out(de_valid)
        // Note: FPU and AMO decode signals would be added to rv_decode,
        // wired here appropriately.
    );
    assign de_amo_f5 = 5'h0;
    assign de_is_amo = 1'b0;
    assign de_fop    = 5'h0;
    assign de_frm    = 3'h0;
    assign de_fmt    = 3'h0;

    // -------------------------------------------------------
    // FPU
    // -------------------------------------------------------
    wire [63:0] fpu_result;
    wire        fpu_result_valid;
    wire [4:0]  fpu_fflags;
    wire        fpu_done;

    rv_fpu u_fpu (
        .clk             (clk),
        .rst_n           (rst_n),
        .fop             (de_fop),
        .fmt             (de_fmt[1:0]),
        .rm              (de_frm),
        .valid_in        (de_valid && (de_op == `OP_FP)),
        .fp_src1         (64'h0), // Connect to FP regfile
        .fp_src2         (64'h0),
        .fp_src3         (64'h0),
        .int_src         (de_rs1),
        .frm_csr         (3'h0),
        .fp_result       (fpu_result),
        .result_valid    (fpu_result_valid),
        .fflags          (fpu_fflags),
        .fpu_done        (fpu_done),
        .int_result      (),
        .int_result_valid()
    );

    // -------------------------------------------------------
    // Execute Stage
    // -------------------------------------------------------
    wire [63:0] ex_alures, ex_rs2, ex_lr_addr;
    wire [4:0]  ex_rd, ex_amo_f5;
    wire [2:0]  ex_f3;
    wire [6:0]  ex_op;
    wire        ex_memr, ex_memw, ex_regw, ex_is_amo, ex_valid, ex_lr_valid;
    wire        mul_div_stall;

    rv_execute u_execute (
        .clk          (clk),        .rst_n        (rst_n),
        .stall        (stall),      .flush        (flush_de_4),
        .pc_in        (de_pc),      .rs1_data     (de_rs1),    .rs2_data    (de_rs2),
        .imm          (de_imm),     .rd_in        (de_rd),
        .rs1_addr     (de_rs1a),    .rs2_addr     (de_rs2a),
        .funct3       (de_f3),      .funct7       (de_f7),     .opcode      (de_op),
        .alu_op       (de_aluop),   .mem_read     (de_memr),   .mem_write   (de_memw),
        .reg_write    (de_regw),    .branch       (de_branch), .jal         (de_jal),
        .jalr         (de_jalr),    .is_amo       (de_is_amo), .amo_funct5  (de_amo_f5),
        .valid_in     (de_valid),
        .fwd_mem_data (64'h0),      .fwd_mem_valid(1'b0),      .fwd_mem_rd  (5'h0),
        .fwd_wb_data  (64'h0),      .fwd_wb_valid (1'b0),      .fwd_wb_rd   (5'h0),
        .fpu_result   (fpu_result), .fpu_valid    (fpu_result_valid), .fpu_done(fpu_done),
        .alu_result   (ex_alures),  .rs2_out      (ex_rs2),
        .rd_out       (ex_rd),      .funct3_out   (ex_f3),     .opcode_out  (ex_op),
        .mem_read_out (ex_memr),    .mem_write_out(ex_memw),   .reg_write_out(ex_regw),
        .is_amo_out   (ex_is_amo),  .amo_funct5_out(ex_amo_f5),
        .valid_out    (ex_valid),
        .mul_div_stall(mul_div_stall),
        .branch_taken (branch_taken), .branch_target(branch_target),
        .lr_addr      (ex_lr_addr), .lr_valid     (ex_lr_valid)
    );

    // -------------------------------------------------------
    // MMU & D-Cache
    // -------------------------------------------------------
    wire [39:0] dmem_pa;
    wire        dmem_trans_valid, dmem_trans_busy, dmem_page_fault;

    rv_mmu u_dmmu (
        .clk           (clk),
        .rst_n         (rst_n),
        .satp          (satp),
        .priv_mode     (priv_mode),
        .va_req        (ex_alures), // Virtual address from ALU
        .req_valid     (ex_valid && (ex_memr || ex_memw)),
        .req_r         (ex_memr),
        .req_w         (ex_memw),
        .req_x         (1'b0),
        .pa_out        (dmem_pa),
        .trans_valid   (dmem_trans_valid),
        .trans_busy    (dmem_trans_busy),
        .page_fault    (dmem_page_fault),
        .ptw_arready   (1'b0),
        .ptw_rvalid    (1'b0),
        .ptw_rdata     (64'h0),
        .ptw_rresp     (2'h0),
        .sfence_vma    (1'b0),
        .sfence_asid_en(1'b0),
        .sfence_va_en  (1'b0),
        .sfence_va_val (64'h0),
        .sfence_asid_val(64'h0)
    );

    wire        pmp_fault;
    rv_pmp u_pmp (
        .clk        (clk),
        .rst_n      (rst_n),
        .paddr      (dmem_pa[37:0]),
        .check_r    (ex_memr),
        .check_w    (ex_memw),
        .check_x    (1'b0),
        .priv_mode  (priv_mode),
        .check_en   (ex_valid && (ex_memr || ex_memw) && dmem_trans_valid),
        .pmpcfg0    (64'h0), // from CSRs
        .pmpcfg2    (64'h0),
        .pmpaddr_packed    (304'h0),
        .pmp_fault  (pmp_fault)
    );

    wire [63:0] dcache_rdata;
    wire        dcache_valid;
    wire        dcache_stall;
    wire        sc_success;

    rv_dcache u_dcache (
        .clk             (clk),
        .rst_n           (rst_n),
        .cpu_addr        (dmem_pa),
        .cpu_wdata       (ex_rs2),
        .cpu_wstrb       (8'hFF), // generated from funct3 in full mem stage
        .cpu_req         (ex_valid && (ex_memr || ex_memw) && dmem_trans_valid && !dmem_page_fault && !pmp_fault),
        .cpu_wr          (ex_memw),
        .cpu_size        (ex_f3),
        .cpu_rdata       (dcache_rdata),
        .cpu_valid       (dcache_valid),
        .cpu_stall       (dcache_stall),
        .is_lr           (ex_is_amo && ex_amo_f5 == `AMO_LR),
        .is_sc           (ex_is_amo && ex_amo_f5 == `AMO_SC),
        .lr_addr_in      (ex_lr_addr[39:0]),
        .lr_valid_in     (ex_lr_valid),
        .sc_success      (sc_success),
        .flush_all       (1'b0),
        .flush_addr_en   (1'b0),
        .flush_addr      (40'h0),
        .m_arvalid       (dmem_arvalid),
        .m_arready       (dmem_arready),
        .m_araddr        (dmem_araddr),
        .m_arlen         (dmem_arlen),
        .m_arsize        (dmem_arsize),
        .m_arburst       (dmem_arburst),
        .m_arlock        (dmem_arlock),
        .m_rvalid        (dmem_rvalid),
        .m_rready        (dmem_rready),
        .m_rdata         (dmem_rdata),
        .m_rlast         (dmem_rlast),
        .m_rresp         (dmem_rresp),
        .m_awvalid       (dmem_awvalid),
        .m_awready       (dmem_awready),
        .m_awaddr        (dmem_awaddr),
        .m_awlen         (dmem_awlen),
        .m_awsize        (dmem_awsize),
        .m_awburst       (dmem_awburst),
        .m_wvalid        (dmem_wvalid),
        .m_wready        (dmem_wready),
        .m_wdata         (dmem_wdata),
        .m_wstrb         (dmem_wstrb),
        .m_wlast         (dmem_wlast),
        .m_bvalid        (dmem_bvalid),
        .m_bready        (dmem_bready),
        .m_bresp         (dmem_bresp),
        .snoop_valid     (snoop_valid),
        .snoop_addr      (snoop_addr),
        .snoop_type      (snoop_type),
        .snoop_ack       (snoop_ack),
        .snoop_data_valid(snoop_data_valid),
        .snoop_data      (snoop_data),
        .ecc_1bit        (),
        .ecc_2bit        ()
    );

    // Hazard and stall logic
    assign stall = mul_div_stall || icache_stall || fetch_trans_busy || 
                   dcache_stall || dmem_trans_busy || halt_req;
    
    // Exception generation (Page Faults, PMP Faults)
    assign exception = fetch_page_fault || dmem_page_fault || pmp_fault;
    assign exception_target = 64'h0; // Read from mtvec

    assign hart_halted = halt_req;
    assign hart_running = !halt_req;

endmodule
