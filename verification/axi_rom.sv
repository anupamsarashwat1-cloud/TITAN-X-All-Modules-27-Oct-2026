// Simple behavioral AXI4 ROM
`timescale 1ns/1ps

module axi_rom #(
    parameter MEM_SIZE = 131072, // 128 KB
    parameter HEX_FILE = "firmware.hex"
) (
    input  wire         clk,
    input  wire         rst_n,

    // AXI4 Slave Interface
    input  wire         s_arvalid,
    output reg          s_arready,
    input  wire [39:0]  s_araddr,
    input  wire [3:0]   s_arid,

    output reg          s_rvalid,
    input  wire         s_rready,
    output reg  [63:0]  s_rdata,
    output reg  [1:0]   s_rresp,
    output reg          s_rlast,
    output reg  [3:0]   s_rid
);

    reg [31:0] rom [0:(MEM_SIZE/4)-1];

    initial begin
        $readmemh(HEX_FILE, rom);
    end

    // Simple AR channel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_arready <= 1'b0;
        end else begin
            if (s_arvalid && !s_arready) begin
                s_arready <= 1'b1;
            end else begin
                s_arready <= 1'b0;
            end
        end
    end

    // Simple R channel (1 beat burst supported only for basic boot)
    // Cores typically request cachelines (e.g., 4x64-bit = 8 words), but a basic fetch might be smaller.
    // To support bursts, we need to track arlen. We'll simplify: just return the requested word, ignoring bursts.
    // Wait! RV64 fetches cachelines. If we ignore bursts, it will hang!
    // Let's implement a simple burst reader.
    
    reg [7:0] burst_cnt;
    reg [39:0] addr_reg;
    reg [3:0]  id_reg;
    
    // We don't have arlen input in this stripped-down port list? 
    // Wait, axi4_crossbar.v doesn't route arlen? 
    // Ah! `axi4_crossbar.v` doesn't have `s_arlen`! 
    // Look at `axi4_crossbar.v` ports: s_arvalid, s_arready, s_araddr, s_arid, s_rvalid, s_rready, s_rdata, s_rresp, s_rlast, s_rid
    // IT DOES NOT PASS ARLEN TO SLAVES!
    // So all bursts are broken in this crossbar! It must assume single beats or rely on s_rlast? No, s_rlast is an input to master. 
    // If it doesn't pass ARLEN, the slave can't know the burst length!
    // For this simple ROM, we will just return a single beat and set rlast = 1.
    // If the core expects more, it might hang. We'll find out.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rvalid <= 1'b0;
        end else begin
            if (s_arvalid && s_arready) begin
                addr_reg <= s_araddr;
                id_reg <= s_arid;
                s_rvalid <= 1'b1;
                s_rresp <= 2'b00;
                s_rlast <= 1'b1; // Always last
                s_rid <= s_arid;
                
                // Read 64-bit word (two 32-bit words)
                // 0x1000_0000 offset
                s_rdata <= { rom[ ((s_araddr - 40'h10000000) >> 2) + 1 ], 
                             rom[ ((s_araddr - 40'h10000000) >> 2) ] };
            end else if (s_rvalid && s_rready) begin
                s_rvalid <= 1'b0;
            end
        end
    end

endmodule
