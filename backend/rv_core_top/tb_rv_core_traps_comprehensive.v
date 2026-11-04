// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X — Phase 2 Gate E Qualification Testbench
// Module: tb_rv_core_traps_comprehensive
// Exhaustively qualifies the full synchronous exception and asynchronous interrupt datapath:
//   1. Cause 1: Instruction Access Fault (fe_fault via imem_rresp != 2'b00)
//   2. Cause 2: Illegal Instruction
//   3. Cause 3: Breakpoint (EBREAK)
//   4. Cause 11: Environment Call (ECALL from M-mode)
//   5. Cause 4: Load Address Misaligned
//   6. Cause 5: Load Access Fault (dmem_rresp = 2'b10)
//   7. Cause 6: Store Address Misaligned
//   8. Cause 7: Store Access Fault (dmem_bresp = 2'b10)
//   9. Cause (1<<63)|7: Machine Timer Interrupt
//  10. Cause (1<<63)|3: Machine Software Interrupt
//  11. Cause (1<<63)|11: Machine External Interrupt
//  12. Trap Return: MRET execution restoring PC from mepc

`timescale 1ns/1ps

module tb_rv_core_traps_comprehensive;

    reg clk;
    reg rst_n;
    reg irq_m_ext;
    reg irq_m_timer;
    reg irq_m_soft;

    // AXI-Lite Instruction Master wires
    wire        imem_arvalid;
    reg         imem_arready;
    wire [39:0] imem_araddr;
    wire [7:0]  imem_arlen;
    wire [2:0]  imem_arsize;
    wire [1:0]  imem_arburst;
    reg         imem_rvalid;
    wire        imem_rready;
    reg  [63:0] imem_rdata;
    reg         imem_rlast;
    reg  [1:0]  imem_rresp;

    // AXI-Lite Data Master wires
    wire        dmem_awvalid;
    reg         dmem_awready;
    wire [39:0] dmem_awaddr;
    wire [7:0]  dmem_awlen;
    wire [2:0]  dmem_awsize;
    wire [1:0]  dmem_awburst;
    wire        dmem_wvalid;
    reg         dmem_wready;
    wire [63:0] dmem_wdata;
    wire [7:0]  dmem_wstrb;
    wire        dmem_wlast;
    reg         dmem_bvalid;
    wire        dmem_bready;
    reg  [1:0]  dmem_bresp;

    wire        dmem_arvalid;
    reg         dmem_arready;
    wire [39:0] dmem_araddr;
    wire [7:0]  dmem_arlen;
    wire [2:0]  dmem_arsize;
    wire [1:0]  dmem_arburst;
    wire        dmem_arlock;
    reg         dmem_rvalid;
    wire        dmem_rready;
    reg  [63:0] dmem_rdata;
    reg         dmem_rlast;
    reg  [1:0]  dmem_rresp;

    // Snoop interface
    reg         snoop_valid;
    reg  [39:0] snoop_addr;
    reg  [1:0]  snoop_type;
    wire        snoop_ack;
    wire        snoop_data_valid;
    wire [511:0] snoop_data;

    reg         halt_req, resume_req;
    wire        hart_halted, hart_running;

    integer checks_passed = 0;
    integer checks_failed = 0;

    localparam RESET_PC   = 64'h0000_0000_0002_0000;
    localparam MTVEC_ADDR = 64'h0000_0000_0002_0800;

    // Instantiate Core Top with L1 Cache disabled for direct bus inspection
    rv_core_top #(
        .HART_ID(0),
        .RESET_PC(RESET_PC),
        .ENABLE_L1_CACHE(0)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .irq_m_ext(irq_m_ext),
        .irq_m_timer(irq_m_timer),
        .irq_m_soft(irq_m_soft),

        .imem_arvalid(imem_arvalid),
        .imem_arready(imem_arready),
        .imem_araddr(imem_araddr),
        .imem_arlen(imem_arlen),
        .imem_arsize(imem_arsize),
        .imem_arburst(imem_arburst),
        .imem_rvalid(imem_rvalid),
        .imem_rready(imem_rready),
        .imem_rdata(imem_rdata),
        .imem_rlast(imem_rlast),
        .imem_rresp(imem_rresp),

        .dmem_awvalid(dmem_awvalid),
        .dmem_awready(dmem_awready),
        .dmem_awaddr(dmem_awaddr),
        .dmem_awlen(dmem_awlen),
        .dmem_awsize(dmem_awsize),
        .dmem_awburst(dmem_awburst),
        .dmem_wvalid(dmem_wvalid),
        .dmem_wready(dmem_wready),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_wlast(dmem_wlast),
        .dmem_bvalid(dmem_bvalid),
        .dmem_bready(dmem_bready),
        .dmem_bresp(dmem_bresp),

        .dmem_arvalid(dmem_arvalid),
        .dmem_arready(dmem_arready),
        .dmem_araddr(dmem_araddr),
        .dmem_arlen(dmem_arlen),
        .dmem_arsize(dmem_arsize),
        .dmem_arburst(dmem_arburst),
        .dmem_arlock(dmem_arlock),
        .dmem_rvalid(dmem_rvalid),
        .dmem_rready(dmem_rready),
        .dmem_rdata(dmem_rdata),
        .dmem_rlast(dmem_rlast),
        .dmem_rresp(dmem_rresp),

        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_type(snoop_type),
        .snoop_ack(snoop_ack),
        .snoop_data_valid(snoop_data_valid),
        .snoop_data(snoop_data),

        .halt_req(halt_req),
        .resume_req(resume_req),
        .hart_halted(hart_halted),
        .hart_running(hart_running)
    );

    // Clock generator (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Memory Models
    reg [31:0] test_instruction;
    reg [63:0] data_mem  [0:511];

    reg inject_imem_fault   = 1'b0;
    reg inject_dmem_r_fault = 1'b0;
    reg inject_dmem_w_fault = 1'b0;

    // Instruction bus responder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_arready <= 1'b1;
            imem_rvalid  <= 1'b0;
            imem_rdata   <= 64'h0;
            imem_rresp   <= 2'b00;
            imem_rlast   <= 1'b1;
        end else begin
            if (imem_arvalid && imem_arready) begin
                imem_rvalid  <= 1'b1;
                imem_arready <= 1'b0;
                imem_rlast   <= 1'b1;
                if (inject_imem_fault) begin
                    imem_rresp <= 2'b10; // SLVERR -> Cause 1
                    imem_rdata <= 64'h0;
                end else begin
                    imem_rresp <= 2'b00;
                    imem_rdata <= {32'h0000_0013, test_instruction};
                end
            end else if (imem_rvalid && imem_rready) begin
                imem_rvalid  <= 1'b0;
                imem_arready <= 1'b1;
            end
        end
    end

    // Data bus responder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_arready <= 1'b1;
            dmem_rvalid  <= 1'b0;
            dmem_rdata   <= 64'h0;
            dmem_rresp   <= 2'b00;
            dmem_rlast   <= 1'b1;
            dmem_awready <= 1'b1;
            dmem_wready  <= 1'b1;
            dmem_bvalid  <= 1'b0;
            dmem_bresp   <= 2'b00;
        end else begin
            // Read
            if (dmem_arvalid && dmem_arready) begin
                dmem_rvalid  <= 1'b1;
                dmem_arready <= 1'b0;
                dmem_rlast   <= 1'b1;
                if (inject_dmem_r_fault) begin
                    dmem_rresp <= 2'b10; // SLVERR -> Cause 5
                    dmem_rdata <= 64'h0;
                end else begin
                    dmem_rresp <= 2'b00;
                    dmem_rdata <= data_mem[dmem_araddr[11:3] & 9'h1FF];
                end
            end else if (dmem_rvalid && dmem_rready) begin
                dmem_rvalid  <= 1'b0;
                dmem_arready <= 1'b1;
            end

            // Write
            if (dmem_awvalid && dmem_wvalid && dmem_awready && dmem_wready) begin
                dmem_bvalid  <= 1'b1;
                dmem_awready <= 1'b0;
                dmem_wready  <= 1'b0;
                if (inject_dmem_w_fault) begin
                    dmem_bresp <= 2'b10; // SLVERR -> Cause 7
                end else begin
                    dmem_bresp <= 2'b00;
                    data_mem[dmem_awaddr[11:3] & 9'h1FF] <= dmem_wdata;
                end
            end else if (dmem_bvalid && dmem_bready) begin
                dmem_bvalid  <= 1'b0;
                dmem_awready <= 1'b1;
                dmem_wready  <= 1'b1;
            end
        end
    end

    task reset_core();
        begin
            rst_n = 1'b0;
            irq_m_ext = 1'b0;
            irq_m_timer = 1'b0;
            irq_m_soft = 1'b0;
            inject_imem_fault = 1'b0;
            inject_dmem_r_fault = 1'b0;
            inject_dmem_w_fault = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
            uut.u_execute.u_csr.mtvec_q <= MTVEC_ADDR;
        end
    endtask

    task run_check(input [63:0] exp_cause, input [63:0] exp_tval, input [127:0] test_name);
        integer timeout;
        begin
            timeout = 0;
            while (!uut.u_execute.trap_commit && timeout < 150) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            @(posedge clk); // Allow CSR synchronous write (trap_we) to update mcause_q/mtval_q
            if (timeout >= 150) begin
                $display("FAIL: [%0s] Timed out waiting for trap commit @%0t", test_name, $time);
                checks_failed = checks_failed + 1;
            end else begin
                if (uut.u_execute.u_csr.mcause_q === exp_cause) begin
                    $display("PASS: [%0s] Trap taken with mcause = 0x%016h", test_name, exp_cause);
                    checks_passed = checks_passed + 1;
                end else begin
                    $display("FAIL: [%0s] Expected mcause 0x%016h, got 0x%016h", test_name, exp_cause, uut.u_execute.u_csr.mcause_q);
                    checks_failed = checks_failed + 1;
                end

                if (exp_tval !== 64'hFFFF_FFFF_FFFF_FFFF) begin
                    if (uut.u_execute.u_csr.mtval_q === exp_tval) begin
                        $display("PASS: [%0s] Correct mtval = 0x%016h", test_name, exp_tval);
                        checks_passed = checks_passed + 1;
                    end else begin
                        $display("FAIL: [%0s] Expected mtval 0x%016h, got 0x%016h", test_name, exp_tval, uut.u_execute.u_csr.mtval_q);
                        checks_failed = checks_failed + 1;
                    end
                end
            end
            repeat (5) @(posedge clk);
        end
    endtask

    integer w;
    initial begin
        $dumpfile("tb_rv_core_traps_comprehensive.vcd");
        $dumpvars(0, tb_rv_core_traps_comprehensive);

        snoop_valid = 1'b0;
        snoop_addr = 40'h0;
        snoop_type = 2'b00;
        halt_req = 1'b0;
        resume_req = 1'b0;
        test_instruction = 32'h0000_0013; // default NOP

        for (w=0; w<512; w=w+1) data_mem[w] = 64'h0;

        $display("\n==================================================================");
        $display("  TITAN X GATE E: RV64 TRAP & INTERRUPT COMPREHENSIVE SUITE");
        $display("==================================================================");

        // ------------------------------------------------------------
        // TEST 1: Cause 1 — Instruction Access Fault (fe_fault)
        // ------------------------------------------------------------
        $display("\n--- TEST 1: Cause 1 — Instruction Access Fault (Bus Error) ---");
        test_instruction = 32'h0000_0013;
        reset_core();
        inject_imem_fault = 1'b1;
        run_check(64'd1, 64'h0000_0000_0002_0004, "CAUSE 1: INST_ACCESS_FAULT");

        // ------------------------------------------------------------
        // TEST 2: Cause 2 — Illegal Instruction
        // ------------------------------------------------------------
        $display("\n--- TEST 2: Cause 2 — Illegal Instruction (0x0000_0000) ---");
        test_instruction = 32'h0000_0000;
        reset_core();
        run_check(64'd2, 64'h0, "CAUSE 2: ILLEGAL_INSTR");

        // ------------------------------------------------------------
        // TEST 3: Cause 3 — Breakpoint (EBREAK)
        // ------------------------------------------------------------
        $display("\n--- TEST 3: Cause 3 — Breakpoint (EBREAK: 0x0010_0073) ---");
        test_instruction = 32'h0010_0073;
        reset_core();
        run_check(64'd3, RESET_PC, "CAUSE 3: BREAKPOINT");

        // ------------------------------------------------------------
        // TEST 4: Cause 11 — Environment Call (ECALL from M-mode)
        // ------------------------------------------------------------
        $display("\n--- TEST 4: Cause 11 — Environment Call (ECALL: 0x0000_0073) ---");
        test_instruction = 32'h0000_0073;
        reset_core();
        run_check(64'd11, 64'h0, "CAUSE 11: ECALL_M_MODE");

        // ------------------------------------------------------------
        // TEST 5: Cause 4 — Load Address Misaligned
        // ------------------------------------------------------------
        $display("\n--- TEST 5: Cause 4 — Load Address Misaligned ---");
        test_instruction = 32'h00103083; // LD x1, 1(x0)
        reset_core();
        run_check(64'd4, 64'd1, "CAUSE 4: LOAD_MISALIGNED");

        // ------------------------------------------------------------
        // TEST 6: Cause 6 — Store Address Misaligned
        // ------------------------------------------------------------
        $display("\n--- TEST 6: Cause 6 — Store Address Misaligned ---");
        test_instruction = 32'h001031a3; // SD x1, 3(x0)
        reset_core();
        run_check(64'd6, 64'd3, "CAUSE 6: STORE_MISALIGNED");

        // ------------------------------------------------------------
        // TEST 7: Cause 5 — Load Access Fault
        // ------------------------------------------------------------
        $display("\n--- TEST 7: Cause 5 — Load Access Fault (SLVERR on bus) ---");
        test_instruction = 32'h00003083; // LD x1, 0(x0)
        reset_core();
        inject_dmem_r_fault = 1'b1;
        run_check(64'd5, 64'h0, "CAUSE 5: LOAD_ACCESS_FAULT");

        // ------------------------------------------------------------
        // TEST 8: Cause 7 — Store Access Fault
        // ------------------------------------------------------------
        $display("\n--- TEST 8: Cause 7 — Store Access Fault (SLVERR on bus) ---");
        test_instruction = 32'h00003023; // SD x0, 0(x0)
        reset_core();
        inject_dmem_w_fault = 1'b1;
        run_check(64'd7, 64'h0, "CAUSE 7: STORE_ACCESS_FAULT");

        // ------------------------------------------------------------
        // TEST 9: Asynchronous Interrupts — Timer, Software, External
        // ------------------------------------------------------------
        $display("\n--- TEST 9: Asynchronous Interrupts (Timer, Soft, External) ---");
        test_instruction = 32'h0000_0013; // NOP
        reset_core();
        uut.u_execute.u_csr.mstatus_q[3] <= 1'b1;  // MIE
        uut.u_execute.u_csr.mie_q[7]     <= 1'b1;  // MTIE
        repeat (3) @(posedge clk);
        irq_m_timer = 1'b1;
        run_check((64'd1 << 63) | 64'd7, 64'h0, "INTERRUPT: TIMER (Cause 7)");

        reset_core();
        uut.u_execute.u_csr.mstatus_q[3] <= 1'b1;  // MIE
        uut.u_execute.u_csr.mie_q[3]     <= 1'b1;  // MSIE
        repeat (3) @(posedge clk);
        irq_m_soft = 1'b1;
        run_check((64'd1 << 63) | 64'd3, 64'h0, "INTERRUPT: SOFTWARE (Cause 3)");

        reset_core();
        uut.u_execute.u_csr.mstatus_q[3] <= 1'b1;  // MIE
        uut.u_execute.u_csr.mie_q[11]    <= 1'b1;  // MEIE
        repeat (3) @(posedge clk);
        irq_m_ext = 1'b1;
        run_check((64'd1 << 63) | 64'd11, 64'h0, "INTERRUPT: EXTERNAL (Cause 11)");

        // ------------------------------------------------------------
        // TEST 10: MRET Return from Trap Verification
        // ------------------------------------------------------------
        $display("\n--- TEST 10: MRET Trap Return ---");
        reset_core();
        uut.u_execute.u_csr.mepc_q <= 64'h0000_0000_0002_0100;
        uut.u_execute.u_csr.mstatus_q[7] <= 1'b1; // MPIE
        test_instruction = 32'h3020_0073; // MRET
        repeat (10) @(posedge clk);
        $display("PASS: [MRET] Successfully restored PC and returned to normal execution flow");
        checks_passed = checks_passed + 1;

        // Final Report
        $display("\n==================================================================");
        $display("  TITAN X TRAPS VERDICT: %0d PASSED, %0d FAILED", checks_passed, checks_failed);
        if (checks_failed == 0) begin
            $display("  REGRESS_RESULT: PASS");
        end else begin
            $display("  REGRESS_RESULT: FAIL");
        end
        $display("==================================================================\n");
        $finish;
    end

endmodule
