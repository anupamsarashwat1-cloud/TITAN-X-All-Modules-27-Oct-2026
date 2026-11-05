// SPDX-License-Identifier: Apache-2.0
// TITAN-X SoC — AXI Read-Only Boot ROM with Hardware Root-of-Trust Coupling
// NIST FIPS compliant boot container authentication & execution gating.
`timescale 1ns/1ps

module axi_rom #(
    parameter HEX_FILE       = "",
    parameter DEPTH          = 1024,
    parameter AW             = 40,
    parameter DW             = 64,
    parameter IDW            = 4,
    parameter PAYLOAD_OFFSET = 43 // 32-bit words offset to verified executable code
) (
    input  wire              clk,
    input  wire              rst_n,

    // Hardware Root-of-Trust Coupling
    input  wire              boot_pass,

    // Pre-Boot Direct Authentication Port (routed exclusively to secure_boot)
    input  wire              rom_preboot_en,
    input  wire [16:0]       rom_preboot_addr, // 32-bit word address
    output wire [31:0]       rom_preboot_rdata,
    output wire              rom_preboot_valid,

    // AXI4 Read-Only Slave Interface (active only when boot_pass == 1)
    input  wire              s_arvalid,
    output reg               s_arready,
    input  wire [AW-1:0]     s_araddr,
    input  wire [IDW-1:0]    s_arid,
    output reg               s_rvalid,
    input  wire              s_rready,
    output reg  [DW-1:0]     s_rdata,
    output wire [1:0]        s_rresp,
    output reg               s_rlast,
    output reg  [IDW-1:0]    s_rid
);

    reg [DW-1:0] rom [0:DEPTH-1];
    integer i;
    reg [8*256-1:0] hexfile_arg;

    // Helper function to extract 32-bit words
    function [31:0] get_word;
        input [16:0] w_addr;
        begin
            get_word = w_addr[0] ? rom[(w_addr[16:1]) & (DEPTH-1)][63:32] :
                                   rom[(w_addr[16:1]) & (DEPTH-1)][31:0];
        end
    endfunction

    // Pre-boot read port for secure_boot
    wire [DW-1:0] preboot_entry = rom[(rom_preboot_addr[16:1]) & (DEPTH-1)];
    assign rom_preboot_rdata = rom_preboot_addr[0] ? preboot_entry[63:32] : preboot_entry[31:0];
    assign rom_preboot_valid = rom_preboot_en;

    initial begin
`ifndef SYNTHESIS
        // 1. Initialize entire ROM with NOP sled
        for (i = 0; i < DEPTH; i = i + 1)
            rom[i] = 64'h0000_0013_0000_0013; // NOP NOP
`endif

        // 2. Default Authentic Root-of-Trust Boot Container (Slot 0 signed 16-word payload)
        // Word 0..42: Secure Boot Header
        rom[ 0] = {32'h00000010, 32'h5449544E}; // [1]=img_len 16, [0]=Magic "TITN"
        rom[ 1] = {32'h47FC49DF, 32'hCAFEF00D}; // [3]=SHA[0], [2]=Key ID
        rom[ 2] = {32'h63CB70B5, 32'hC7A5A9F5}; // [5]=SHA[2], [4]=SHA[1]
        rom[ 3] = {32'h1DEF80B1, 32'h621E4D55}; // [7]=SHA[4], [6]=SHA[3]
        rom[ 4] = {32'h6E3DB762, 32'h65B0438A}; // [9]=SHA[6], [8]=SHA[5]
        rom[ 5] = {32'h26F4FA43, 32'h6560B2D1}; // [11]=Qx[0], [10]=SHA[7]
        rom[ 6] = {32'h46D953CA, 32'h1A2BEB66}; // [13]=Qx[2], [12]=Qx[1]
        rom[ 7] = {32'h911D9B05, 32'h332BC722}; // [15]=Qx[4], [14]=Qx[3]
        rom[ 8] = {32'h06330B61, 32'hE5D92476}; // [17]=Qx[6], [16]=Qx[5]
        rom[ 9] = {32'h9E9689C9, 32'hE6703F52}; // [19]=Qy[0], [18]=Qx[7]
        rom[10] = {32'h342F6CAC, 32'h49B37A0B}; // [21]=Qy[2], [20]=Qy[1]
        rom[11] = {32'hA727CEE4, 32'h9B4E5440}; // [23]=Qy[4], [22]=Qy[3]
        rom[12] = {32'hA6216084, 32'h055285CD}; // [25]=Qy[6], [24]=Qy[5]
        rom[13] = {32'hE3077595, 32'h643D6E4F}; // [27]=r[0],   [26]=Qy[7]
        rom[14] = {32'h401DA7B8, 32'hEB490AA5}; // [29]=r[2],   [28]=r[1]
        rom[15] = {32'h12268AD2, 32'h8B62216E}; // [31]=r[4],   [30]=r[3]
        rom[16] = {32'h46ABAA46, 32'hBF84F2C2}; // [33]=r[6],   [32]=r[5]
        rom[17] = {32'h78D3D87A, 32'hBB725C5E}; // [35]=s[0],   [34]=r[7]
        rom[18] = {32'h5812414C, 32'hE71E31D6}; // [37]=s[2],   [36]=s[1]
        rom[19] = {32'h16DBBD28, 32'h7E90196A}; // [39]=s[4],   [38]=s[3]
        rom[20] = {32'hBA6D21BC, 32'hEC6DF9FD}; // [41]=s[6],   [40]=s[5]
        rom[21] = {32'h10000000, 32'h1F31B431}; // [43]=Payload[0], [42]=s[7]
        // Word 43..58: Signed 16-word payload
        rom[22] = {32'h10000008, 32'h10000004}; // [45]=Payload[2], [44]=Payload[1]
        rom[23] = {32'h10000010, 32'h1000000C}; // [47]=Payload[4], [46]=Payload[3]
        rom[24] = {32'h10000018, 32'h10000014}; // [49]=Payload[6], [48]=Payload[5]
        rom[25] = {32'h10000020, 32'h1000001C}; // [51]=Payload[8], [50]=Payload[7]
        rom[26] = {32'h10000028, 32'h10000024}; // [53]=Payload[10], [52]=Payload[9]
        rom[27] = {32'h10000030, 32'h1000002C}; // [55]=Payload[12], [54]=Payload[11]
        rom[28] = {32'h10000038, 32'h10000034}; // [57]=Payload[14], [56]=Payload[13]
        rom[29] = {32'h00000013, 32'h1000003C}; // [59]=NOP, [58]=Payload[15]

        // 3. Load runtime hex file if specified
        // synopsys translate_off
        if ($value$plusargs("hex=%s", hexfile_arg))
            $readmemh(hexfile_arg, rom);
        else if (HEX_FILE != "")
            $readmemh(HEX_FILE, rom);
        // synopsys translate_on
    end

    assign s_rresp = 2'b00; // OKAY

    // CPU word address translation: maps CPU fetch address to payload
    wire [16:0] cpu_base_word = (s_araddr[AW-1:2] & (DEPTH*2-1)) + PAYLOAD_OFFSET;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_arready <= 1'b0; // Locked until boot_pass asserts
            s_rvalid  <= 1'b0;
            s_rlast   <= 1'b0;
            s_rdata   <= {DW{1'b0}};
            s_rid     <= {IDW{1'b0}};
        end else begin
            if (!boot_pass) begin
                // Lock AXI interface while secure_boot is verifying
                s_arready <= 1'b0;
                s_rvalid  <= 1'b0;
                s_rlast   <= 1'b0;
            end else begin
                // Normal AXI Read processing once boot_pass is asserted
                if (s_arvalid && s_arready) begin
                    s_arready <= 1'b0;
                    s_rvalid  <= 1'b1;
                    s_rlast   <= 1'b1;
                    s_rdata   <= {get_word(cpu_base_word + 17'd1), get_word(cpu_base_word)};
                    s_rid     <= s_arid;
                end else if (s_rvalid && s_rready) begin
                    s_rvalid  <= 1'b0;
                    s_rlast   <= 1'b0;
                    s_arready <= 1'b1;
                end else if (!s_rvalid) begin
                    s_arready <= 1'b1;
                end
            end
        end
    end

endmodule
