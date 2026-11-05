// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — AXI4-Lite to APB Bridge
// Iteration 3: 32-bit APB (AMBA 3 APB) Compliance
// Converts AXI4-Lite transactions into standard APB transfers.
`timescale 1ns/1ps

module apb_bridge #(
    parameter AW = 32, // APB address width
    parameter DW = 32  // APB data width (32-bit compliant)
) (
    input  wire          clk,
    input  wire          rst_n,

    // AXI4-Lite Slave Interface
    input  wire          s_awvalid,
    output wire          s_awready,
    input  wire [AW-1:0] s_awaddr,
    
    input  wire          s_wvalid,
    output wire          s_wready,
    input  wire [DW-1:0] s_wdata,
    input  wire [(DW/8)-1:0] s_wstrb,
    
    output wire          s_bvalid,
    input  wire          s_bready,
    output wire [1:0]    s_bresp,
    
    input  wire          s_arvalid,
    output wire          s_arready,
    input  wire [AW-1:0] s_araddr,
    
    output wire          s_rvalid,
    input  wire          s_rready,
    output wire [DW-1:0] s_rdata,
    output wire [1:0]    s_rresp,

    // APB Master Interface
    output wire [AW-1:0] paddr,
    output wire          psel,
    output wire          penable,
    output wire          pwrite,
    output wire [DW-1:0] pwdata,
    output wire [(DW/8)-1:0] pstrb, // APB4 extension
    input  wire [DW-1:0] prdata,
    input  wire          pready,
    input  wire          pslverr
);

    // -------------------------------------------------------
    // State Machine for APB Bridge
    // -------------------------------------------------------
    localparam IDLE   = 2'd0;
    localparam SETUP  = 2'd1;
    localparam ACCESS = 2'd2;

    reg [1:0] state, next_state;

    // Registers to hold transaction details
    reg [AW-1:0] addr_reg;
    reg [DW-1:0] wdata_reg;
    reg [(DW/8)-1:0] wstrb_reg;
    reg          is_write;

    // AXI handshake tracking
    reg aw_accepted, w_accepted, ar_accepted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            addr_reg <= {AW{1'b0}};
            wdata_reg <= {DW{1'b0}};
            wstrb_reg <= {(DW/8){1'b0}};
            is_write <= 1'b0;
            aw_accepted <= 1'b0;
            w_accepted <= 1'b0;
            ar_accepted <= 1'b0;
        end else begin
            state <= next_state;

            // Latch write address
            if (s_awvalid && s_awready) begin
                aw_accepted <= 1'b1;
                addr_reg <= s_awaddr;
            end
            
            // Latch write data
            if (s_wvalid && s_wready) begin
                w_accepted <= 1'b1;
                wdata_reg <= s_wdata;
                wstrb_reg <= s_wstrb;
            end

            // Latch read address
            if (s_arvalid && s_arready && state == IDLE) begin
                ar_accepted <= 1'b1;
                addr_reg <= s_araddr;
            end

            // Determine if it's a write or read
            if (state == IDLE) begin
                if (s_awvalid || aw_accepted) begin
                    is_write <= 1'b1;
                end else if (s_arvalid) begin
                    is_write <= 1'b0;
                end
            end

            // Clear acceptance flags when APB transaction finishes
            if (state == ACCESS && pready) begin
                aw_accepted <= 1'b0;
                w_accepted  <= 1'b0;
                ar_accepted <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                // Need both AW and W for write, or just AR for read
                if ((s_awvalid || aw_accepted) && (s_wvalid || w_accepted)) begin
                    next_state = SETUP;
                end else if (s_arvalid || ar_accepted) begin
                    next_state = SETUP;
                end
            end
            SETUP: begin
                next_state = ACCESS;
            end
            ACCESS: begin
                if (pready) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // AXI Ready Signals
    assign s_awready = (state == IDLE) && !aw_accepted && !s_arvalid; // Prefer reads slightly or block writes if read active
    assign s_wready  = (state == IDLE) && !w_accepted && !s_arvalid;
    assign s_arready = (state == IDLE) && !ar_accepted && !s_awvalid;

    // AXI Response Signals
    reg bvalid_reg;
    reg rvalid_reg;
    reg [1:0] bresp_reg;
    reg [1:0] rresp_reg;
    reg [DW-1:0] rdata_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid_reg <= 1'b0;
            rvalid_reg <= 1'b0;
            bresp_reg  <= 2'b00;
            rresp_reg  <= 2'b00;
            rdata_reg  <= {DW{1'b0}};
        end else begin
            // Write response
            if (state == ACCESS && pready && is_write) begin
                bvalid_reg <= 1'b1;
                bresp_reg <= pslverr ? 2'b10 : 2'b00; // SLVERR -> SLVERR, else OKAY
            end else if (s_bready && bvalid_reg) begin
                bvalid_reg <= 1'b0;
            end

            // Read response
            if (state == ACCESS && pready && !is_write) begin
                rvalid_reg <= 1'b1;
                rdata_reg <= prdata;
                rresp_reg <= pslverr ? 2'b10 : 2'b00;
            end else if (s_rready && rvalid_reg) begin
                rvalid_reg <= 1'b0;
            end
        end
    end

    assign s_bvalid = bvalid_reg;
    assign s_bresp  = bresp_reg;
    
    assign s_rvalid = rvalid_reg;
    assign s_rdata  = rdata_reg;
    assign s_rresp  = rresp_reg;

    // APB Signals
    assign psel    = (state == SETUP || state == ACCESS);
    assign penable = (state == ACCESS);
    assign pwrite  = is_write;
    assign paddr   = addr_reg;
    assign pwdata  = wdata_reg;
    assign pstrb   = wstrb_reg;

endmodule
