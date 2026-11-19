`timescale 1ns/1ps

module axi_ram #(
    parameter MEM_SIZE = 64 * 1024 * 1024, // 64 MB
    parameter BASE_ADDR = 40'h0000_8000_0000
)(
    input wire clk,
    input wire rst_n,
    
    // Write Address
    input  wire        s_awvalid,
    output reg         s_awready,
    input  wire [39:0] s_awaddr,
    input  wire [3:0]  s_awid,
    input  wire [7:0]  s_awlen,
    
    // Write Data
    input  wire        s_wvalid,
    output reg         s_wready,
    input  wire [63:0] s_wdata,
    input  wire [7:0]  s_wstrb,
    input  wire        s_wlast,
    
    // Write Response
    output reg         s_bvalid,
    input  wire        s_bready,
    output reg  [1:0]  s_bresp,
    output reg  [3:0]  s_bid,
    
    // Read Address
    input  wire        s_arvalid,
    output reg         s_arready,
    input  wire [39:0] s_araddr,
    input  wire [3:0]  s_arid,
    input  wire [7:0]  s_arlen,
    
    // Read Data
    output reg         s_rvalid,
    input  wire        s_rready,
    output reg  [63:0] s_rdata,
    output reg  [1:0]  s_rresp,
    output reg         s_rlast,
    output reg  [3:0]  s_rid
);

    // 64-bit words (8 bytes per word)
    reg [63:0] mem [0:(MEM_SIZE/8)-1] /* verilator public */;
    
    initial begin
        $readmemh("firmware.hex", mem);
    end
    
    reg [63:0] cyc;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cyc <= 0;
        else cyc <= cyc + 1;
    end

    // --- Write Channel FSM ---
    reg [39:0] w_addr;
    reg [7:0]  w_len;
    reg [3:0]  w_id;
    reg [1:0]  w_state; // 0=IDLE, 1=DATA, 2=RESP
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_awready <= 1'b1;
            s_wready  <= 1'b0;
            s_bvalid  <= 1'b0;
            w_state   <= 0;
        end else begin
            case (w_state)
                0: begin // IDLE
                    s_bvalid <= 1'b0;
                    if (s_awvalid && s_awready) begin
                        s_awready <= 1'b0;
                        w_addr <= s_awaddr - BASE_ADDR;
                        w_len  <= s_awlen;
                        w_id   <= s_awid;
                        s_wready <= 1'b1;
                        w_state <= 1;
                    end else begin
                        s_awready <= 1'b1;
                    end
                end
                1: begin // DATA
                    if (s_wvalid && s_wready) begin
                        // Apply Write Strobe
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (s_wstrb[i]) mem[(w_addr >> 3) & ((MEM_SIZE/8)-1)][i*8 +: 8] <= s_wdata[i*8 +: 8];
                        end
                        w_addr <= w_addr + 8; // Next word
                        if (s_wlast) begin
                            s_wready <= 1'b0;
                            s_bvalid <= 1'b1;
                            s_bresp  <= 2'b00;
                            s_bid    <= w_id;
                            w_state  <= 2;
                        end
                    end
                end
                2: begin // RESP
                    if (s_bvalid && s_bready) begin
                        s_bvalid <= 1'b0;
                        s_awready <= 1'b1;
                        w_state <= 0;
                    end
                end
            endcase
        end
    end

    // --- Read Channel FSM ---
    reg [39:0] r_addr;
    reg [7:0]  r_len;
    reg [3:0]  r_id;
    reg        r_active;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_arready <= 1'b1;
            s_rvalid  <= 1'b0;
            r_active  <= 1'b0;
        end else begin
            if (!r_active) begin
                if (s_arvalid && s_arready) begin
                    s_arready <= 1'b0;
                    r_addr <= s_araddr - BASE_ADDR;
                    r_len  <= s_arlen;
                    r_id   <= s_arid;
                    r_active <= 1'b1;
                    
                    s_rvalid <= 1'b1;
                    s_rdata  <= mem[((s_araddr - BASE_ADDR) >> 3) & ((MEM_SIZE/8)-1)];
                    s_rresp  <= 2'b00;
                    s_rid    <= s_arid;
                    s_rlast  <= (s_arlen == 0);
                end else begin
                    s_arready <= 1'b1;
                end
            end else begin
                if (s_rvalid && s_rready) begin
                    if (r_len == 0) begin
                        s_rvalid <= 1'b0;
                        r_active <= 1'b0;
                        s_arready <= 1'b1;
                    end else begin
                        r_addr <= r_addr + 8;
                        r_len  <= r_len - 1;
                        s_rdata <= mem[((r_addr + 8) >> 3) & ((MEM_SIZE/8)-1)];
                        s_rlast <= (r_len == 1);
                    end
                end
            end
        end
    end

endmodule
