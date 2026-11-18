module sync_cell (
    input  wire clk,
    input  wire rst_n,
    input  wire d,
    output reg  q
);
    reg q1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= 1'b0;
            q  <= 1'b0;
        end else begin
            q1 <= d;
            q  <= q1;
        end
    end
endmodule
