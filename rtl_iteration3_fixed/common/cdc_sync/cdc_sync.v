// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — CDC 2-FF Synchronizer
`timescale 1ns/1ps
module cdc_sync #(
    parameter WIDTH  = 1,
    parameter STAGES = 2
) (
    input  wire               dst_clk,
    input  wire               rst_n,
    input  wire [WIDTH-1:0]   data_in,
    output wire [WIDTH-1:0]   data_out
);
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] sync_ff [0:STAGES-1];
    integer i;

    always @(posedge dst_clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff[0] <= {WIDTH{1'b0}};
            sync_ff[1] <= {WIDTH{1'b0}};
        end else begin
            sync_ff[0] <= data_in;
            sync_ff[1] <= sync_ff[0];
        end
    end

    assign data_out = sync_ff[STAGES-1];
endmodule
