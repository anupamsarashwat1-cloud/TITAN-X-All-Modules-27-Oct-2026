// SPDX-License-Identifier: Apache-2.0
// SMVDU-TitanX SoC — rv_core_top Exception & Privileged Architecture Testbench
//
// Directed architectural verification for the RISC-V Privileged Architecture:
//   1. Cause 2:  Illegal Instruction trap (mcause=2, mtval=faulting_word, mstatus.MPP=2'b11, MRET)
//   2. Cause 11: ECALL from M-mode (mcause=11, mtval=0, vector to mtvec, MRET)
//   3. Cause 3:  EBREAK (mcause=3, mtval=faulting_pc, vector to mtvec, MRET)
//   4. Cause 4:  Load Address Misaligned (mcause=4, mtval=addr, no AXI bus transaction)
//   5. Cause 6:  Store Address Misaligned (mcause=6, mtval=addr, no AXI bus transaction)
//   6. Cause 0:  Instruction Address Misaligned (mcause=0, mtval=target_addr, MRET)

`timescale 1ns/1ps

module tb_rv_core_exception();
    localparam BASE  = 64'h0000_0000_0002_0000;   // params.vh RESET_PC
    localparam DBASE = 64'h0000_0000_8000_0000;   // DDR window base

    reg  clk;
    reg  rst_n;
    reg  irq_m_ext, irq_m_timer, irq_m_soft;
    wire imem_arvalid;
    wire imem_arready;
    wire [39:0] imem_araddr;
    wire [7:0]  imem_arlen;
    wire [2:0]  imem_arsize;
    wire [1:0]  imem_arburst;
    wire imem_rvalid;
    wire imem_rready;
    wire [63:0] imem_rdata;
    wire imem_rlast;
    wire [1:0]  imem_rresp;
    wire dmem_awvalid;
    wire dmem_awready;
    wire [39:0] dmem_awaddr;
    wire [7:0]  dmem_awlen;
    wire [2:0]  dmem_awsize;
    wire [1:0]  dmem_awburst;
    wire dmem_wvalid;
    wire dmem_wready;
    wire [63:0] dmem_wdata;
    wire [7:0]  dmem_wstrb;
    wire dmem_wlast;
    wire dmem_bvalid;
    wire dmem_bready;
    wire [1:0]  dmem_bresp;
    wire dmem_arvalid;
    wire dmem_arready;
    wire [39:0] dmem_araddr;
    wire [7:0]  dmem_arlen;
    wire [2:0]  dmem_arsize;
    wire [1:0]  dmem_arburst;
    wire dmem_arlock;
    wire dmem_rvalid;
    wire dmem_rready;
    wire [63:0] dmem_rdata;
    wire dmem_rlast;
    wire [1:0]  dmem_rresp;
    reg  snoop_valid;
    reg  [39:0] snoop_addr;
    reg  [1:0]  snoop_type;
    wire snoop_ack;
    wire snoop_data_valid;
    wire [511:0] snoop_data;
    reg  halt_req;
    reg  resume_req;
    wire hart_halted;
    wire hart_running;

    integer error_count;
    integer misaligned_bus_accesses;

    rv_core_top uut (
        .clk(clk), .rst_n(rst_n),
        .irq_m_ext(irq_m_ext), .irq_m_timer(irq_m_timer), .irq_m_soft(irq_m_soft),
        .imem_arvalid(imem_arvalid), .imem_arready(imem_arready),
        .imem_araddr(imem_araddr), .imem_arlen(imem_arlen),
        .imem_arsize(imem_arsize), .imem_arburst(imem_arburst),
        .imem_rvalid(imem_rvalid), .imem_rready(imem_rready),
        .imem_rdata(imem_rdata), .imem_rlast(imem_rlast), .imem_rresp(imem_rresp),
        .dmem_awvalid(dmem_awvalid), .dmem_awready(dmem_awready),
        .dmem_awaddr(dmem_awaddr), .dmem_awlen(dmem_awlen),
        .dmem_awsize(dmem_awsize), .dmem_awburst(dmem_awburst),
        .dmem_wvalid(dmem_wvalid), .dmem_wready(dmem_wready),
        .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb), .dmem_wlast(dmem_wlast),
        .dmem_bvalid(dmem_bvalid), .dmem_bready(dmem_bready), .dmem_bresp(dmem_bresp),
        .dmem_arvalid(dmem_arvalid), .dmem_arready(dmem_arready),
        .dmem_araddr(dmem_araddr), .dmem_arlen(dmem_arlen),
        .dmem_arsize(dmem_arsize), .dmem_arburst(dmem_arburst),
        .dmem_arlock(dmem_arlock),
        .dmem_rvalid(dmem_rvalid), .dmem_rready(dmem_rready),
        .dmem_rdata(dmem_rdata), .dmem_rlast(dmem_rlast), .dmem_rresp(dmem_rresp),
        .snoop_valid(snoop_valid), .snoop_addr(snoop_addr), .snoop_type(snoop_type),
        .snoop_ack(snoop_ack), .snoop_data_valid(snoop_data_valid),
        .snoop_data(snoop_data),
        .halt_req(halt_req), .resume_req(resume_req),
        .hart_halted(hart_halted), .hart_running(hart_running)
    );

    initial clk = 0;
    always #3.6 clk = ~clk;

    // ------------------------------------------------------------
    // Instruction slave: single-beat AXI-Lite
    // ------------------------------------------------------------
    localparam IS_AR = 1'b0, IS_R = 1'b1;
    reg        is_state;
    reg [63:0] is_addr;
    reg [31:0] imem [0:4095];

    assign imem_arready = (is_state == IS_AR) && rst_n;
    wire [63:0] is_word_ix = (is_addr - BASE) >> 2;
    wire        is_oob = (is_addr < BASE) || (is_addr[1:0] != 2'b00) ||
                         (is_word_ix >= 4096);
    wire [31:0] is_word = is_oob ? 32'h0 : imem[is_word_ix[11:0]];

    assign imem_rdata = {32'h0, is_word};
    assign imem_rvalid = (is_state == IS_R) && rst_n;
    assign imem_rlast  = 1'b1;
    assign imem_rresp  = is_oob ? 2'b10 : 2'b00;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_state <= IS_AR;
            is_addr  <= 64'h0;
        end else begin
            case (is_state)
                IS_AR: if (imem_arvalid && imem_arready) begin
                    is_addr  <= {24'h0, imem_araddr};
                    is_state <= IS_R;
                end
                IS_R: if (imem_rvalid && imem_rready) begin
                    is_state <= IS_AR;
                end
            endcase
        end
    end

    // ------------------------------------------------------------
    // Data slave: byte-strobed writes + single-beat reads, DDR window
    // ------------------------------------------------------------
    reg [63:0] dmem [0:2047];
    reg        ds_aw_pend, ds_w_pend, ds_bvalid;
    reg [39:0] ds_aw_addr;
    reg [63:0] ds_w_data;
    reg [7:0]  ds_w_strb;

    assign dmem_awready = !ds_aw_pend;
    assign dmem_wready  = !ds_w_pend;
    assign dmem_bvalid  = ds_bvalid && rst_n;
    assign dmem_bresp   = 2'b00;

    wire [63:0] ds_word_ix = ({24'h0, ds_aw_addr} - DBASE) >> 3;
    wire        ds_oob = (ds_aw_addr < DBASE) ||
                         ((({24'h0, ds_aw_addr} - DBASE) >> 3) >= 2048);

    // Read channel
    localparam DS_AR = 1'b0, DS_R = 1'b1;
    reg        ds_rstate;
    reg [39:0] ds_ar_addr;
    assign dmem_arready = (ds_rstate == DS_AR) && rst_n;
    wire [63:0] ds_r_ix = ({24'h0, ds_ar_addr} - DBASE) >> 3;
    wire        ds_r_oob = (ds_ar_addr < DBASE) ||
                           ((({24'h0, ds_ar_addr} - DBASE) >> 3) >= 2048);
    wire [63:0] ds_r_word = ds_r_oob ? 64'h0 : dmem[ds_r_ix[10:0]];
    assign dmem_rvalid = (ds_rstate == DS_R) && rst_n;
    assign dmem_rdata  = ds_r_word;
    assign dmem_rlast  = 1'b1;
    assign dmem_rresp  = ds_r_oob ? 2'b10 : 2'b00;

    integer b;
    reg [63:0] wtmp;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ds_aw_pend <= 0; ds_w_pend <= 0; ds_bvalid <= 0;
            ds_aw_addr <= 40'h0; ds_w_data <= 64'h0; ds_w_strb <= 8'h0;
            ds_rstate <= DS_AR; ds_ar_addr <= 40'h0;
        end else begin
            if (!ds_aw_pend && dmem_awvalid && dmem_awready) begin
                ds_aw_addr <= dmem_awaddr;
                ds_aw_pend <= 1'b1;
            end
            if (!ds_w_pend && dmem_wvalid && dmem_wready) begin
                ds_w_data <= dmem_wdata;
                ds_w_strb <= dmem_wstrb;
                ds_w_pend <= 1'b1;
            end
            if (ds_aw_pend && ds_w_pend && !ds_bvalid) begin
                if (!ds_oob) begin
                    wtmp = dmem[ds_word_ix[10:0]];
                    for (b = 0; b < 8; b = b + 1)
                        if (ds_w_strb[b])
                            wtmp[b*8 +: 8] = ds_w_data[b*8 +: 8];
                    dmem[ds_word_ix[10:0]] <= wtmp;
                end
                ds_aw_pend <= 1'b0;
                ds_w_pend  <= 1'b0;
                ds_bvalid  <= 1'b1;
            end
            if (ds_bvalid && dmem_bready)
                ds_bvalid <= 1'b0;
            // Read channel
            case (ds_rstate)
                DS_AR: if (dmem_arvalid && dmem_arready) begin
                    ds_ar_addr <= dmem_araddr;
                    ds_rstate  <= DS_R;
                end
                DS_R: if (dmem_rvalid && dmem_rready) begin
                    ds_rstate <= DS_AR;
                end
            endcase
        end
    end

    // Bus monitor: verify misaligned addresses never appear on AXI bus
    always @(posedge clk) begin
        if (rst_n && dmem_arvalid && dmem_araddr == 40'd1) begin
            $display("FAIL [%0t] Misaligned load leaked to AXI bus (addr=0x1)", $time);
            misaligned_bus_accesses = misaligned_bus_accesses + 1;
        end
        if (rst_n && dmem_awvalid && dmem_awaddr == 40'd2) begin
            $display("FAIL [%0t] Misaligned store leaked to AXI bus (addr=0x2)", $time);
            misaligned_bus_accesses = misaligned_bus_accesses + 1;
        end
    end

    task check;
        input [63:0] got;
        input [63:0] exp;
        input [255:0] msg;
        begin
            if (got !== exp) begin
                $display("FAIL [%0t] %s: got=0x%016X exp=0x%016X", $time, msg, got, exp);
                error_count = error_count + 1;
            end else begin
                $display("PASS [%0t] %s (0x%016X)", $time, msg, got);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_rv_core_exception.vcd");
        $dumpvars(0, tb_rv_core_exception);

        error_count = 0;
        misaligned_bus_accesses = 0;
        irq_m_ext = 0; irq_m_timer = 0; irq_m_soft = 0;
        snoop_valid = 0; snoop_addr = 0; snoop_type = 0;
        halt_req = 0; resume_req = 0;

        for (b = 0; b < 2048; b = b + 1) dmem[b] = 64'h0;
        for (b = 0; b < 4096; b = b + 1) imem[b] = 32'h0000_0013; // NOP fill

        // ------------------------------------------------------------
        // Program Setup
        // Base = 0x0002_0000
        // ------------------------------------------------------------
        // Words 0..5: Set up mtvec = 0x0002_0100 and x20 = 0x8000_0000 (DDR base)
        imem[0] = 32'h0010_0a13; // addi x20, x0, 1
        imem[1] = 32'h01fa_1a13; // slli x20, x20, 31 (x20 = 0x8000_0000)
        imem[2] = 32'h0200_0993; // addi x19, x0, 32
        imem[3] = 32'h00c9_9993; // slli x19, x19, 12 (x19 = 0x20000)
        imem[4] = 32'h1009_8993; // addi x19, x19, 256 (x19 = 0x20100)
        imem[5] = 32'h3059_9073; // csrrw x0, mtvec, x19

        // TEST 1: Illegal instruction at 0x20018
        imem[6] = 32'h0000_000b; // invalid opcode 0x0B -> Cause 2, mtval = 0x0000_000B

        // TEST 2: ECALL at 0x2001C
        imem[7] = 32'h0000_0073; // ECALL -> Cause 11, mtval = 0

        // TEST 3: EBREAK at 0x20020
        imem[8] = 32'h0010_0073; // EBREAK -> Cause 3, mtval = PC (0x20020)

        // TEST 4: Misaligned Load at 0x20024: lw x5, 1(x0)
        imem[9] = 32'h0010_2283; // lw x5, 1(x0) -> Cause 4, mtval = 1

        // TEST 5: Misaligned Store at 0x20028: sw x5, 2(x0)
        imem[10] = 32'h0050_2123; // sw x5, 2(x0) -> Cause 6, mtval = 2

        // TEST 6: Misaligned Jump at 0x2002C: jalr x0, 2(x19) -> target = 0x20102
        imem[11] = 32'h0029_8067; // jalr x0, 2(x19) -> Cause 0, mtval = 0x20102

        // Park loop at 0x20030:
        imem[12] = 32'h0000_006f; // jal x0, 0 (infinite loop)

        // ------------------------------------------------------------
        // Exception Handler at 0x0002_0100 (word 64)
        // ------------------------------------------------------------
        imem[64] = 32'h3420_2573; // csrr x10, mcause
        imem[65] = 32'h3410_25f3; // csrr x11, mepc
        imem[66] = 32'h3430_2673; // csrr x12, mtval
        imem[67] = 32'h3000_26f3; // csrr x13, mstatus
        imem[68] = 32'h00a_a3023; // sd x10, 0(x20)   (mcause)
        imem[69] = 32'h00b_a3423; // sd x11, 8(x20)   (mepc)
        imem[70] = 32'h00c_a3823; // sd x12, 16(x20)  (mtval)
        imem[71] = 32'h00d_a3c23; // sd x13, 24(x20)  (mstatus)
        imem[72] = 32'h020a_0a13; // addi x20, x20, 32 (advance slot pointer)
        imem[73] = 32'h0045_8593; // addi x11, x11, 4  (advance mepc by 4 to resume past fault)
        imem[74] = 32'h3415_9073; // csrrw x0, mepc, x11 (save updated mepc)
        imem[75] = 32'h3020_0073; // mret (return to updated mepc in M-mode)

        rst_n = 0;
        #40;
        rst_n = 1;

        // Run program to completion
        begin : run
            integer cyc;
            for (cyc = 0; cyc < 5000; cyc = cyc + 1) begin
                @(posedge clk);
            end
        end

        halt_req = 1;
        repeat (10) @(posedge clk);

        $display("\n========================================================");
        $display("   TITAN X PRIVILEGED ARCHITECTURE & EXCEPTION AUDIT    ");
        $display("========================================================\n");

        // TEST 1 Verification: Illegal Instruction Trap (Cause 2)
        $display("--- TEST 1: Illegal Instruction Trap (Cause 2) ---");
        check(dmem[0], 64'd2, "Test 1 mcause == 2 (Illegal instruction)");
        check(dmem[1], 64'h0002_0018, "Test 1 mepc == 0x20018 (faulting instruction PC)");
        check(dmem[2], 64'h0000_000B, "Test 1 mtval == 0x0000_000B (faulting instruction word)");
        check(dmem[3][12:11], 2'b11, "Test 1 mstatus.MPP == 2'b11 (Machine mode preserved)");

        // TEST 2 Verification: ECALL Trap (Cause 11)
        $display("\n--- TEST 2: Environment Call Trap (Cause 11) ---");
        check(dmem[4], 64'd11, "Test 2 mcause == 11 (ECALL from M-mode)");
        check(dmem[5], 64'h0002_001C, "Test 2 mepc == 0x2001C (ECALL instruction PC)");
        check(dmem[6], 64'h0, "Test 2 mtval == 0 (zero on ECALL)");
        check(dmem[7][12:11], 2'b11, "Test 2 mstatus.MPP == 2'b11");

        // TEST 3 Verification: EBREAK Trap (Cause 3)
        $display("\n--- TEST 3: Breakpoint Trap (Cause 3) ---");
        check(dmem[8], 64'd3, "Test 3 mcause == 3 (EBREAK)");
        check(dmem[9], 64'h0002_0020, "Test 3 mepc == 0x20020 (EBREAK instruction PC)");
        check(dmem[10], 64'h0002_0020, "Test 3 mtval == 0x20020 (PC written to mtval on breakpoint)");
        check(dmem[11][12:11], 2'b11, "Test 3 mstatus.MPP == 2'b11");

        // TEST 4 Verification: Misaligned Load Trap (Cause 4)
        $display("\n--- TEST 4: Misaligned Load Trap (Cause 4) ---");
        check(dmem[12], 64'd4, "Test 4 mcause == 4 (Load address misaligned)");
        check(dmem[13], 64'h0002_0024, "Test 4 mepc == 0x20024 (LW instruction PC)");
        check(dmem[14], 64'h1, "Test 4 mtval == 0x1 (faulting load address)");
        check(dmem[15][12:11], 2'b11, "Test 4 mstatus.MPP == 2'b11");

        // TEST 5 Verification: Misaligned Store Trap (Cause 6)
        $display("\n--- TEST 5: Misaligned Store Trap (Cause 6) ---");
        check(dmem[16], 64'd6, "Test 5 mcause == 6 (Store address misaligned)");
        check(dmem[17], 64'h0002_0028, "Test 5 mepc == 0x20028 (SW instruction PC)");
        check(dmem[18], 64'h2, "Test 5 mtval == 0x2 (faulting store address)");
        check(dmem[19][12:11], 2'b11, "Test 5 mstatus.MPP == 2'b11");

        // TEST 6 Verification: Misaligned Instruction Address Trap (Cause 0)
        $display("\n--- TEST 6: Misaligned Instruction Address Trap (Cause 0) ---");
        check(dmem[20], 64'd0, "Test 6 mcause == 0 (Instruction address misaligned)");
        check(dmem[21], 64'h0002_002C, "Test 6 mepc == 0x2002C (JALR instruction PC)");
        check(dmem[22], 64'h0002_0102, "Test 6 mtval == 0x20102 (misaligned target address)");
        check(dmem[23][12:11], 2'b11, "Test 6 mstatus.MPP == 2'b11");

        // Bus transaction suppression check
        $display("\n--- Bus Integrity Audit ---");
        check(misaligned_bus_accesses, 64'd0, "No misaligned loads or stores reached the AXI bus");

        $display("\n========================================================");
        if (error_count == 0 && misaligned_bus_accesses == 0) begin
            $display("RV_CORE_EXCEPTION VERDICT: ✅ PASS — All privileged exception contracts verified");
            $display("REGRESS_RESULT: PASS");
        end else begin
            $display("RV_CORE_EXCEPTION VERDICT: ❌ FAIL — %0d errors, %0d bus leaks",
                     error_count, misaligned_bus_accesses);
            $display("REGRESS_RESULT: FAIL");
        end
        $display("========================================================\n");
        $finish;
    end

    initial begin
        #600_000;
        $display("WATCHDOG TIMEOUT");
        $display("RV_CORE_EXCEPTION VERDICT: ❌ FAIL — watchdog");
        $display("REGRESS_RESULT: FAIL");
        $finish;
    end

endmodule
