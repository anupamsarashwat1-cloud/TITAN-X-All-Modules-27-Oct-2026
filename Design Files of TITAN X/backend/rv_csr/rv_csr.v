// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Machine and Supervisor Mode CSR file (Zicsr + Privileged Spec v1.12)
`timescale 1ns/1ps
`include "params.vh"
`include "isa_pkg.vh"

module rv_csr #(
    parameter HART_ID = 0
) (
    input  wire        clk,
    input  wire        rst_n,
    // combinational read port (execute)
    input  wire [11:0] csr_raddr,
    output reg  [63:0] csr_rdata,
    // synchronous write port (execute, one pulse per retiring CSR op)
    input  wire        csr_we,
    input  wire [11:0] csr_waddr,
    input  wire [63:0] csr_wdata,
    // trap entry / return (core-level control, single pulse each)
    input  wire        trap_we,          // capture mepc/mcause/mtval/mstatus or sepc/scause/stval/sstatus
    input  wire [63:0] trap_pc,          // PC of the trapping instruction
    input  wire [63:0] trap_cause,
    input  wire [63:0] trap_tval,
    input  wire        mret_we,          // mstatus MPIE/MIE shuffle
    input  wire        sret_we,          // sstatus SPIE/SIE shuffle
    // machine interrupt pending (from CLINT/PLIC glue; active high)
    input  wire        mip_m_ext,
    input  wire        mip_m_timer,
    input  wire        mip_m_soft,
    // performance: one pulse per retired instruction
    input  wire        retire_pulse,
    // status out for the core/trap logic
    output wire [63:0] mtvec_out,
    output wire [63:0] mepc_out,
    output wire [63:0] mtval_out,
    output wire [63:0] stvec_out,
    output wire [63:0] sepc_out,
    output wire [63:0] medeleg_out,
    output wire [63:0] mideleg_out,
    output wire [63:0] satp_out,
    output reg  [1:0]  priv_mode_out,
    output wire        irq_pending      // enabled machine/supervisor interrupt waiting
);

    // -------------------------------------------------------
    // Register state
    // -------------------------------------------------------
    reg [63:0] mstatus_q;
    reg [63:0] misa_q;
    reg [63:0] medeleg_q;
    reg [63:0] mideleg_q;
    reg [63:0] mie_q;
    reg [63:0] mtvec_q;
    reg [31:0] mcounteren_q;
    reg [31:0] mcountinhibit_q;
    reg [63:0] mscratch_q;
    reg [63:0] mepc_q;
    reg [63:0] mcause_q;
    reg [63:0] mtval_q;
    reg        mip_s_soft_q;
    reg        mip_s_timer_q;
    reg        mip_s_ext_q;

    // Supervisor Mode CSRs
    reg [63:0] stvec_q;
    reg [31:0] scounteren_q;
    reg [63:0] sscratch_q;
    reg [63:0] sepc_q;
    reg [63:0] scause_q;
    reg [63:0] stval_q;
    reg [63:0] satp_q;

    reg [63:0] mcycle_q, minstret_q;

    // RV64IMASU: Base RV64 (2 << 62) + User (1 << 20) + Supervisor (1 << 18) + M (1 << 12) + I (1 << 8) + A (1 << 0)
    localparam [63:0] MISA_RV64IM =
        (64'd2 << 62) | (64'd1 << 20) | (64'd1 << 18) | (64'd1 << 12) | (64'd1 << 8) | (64'd1 << 0);

    // -------------------------------------------------------
    // Derived Register Signals
    // -------------------------------------------------------
    wire [63:0] mip_val = {
        52'h0,
        mip_m_ext,      // 11: MEIP
        1'b0,
        mip_s_ext_q,    // 9:  SEIP
        1'b0,
        mip_m_timer,    // 7:  MTIP
        1'b0,
        mip_s_timer_q,  // 5:  STIP
        1'b0,
        mip_m_soft,     // 3:  MSIP
        1'b0,
        mip_s_soft_q,   // 1:  SSIP
        1'b0
    };

    wire [63:0] sip_val = mip_val & mideleg_q;

    wire mstatus_sd = (mstatus_q[14:13] == 2'b11) | (mstatus_q[16:15] == 2'b11);

    wire [63:0] mstatus_rdata = {
        mstatus_sd,            // 63: SD
        27'b0,
        2'b10,                 // 35:34: SXL = 64-bit
        2'b10,                 // 33:32: UXL = 64-bit
        9'b0,
        mstatus_q[22:17],      // 22:17: TSR, TW, TVM, MXR, SUM, MPRV
        mstatus_q[16:13],      // 16:13: XS, FS
        mstatus_q[12:11],      // 12:11: MPP
        2'b0,
        mstatus_q[8],          // 8: SPP
        mstatus_q[7],          // 7: MPIE
        1'b0,
        mstatus_q[5],          // 5: SPIE
        1'b0,
        mstatus_q[3],          // 3: MIE
        1'b0,
        mstatus_q[1],          // 1: SIE
        1'b0
    };

    wire [63:0] sstatus_rdata = {
        mstatus_sd,            // 63: SD
        29'b0,
        2'b10,                 // 33:32: UXL = 64-bit
        12'b0,
        mstatus_q[19:18],      // 19:18: MXR, SUM
        1'b0,
        mstatus_q[16:13],      // 16:13: XS, FS
        4'b0,
        mstatus_q[8],          // 8: SPP
        2'b0,
        mstatus_q[5],          // 5: SPIE
        3'b0,
        mstatus_q[1],          // 1: SIE
        1'b0
    };

    // -------------------------------------------------------
    // Read decode (combinational)
    // -------------------------------------------------------
    always @(*) begin
        case (csr_raddr)
            12'h300:    csr_rdata = mstatus_rdata;
            12'h301:    csr_rdata = misa_q;
            12'h302:    csr_rdata = medeleg_q;
            12'h303:    csr_rdata = mideleg_q;
            12'h304:    csr_rdata = mie_q;
            12'h305:    csr_rdata = mtvec_q;
            12'h306:    csr_rdata = {32'h0, mcounteren_q};
            12'h320:    csr_rdata = {32'h0, mcountinhibit_q};
            12'h340:    csr_rdata = mscratch_q;
            12'h341:    csr_rdata = mepc_q;
            12'h342:    csr_rdata = mcause_q;
            12'h343:    csr_rdata = mtval_q;
            12'h344:    csr_rdata = mip_val;
            12'h100:    csr_rdata = sstatus_rdata;
            12'h104:    csr_rdata = mie_q & mideleg_q; // sie
            12'h105:    csr_rdata = stvec_q;
            12'h106:    csr_rdata = {32'h0, scounteren_q};
            12'h140:    csr_rdata = sscratch_q;
            12'h141:    csr_rdata = sepc_q;
            12'h142:    csr_rdata = scause_q;
            12'h143:    csr_rdata = stval_q;
            12'h144:    csr_rdata = sip_val;
            12'h180:    csr_rdata = satp_q;
            12'hF11:    csr_rdata = 64'h0; // mvendorid
            12'hF12:    csr_rdata = 64'h0; // marchid
            12'hF13:    csr_rdata = 64'h0; // mimpid
            12'hF14:    csr_rdata = {52'h0, HART_ID[11:0]}; // mhartid
            12'hB00:    csr_rdata = mcycle_q;
            12'hB02:    csr_rdata = minstret_q;
            12'hC00:    csr_rdata = mcycle_q;            // cycle alias
            12'hC01:    csr_rdata = mcycle_q;            // time alias
            12'hC02:    csr_rdata = minstret_q;          // instret alias
            default:    csr_rdata = 64'h0;               // PMP and HPM read 0
        endcase
    end

    // -------------------------------------------------------
    // Trap Delegation Determination
    // -------------------------------------------------------
    wire trap_to_s = (priv_mode_out < `PRIV_M) &&
                     (trap_cause[63] ? mideleg_q[trap_cause[5:0]] : medeleg_q[trap_cause[5:0]]);

    // -------------------------------------------------------
    // Writes (priority: trap > mret > sret > explicit CSR op)
    // -------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            priv_mode_out   <= `PRIV_M;
            mstatus_q       <= 64'h0000_0000_0000_1800; // MPP defaults to M-mode (2'b11)
            misa_q          <= MISA_RV64IM;
            medeleg_q       <= 64'h0;
            mideleg_q       <= 64'h0;
            mie_q           <= 64'h0;
            mtvec_q         <= 64'h0;
            mcounteren_q    <= 32'h0;
            mcountinhibit_q <= 32'h0;
            mscratch_q      <= 64'h0;
            mepc_q          <= 64'h0;
            mcause_q        <= 64'h0;
            mtval_q         <= 64'h0;
            mip_s_soft_q    <= 1'b0;
            mip_s_timer_q   <= 1'b0;
            mip_s_ext_q     <= 1'b0;
            stvec_q         <= 64'h0;
            scounteren_q    <= 32'h0;
            sscratch_q      <= 64'h0;
            sepc_q          <= 64'h0;
            scause_q        <= 64'h0;
            stval_q         <= 64'h0;
            satp_q          <= 64'h0;
            mcycle_q        <= 64'h0;
            minstret_q      <= 64'h0;
        end else begin
            // Performance counters
            mcycle_q <= mcycle_q + 64'd1;
            if (retire_pulse)
                minstret_q <= minstret_q + 64'd1;

            if (trap_we) begin
                if (trap_to_s) begin
                    sepc_q           <= {trap_pc[63:2], 2'b00};
                    scause_q         <= trap_cause;
                    stval_q          <= trap_tval;
                    mstatus_q[5]     <= mstatus_q[1];         // SPIE <- SIE
                    mstatus_q[1]     <= 1'b0;                 // enter handler SIE off
                    mstatus_q[8]     <= priv_mode_out[0];     // SPP <- previous priv
                    priv_mode_out    <= `PRIV_S;              // Traps vector to S-mode
                end else begin
                    mepc_q           <= {trap_pc[63:2], 2'b00};
                    mcause_q         <= trap_cause;
                    mtval_q          <= trap_tval;
                    mstatus_q[7]     <= mstatus_q[3];         // MPIE <- MIE
                    mstatus_q[3]     <= 1'b0;                 // enter handler MIE off
                    mstatus_q[12:11] <= priv_mode_out;        // MPP <- previous priv
                    priv_mode_out    <= `PRIV_M;              // Traps vector to M-mode
                end
            end else if (mret_we) begin
                mstatus_q[3]     <= mstatus_q[7];         // MIE <- MPIE
                mstatus_q[7]     <= 1'b1;
                priv_mode_out    <= mstatus_q[12:11];     // Return to MPP mode
                mstatus_q[12:11] <= `PRIV_U;              // Reset MPP to User mode
            end else if (sret_we) begin
                mstatus_q[1]     <= mstatus_q[5];         // SIE <- SPIE
                mstatus_q[5]     <= 1'b1;
                priv_mode_out    <= mstatus_q[8] ? `PRIV_S : `PRIV_U; // Return to SPP mode
                mstatus_q[8]     <= 1'b0;                 // Reset SPP to User mode
            end else if (csr_we) begin
                case (csr_waddr)
                    12'h300: begin
                        mstatus_q[1]     <= csr_wdata[1];     // SIE
                        mstatus_q[3]     <= csr_wdata[3];     // MIE
                        mstatus_q[5]     <= csr_wdata[5];     // SPIE
                        mstatus_q[7]     <= csr_wdata[7];     // MPIE
                        mstatus_q[8]     <= csr_wdata[8];     // SPP
                        mstatus_q[12:11] <= csr_wdata[12:11]; // MPP
                        mstatus_q[14:13] <= csr_wdata[14:13]; // FS
                        mstatus_q[16:15] <= csr_wdata[16:15]; // XS
                        mstatus_q[17]    <= csr_wdata[17];    // MPRV
                        mstatus_q[18]    <= csr_wdata[18];    // SUM
                        mstatus_q[19]    <= csr_wdata[19];    // MXR
                        mstatus_q[20]    <= csr_wdata[20];    // TVM
                        mstatus_q[21]    <= csr_wdata[21];    // TW
                        mstatus_q[22]    <= csr_wdata[22];    // TSR
                    end
                    12'h301: misa_q          <= misa_q;     // WARL: unchanged
                    12'h302: medeleg_q       <= csr_wdata;
                    12'h303: mideleg_q       <= csr_wdata;
                    12'h304: mie_q           <= csr_wdata;
                    12'h305: mtvec_q         <= {csr_wdata[63:2], 2'b00};
                    12'h306: mcounteren_q    <= csr_wdata[31:0];
                    12'h320: mcountinhibit_q <= csr_wdata[31:0];
                    12'h340: mscratch_q      <= csr_wdata;
                    12'h341: mepc_q          <= {csr_wdata[63:2], 2'b00};
                    12'h342: mcause_q        <= csr_wdata;
                    12'h343: mtval_q         <= csr_wdata;
                    12'h344: begin
                        mip_s_soft_q         <= csr_wdata[1]; // SSIP writable
                        mip_s_timer_q        <= csr_wdata[5]; // STIP writable
                        mip_s_ext_q          <= csr_wdata[9]; // SEIP writable
                    end
                    12'h100: begin
                        mstatus_q[1]     <= csr_wdata[1];     // SIE
                        mstatus_q[5]     <= csr_wdata[5];     // SPIE
                        mstatus_q[8]     <= csr_wdata[8];     // SPP
                        mstatus_q[14:13] <= csr_wdata[14:13]; // FS
                        mstatus_q[16:15] <= csr_wdata[16:15]; // XS
                        mstatus_q[18]    <= csr_wdata[18];    // SUM
                        mstatus_q[19]    <= csr_wdata[19];    // MXR
                    end
                    12'h104: mie_q           <= (mie_q & ~mideleg_q) | (csr_wdata & mideleg_q);
                    12'h105: stvec_q         <= {csr_wdata[63:2], 2'b00};
                    12'h106: scounteren_q    <= csr_wdata[31:0];
                    12'h140: sscratch_q      <= csr_wdata;
                    12'h141: sepc_q          <= {csr_wdata[63:2], 2'b00};
                    12'h142: scause_q        <= csr_wdata;
                    12'h143: stval_q         <= csr_wdata;
                    12'h144: mip_s_soft_q    <= csr_wdata[1];
                    12'h180: satp_q          <= csr_wdata;
                    default: ;                                // PMP, HPM, RO ignored
                endcase
            end
        end
    end

    assign mtvec_out   = {mtvec_q[63:2], 2'b00};
    assign mepc_out    = {mepc_q[63:2], 2'b00};
    assign mtval_out   = mtval_q;
    assign stvec_out   = {stvec_q[63:2], 2'b00};
    assign sepc_out    = {sepc_q[63:2], 2'b00};
    assign medeleg_out = medeleg_q;
    assign mideleg_out = mideleg_q;
    assign satp_out    = satp_q;

    wire m_irq_pend = (| (mip_val & mie_q & ~mideleg_q)) &&
                      ((priv_mode_out < `PRIV_M) || mstatus_q[3]);
    wire s_irq_pend = (| (mip_val & mie_q & mideleg_q)) &&
                      ((priv_mode_out < `PRIV_S) || (priv_mode_out == `PRIV_S && mstatus_q[1]));

    assign irq_pending = m_irq_pend | s_irq_pend;

endmodule
