// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Interconnect Memory Protection Unit (MPU)
// Hardware-enforced isolation of address regions per master ID.
// Drops illegal transactions and returns clean AXI DECERR without deadlocks.
`timescale 1ns/1ps

module interconnect_mpu #(
    parameter NM = 15,       // Total masters
    parameter REGIONS = 16,  // Number of programmable regions
    parameter AW = 40,
    parameter DW = 64,
    parameter IDW = 4
) (
    input  wire clk,
    input  wire rst_n,

    // APB Config Interface (Memory Mapped Registers)
    input  wire [31:0]          paddr,
    input  wire                 psel,
    input  wire                 penable,
    input  wire                 pwrite,
    input  wire [31:0]          pwdata,
    output reg  [31:0]          prdata,
    output wire                 pready,
    output wire                 pslverr,

    // Direct Config Interface (Flattened 1D for Verilog-2001 and Yosys synthesis)
    input  wire [(REGIONS*40)-1:0] cfg_base_addr,
    input  wire [(REGIONS*40)-1:0] cfg_limit_addr,
    input  wire [(REGIONS*16)-1:0] cfg_master_mask,
    input  wire [(REGIONS*2)-1:0]  cfg_perm,
    input  wire [REGIONS-1:0]      cfg_valid,

    // Interconnect AR Channel IN (from Masters)
    input  wire [NM-1:0]        s_arvalid,
    output wire [NM-1:0]        s_arready,
    input  wire [(NM*AW)-1:0]   s_araddr,
    input  wire [(NM*IDW)-1:0]  s_arid,

    // Interconnect AR Channel OUT (to Crossbar)
    output wire [NM-1:0]        m_arvalid,
    input  wire [NM-1:0]        m_arready,
    output wire [(NM*AW)-1:0]   m_araddr,
    output wire [(NM*IDW)-1:0]  m_arid,

    // Interconnect R Channel IN (from Crossbar)
    input  wire [NM-1:0]        m_rvalid,
    output wire [NM-1:0]        m_rready,
    input  wire [(NM*DW)-1:0]   m_rdata,
    input  wire [(NM*2)-1:0]    m_rresp,
    input  wire [NM-1:0]        m_rlast,
    input  wire [(NM*IDW)-1:0]  m_rid,

    // Interconnect R Channel OUT (to Masters)
    output wire [NM-1:0]        s_rvalid,
    input  wire [NM-1:0]        s_rready,
    output wire [(NM*DW)-1:0]   s_rdata,
    output wire [(NM*2)-1:0]    s_rresp,
    output wire [NM-1:0]        s_rlast,
    output wire [(NM*IDW)-1:0]  s_rid,

    // Interconnect AW Channel IN (from Masters)
    input  wire [NM-1:0]        s_awvalid,
    output wire [NM-1:0]        s_awready,
    input  wire [(NM*AW)-1:0]   s_awaddr,
    input  wire [(NM*IDW)-1:0]  s_awid,

    // Interconnect AW Channel OUT (to Crossbar)
    output wire [NM-1:0]        m_awvalid,
    input  wire [NM-1:0]        m_awready,
    output wire [(NM*AW)-1:0]   m_awaddr,
    output wire [(NM*IDW)-1:0]  m_awid,

    // Interconnect W Channel IN (from Masters)
    input  wire [NM-1:0]        s_wvalid,
    output wire [NM-1:0]        s_wready,
    input  wire [(NM*DW)-1:0]   s_wdata,
    input  wire [(NM*(DW/8))-1:0] s_wstrb,
    input  wire [NM-1:0]        s_wlast,

    // Interconnect W Channel OUT (to Crossbar)
    output wire [NM-1:0]        m_wvalid,
    input  wire [NM-1:0]        m_wready,
    output wire [(NM*DW)-1:0]   m_wdata,
    output wire [(NM*(DW/8))-1:0] m_wstrb,
    output wire [NM-1:0]        m_wlast,

    // Interconnect B Channel IN (from Crossbar)
    input  wire [NM-1:0]        m_bvalid,
    output wire [NM-1:0]        m_bready,
    input  wire [(NM*2)-1:0]    m_bresp,
    input  wire [(NM*IDW)-1:0]  m_bid,

    // Interconnect B Channel OUT (to Masters)
    output wire [NM-1:0]        s_bvalid,
    input  wire [NM-1:0]        s_bready,
    output wire [(NM*2)-1:0]    s_bresp,
    output wire [(NM*IDW)-1:0]  s_bid
);

    // -------------------------------------------------------
    // Internal Configuration Registers (Programmable via APB)
    // -------------------------------------------------------
    reg [39:0] reg_base_addr  [0:REGIONS-1];
    reg [39:0] reg_limit_addr [0:REGIONS-1];
    reg [15:0] reg_master_mask[0:REGIONS-1];
    reg [1:0]  reg_perm       [0:REGIONS-1];
    reg        reg_valid      [0:REGIONS-1];

    wire [3:0] reg_idx = paddr[7:4];
    integer r_init;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (r_init = 0; r_init < REGIONS; r_init = r_init + 1) begin
                reg_base_addr[r_init]   <= 40'h0;
                reg_limit_addr[r_init]  <= 40'h0;
                reg_master_mask[r_init] <= 16'h0;
                reg_perm[r_init]        <= 2'b00;
                reg_valid[r_init]       <= 1'b0;
            end
        end else if (psel && penable && pwrite) begin
            case (paddr[3:2])
                2'b00: reg_base_addr[reg_idx][31:0]  <= pwdata;
                2'b01: reg_limit_addr[reg_idx][31:0] <= pwdata;
                2'b10: reg_master_mask[reg_idx]      <= pwdata[15:0];
                2'b11: begin
                    reg_valid[reg_idx]             <= pwdata[0];
                    reg_perm[reg_idx]              <= pwdata[2:1];
                    reg_base_addr[reg_idx][39:32]  <= pwdata[7:4];
                    reg_limit_addr[reg_idx][39:32] <= pwdata[11:8];
                end
            endcase
        end
    end

    always @(*) begin
        case (paddr[3:2])
            2'b00: prdata = reg_base_addr[reg_idx][31:0];
            2'b01: prdata = reg_limit_addr[reg_idx][31:0];
            2'b10: prdata = {16'h0, reg_master_mask[reg_idx]};
            2'b11: prdata = {20'h0, reg_limit_addr[reg_idx][39:32], reg_base_addr[reg_idx][39:32], 1'b0, reg_perm[reg_idx], reg_valid[reg_idx]};
            default: prdata = 32'h0;
        endcase
    end

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    // -------------------------------------------------------
    // Effective Region Configuration (combines APB + Direct ports)
    // -------------------------------------------------------
    wire [39:0] eff_base  [0:REGIONS-1];
    wire [39:0] eff_limit [0:REGIONS-1];
    wire [15:0] eff_mask  [0:REGIONS-1];
    wire [1:0]  eff_perm  [0:REGIONS-1];
    wire        eff_valid [0:REGIONS-1];

    genvar gr;
    generate
        for (gr = 0; gr < REGIONS; gr = gr + 1) begin : gen_eff_cfg
            wire        port_valid = cfg_valid[gr];
            wire [39:0] port_base  = cfg_base_addr[gr*40 +: 40];
            wire [39:0] port_limit = cfg_limit_addr[gr*40 +: 40];
            wire [15:0] port_mask  = cfg_master_mask[gr*16 +: 16];
            wire [1:0]  port_perm  = cfg_perm[gr*2 +: 2];

            assign eff_valid[gr] = port_valid | reg_valid[gr];
            assign eff_base[gr]  = port_valid ? port_base  : reg_base_addr[gr];
            assign eff_limit[gr] = port_valid ? port_limit : reg_limit_addr[gr];
            assign eff_mask[gr]  = port_valid ? port_mask  : reg_master_mask[gr];
            assign eff_perm[gr]  = port_valid ? port_perm  : reg_perm[gr];
        end
    endgenerate

    // -------------------------------------------------------
    // Per-Master Protection & Handshaking Channels
    // -------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < NM; i = i + 1) begin : gen_mpu_check
            wire [AW-1:0] ar_addr = s_araddr[i*AW +: AW];
            wire [AW-1:0] aw_addr = s_awaddr[i*AW +: AW];

            reg ar_allowed;
            reg aw_allowed;
            integer r;

            always @(*) begin
                // Default policy: unconfigured regions allow traffic
                ar_allowed = 1'b1;
                aw_allowed = 1'b1;
                for (r = 0; r < REGIONS; r = r + 1) begin
                    if (eff_valid[r]) begin
                        if (ar_addr >= eff_base[r] && ar_addr <= eff_limit[r]) begin
                            ar_allowed = (eff_mask[r][i] && (eff_perm[r] == 2'b01 || eff_perm[r] == 2'b11));
                        end
                        if (aw_addr >= eff_base[r] && aw_addr <= eff_limit[r]) begin
                            aw_allowed = (eff_mask[r][i] && (eff_perm[r] == 2'b10 || eff_perm[r] == 2'b11));
                        end
                    end
                end
            end

            // ── Read Channel (AR / R) ─────────────────────────────
            reg            pending_ar_decerr;
            reg [IDW-1:0]  decerr_arid;

            wire ar_block = s_arvalid[i] && !ar_allowed;
            assign m_arvalid[i]         = s_arvalid[i] && ar_allowed && !pending_ar_decerr;
            assign m_araddr[i*AW +: AW] = ar_addr;
            assign m_arid[i*IDW +: IDW] = s_arid[i*IDW +: IDW];
            assign s_arready[i]         = pending_ar_decerr ? 1'b0 :
                                          (ar_allowed ? m_arready[i] : 1'b1);

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    pending_ar_decerr <= 1'b0;
                    decerr_arid       <= {IDW{1'b0}};
                end else begin
                    if (ar_block && s_arready[i]) begin
                        pending_ar_decerr <= 1'b1;
                        decerr_arid       <= s_arid[i*IDW +: IDW];
                    end else if (pending_ar_decerr && s_rready[i]) begin
                        pending_ar_decerr <= 1'b0;
                    end
                end
            end

            assign s_rvalid[i]         = pending_ar_decerr ? 1'b1 : m_rvalid[i];
            assign s_rdata[i*DW +: DW] = pending_ar_decerr ? {DW{1'b0}} : m_rdata[i*DW +: DW];
            assign s_rresp[i*2 +: 2]   = pending_ar_decerr ? 2'b11 : m_rresp[i*2 +: 2]; // 2'b11 = DECERR
            assign s_rlast[i]          = pending_ar_decerr ? 1'b1 : m_rlast[i];
            assign s_rid[i*IDW +: IDW] = pending_ar_decerr ? decerr_arid : m_rid[i*IDW +: IDW];
            assign m_rready[i]         = pending_ar_decerr ? 1'b0 : s_rready[i];

            // ── Write Channel (AW / W / B) ────────────────────────
            reg            denied_wr_active;
            reg            pending_aw_decerr;
            reg [IDW-1:0]  decerr_awid;

            wire aw_block = s_awvalid[i] && !aw_allowed;
            assign m_awvalid[i]         = s_awvalid[i] && aw_allowed && !denied_wr_active && !pending_aw_decerr;
            assign m_awaddr[i*AW +: AW] = aw_addr;
            assign m_awid[i*IDW +: IDW] = s_awid[i*IDW +: IDW];
            assign s_awready[i]         = (denied_wr_active || pending_aw_decerr) ? 1'b0 :
                                          (aw_allowed ? m_awready[i] : 1'b1);

            wire safe_wvalid = (s_wvalid[i] === 1'b1);

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    denied_wr_active  <= 1'b0;
                    pending_aw_decerr <= 1'b0;
                    decerr_awid       <= {IDW{1'b0}};
                end else begin
                    if (aw_block && s_awready[i]) begin
                        denied_wr_active <= 1'b1;
                        decerr_awid      <= s_awid[i*IDW +: IDW];
                    end

                    // Once write is blocked, drain W beats until WLAST
                    if (denied_wr_active && safe_wvalid && s_wready[i] && s_wlast[i]) begin
                        denied_wr_active  <= 1'b0;
                        pending_aw_decerr <= 1'b1;
                    end else if (pending_aw_decerr && s_bready[i]) begin
                        pending_aw_decerr <= 1'b0;
                    end
                end
            end

            // W channel: passed through when allowed; safely absorbed locally when blocked
            assign s_wready[i] = denied_wr_active ? 1'b1 : m_wready[i];
            assign m_wvalid[i] = denied_wr_active ? 1'b0 : safe_wvalid;
            assign m_wdata[i*DW +: DW]             = s_wdata[i*DW +: DW];
            assign m_wstrb[i*(DW/8) +: (DW/8)]     = s_wstrb[i*(DW/8) +: (DW/8)];
            assign m_wlast[i]                      = s_wlast[i];

            // B channel: returns DECERR when write was blocked; passes through otherwise
            assign s_bvalid[i]         = pending_aw_decerr ? 1'b1 : m_bvalid[i];
            assign s_bresp[i*2 +: 2]   = pending_aw_decerr ? 2'b11 : m_bresp[i*2 +: 2]; // 2'b11 = DECERR
            assign s_bid[i*IDW +: IDW] = pending_aw_decerr ? decerr_awid : m_bid[i*IDW +: IDW];
            assign m_bready[i]         = pending_aw_decerr ? 1'b0 : s_bready[i];

        end
    endgenerate

endmodule
