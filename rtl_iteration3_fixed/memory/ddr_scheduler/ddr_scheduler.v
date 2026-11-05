// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — DDR Scheduler (Open-Row Policy)
// Accepts commands from ddr_ctrl_top and sequences ACT/CAS/PRE
`timescale 1ns/1ps
module ddr_scheduler #(
    parameter BANKS    = 8,
    parameter ROWS     = 65536,
    parameter COLS     = 1024,
    parameter tRCD     = 4,   // cycles
    parameter tRP      = 4,
    parameter tCAS     = 4
) (
    input  wire        clk,
    input  wire        rst_n,
    // Command from controller
    input  wire        cmd_valid,
    input  wire [1:0]  cmd_type,    // 00=RD, 01=WR, 10=ACT, 11=PRE
    input  wire [2:0]  cmd_bank,
    input  wire [15:0] cmd_row,
    input  wire [9:0]  cmd_col,
    output reg         cmd_ready,
    output reg  [63:0] rd_data,
    output reg         rd_valid,
    input  wire [63:0] wr_data,
    // DFI command outputs to PHY
    output reg         dfi_cs_n,
    output reg         dfi_ras_n,
    output reg         dfi_cas_n,
    output reg         dfi_we_n,
    output reg         dfi_act_n,
    output reg  [2:0]  dfi_bank,
    output reg  [15:0] dfi_addr,
    output reg         dfi_wrdata_valid,
    output reg  [63:0] dfi_wrdata,
    input  wire [63:0] dfi_rddata,
    input  wire        dfi_rddata_valid
);
    localparam CMD_RD  = 2'd0;
    localparam CMD_WR  = 2'd1;
    localparam CMD_ACT = 2'd2;
    localparam CMD_PRE = 2'd3;

    // Open-row tracking
    reg [15:0] open_row   [0:BANKS-1];
    reg        row_open   [0:BANKS-1];
    integer    i;

    // Timing counters
    reg [3:0] tRCD_cnt, tRP_cnt, tCAS_cnt;

    localparam SC_IDLE  = 3'd0;
    localparam SC_PRE   = 3'd1;
    localparam SC_TRPW  = 3'd2;
    localparam SC_ACT   = 3'd3;
    localparam SC_TRCDW = 3'd4;
    localparam SC_CAS   = 3'd5;
    localparam SC_CASW  = 3'd6;
    localparam SC_DONE  = 3'd7;

    reg [2:0]  sched_state;
    reg [1:0]  saved_cmd_type;
    reg [2:0]  saved_bank;
    reg [15:0] saved_row;
    reg [9:0]  saved_col;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < BANKS; i = i+1) begin
                open_row[i] <= 16'h0;
                row_open[i] <= 1'b0;
            end
            cmd_ready      <= 1'b1;
            dfi_cs_n       <= 1'b1;
            dfi_ras_n      <= 1'b1;
            dfi_cas_n      <= 1'b1;
            dfi_we_n       <= 1'b1;
            dfi_act_n      <= 1'b1;
            dfi_bank       <= 3'h0;
            dfi_addr       <= 16'h0;
            dfi_wrdata_valid <= 1'b0;
            dfi_wrdata     <= 64'h0;
            rd_valid       <= 1'b0;
            tRCD_cnt       <= 4'h0;
            tRP_cnt        <= 4'h0;
            tCAS_cnt       <= 4'h0;
            sched_state    <= SC_IDLE;
        end else begin
            dfi_cs_n       <= 1'b1;  // Default: NOP
            dfi_ras_n      <= 1'b1;
            dfi_cas_n      <= 1'b1;
            dfi_we_n       <= 1'b1;
            dfi_act_n      <= 1'b1;
            dfi_wrdata_valid <= 1'b0;
            rd_valid       <= 1'b0;

            case (sched_state)
                SC_IDLE: begin
                    cmd_ready <= 1'b1;
                    if (cmd_valid) begin
                        cmd_ready      <= 1'b0;
                        saved_cmd_type <= cmd_type;
                        saved_bank     <= cmd_bank;
                        saved_row      <= cmd_row;
                        saved_col      <= cmd_col;
                        if (row_open[cmd_bank] && open_row[cmd_bank] == cmd_row) begin
                            // Row already open: go direct to CAS
                            sched_state <= SC_CAS;
                        end else if (row_open[cmd_bank]) begin
                            // Different row open: precharge first
                            dfi_cs_n  <= 1'b0;
                            dfi_ras_n <= 1'b0;
                            dfi_we_n  <= 1'b0;
                            dfi_bank  <= cmd_bank;
                            dfi_addr  <= 16'h0400; // AP bit
                            tRP_cnt   <= tRP[3:0];
                            row_open[cmd_bank] <= 1'b0;
                            sched_state <= SC_TRPW;
                        end else begin
                            // Row closed: ACT
                            sched_state <= SC_ACT;
                        end
                    end
                end

                SC_TRPW: begin
                    if (tRP_cnt == 4'h0) sched_state <= SC_ACT;
                    else tRP_cnt <= tRP_cnt - 4'h1;
                end

                SC_ACT: begin
                    dfi_cs_n  <= 1'b0;
                    dfi_ras_n <= 1'b0;
                    dfi_act_n <= 1'b0;
                    dfi_bank  <= saved_bank;
                    dfi_addr  <= saved_row;
                    open_row[saved_bank] <= saved_row;
                    row_open[saved_bank] <= 1'b1;
                    tRCD_cnt  <= tRCD[3:0];
                    sched_state <= SC_TRCDW;
                end

                SC_TRCDW: begin
                    if (tRCD_cnt == 4'h0) sched_state <= SC_CAS;
                    else tRCD_cnt <= tRCD_cnt - 4'h1;
                end

                SC_CAS: begin
                    dfi_cs_n  <= 1'b0;
                    dfi_cas_n <= 1'b0;
                    dfi_bank  <= saved_bank;
                    dfi_addr  <= {{6{1'b0}}, saved_col};
                    if (saved_cmd_type == CMD_WR) begin
                        dfi_we_n         <= 1'b0;
                        dfi_wrdata_valid <= 1'b1;
                        dfi_wrdata       <= wr_data;
                    end
                    tCAS_cnt    <= tCAS[3:0];
                    sched_state <= SC_CASW;
                end

                SC_CASW: begin
                    if (tCAS_cnt == 4'h0) begin
                        if (saved_cmd_type == CMD_RD) begin
                            rd_data  <= dfi_rddata;
                            rd_valid <= dfi_rddata_valid;
                        end
                        sched_state <= SC_IDLE;
                    end else begin
                        tCAS_cnt <= tCAS_cnt - 4'h1;
                    end
                end

                default: sched_state <= SC_IDLE;
            endcase
        end
    end
endmodule
