// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — OTP eFuse Controller Model (Hardware Trust Anchor)
// Manages 4 Root-of-Trust Public Key slots, key revocation fuses, and monotonic anti-rollback counter.
`timescale 1ns/1ps

module efuse_ctrl #(
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32
) (
    input  wire                      clk,
    input  wire                      rst_n,

    // APB Slave Interface (Telemetry, Programming, Diagnostics)
    input  wire [APB_ADDR_WIDTH-1:0] paddr,
    input  wire                      psel,
    input  wire                      penable,
    input  wire                      pwrite,
    input  wire [APB_DATA_WIDTH-1:0] pwdata,
    output reg  [APB_DATA_WIDTH-1:0] prdata,
    output wire                      pready,
    output wire                      pslverr,

    // Dedicated Direct Interface to Secure Boot Engine
    input  wire [1:0]                hw_slot_idx,
    output wire [255:0]              hw_rot_qx,
    output wire [255:0]              hw_rot_qy,
    output wire                      hw_slot_revoked,
    output wire [3:0]                hw_revocation_mask,
    output wire [31:0]               hw_security_counter,
    input  wire [31:0]               hw_update_counter_val,
    input  wire                      hw_update_counter_en
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    // -------------------------------------------------------
    // Root Public Key Slots (Provisioned at Silicon Manufacture)
    // -------------------------------------------------------
    // Slot 0: Primary Production Root Key (NIST P-256)
    localparam [255:0] ROT_PUBKEY_QX_0 = 256'h26F4FA43_1A2BEB66_46D953CA_332BC722_911D9B05_E5D92476_06330B61_E6703F52;
    localparam [255:0] ROT_PUBKEY_QY_0 = 256'h9E9689C9_49B37A0B_342F6CAC_9B4E5440_A727CEE4_055285CD_A6216084_643D6E4F;

    // Slot 1: Secondary Root Key
    localparam [255:0] ROT_PUBKEY_QX_1 = 256'h5A86B737_E13F9826_1A2BEB66_46D953CA_332BC722_911D9B05_E5D92476_06330B61;
    localparam [255:0] ROT_PUBKEY_QY_1 = 256'h67332611_794461E8_49B37A0B_342F6CAC_9B4E5440_A727CEE4_055285CD_A6216084;

    // Slot 2: Engineering / Backup Root Key
    localparam [255:0] ROT_PUBKEY_QX_2 = 256'h11223344_55667788_99AABBCC_DDEEFF00_01234567_89ABCDEF_FEDCBA98_76543210;
    localparam [255:0] ROT_PUBKEY_QY_2 = 256'h88776655_44332211_00FFEEDD_CCBBAA99_76543210_FEDCBA98_01234567_89ABCDEF;

    // Slot 3: Emergency Recovery Root Key
    localparam [255:0] ROT_PUBKEY_QX_3 = 256'hFEDCBA98_76543210_01234567_89ABCDEF_11223344_55667788_99AABBCC_DDEEFF00;
    localparam [255:0] ROT_PUBKEY_QY_3 = 256'h00FFEEDD_CCBBAA99_88776655_44332211_FEDCBA98_76543210_01234567_89ABCDEF;

    // -------------------------------------------------------
    // Non-Volatile OTP Registers (eFuse Behavioral Emulation)
    // -------------------------------------------------------
    reg [3:0]  revocation_fuses;   // 1 bit per slot: 1=REVOKED, 0=VALID
    reg [31:0] monotonic_counter;  // Monotonic security version counter

    assign hw_revocation_mask  = revocation_fuses;
    assign hw_slot_revoked     = revocation_fuses[hw_slot_idx];
    assign hw_security_counter = monotonic_counter;

    // Slot MUX for Secure Boot
    reg [255:0] qx_mux, qy_mux;
    always @(*) begin
        case (hw_slot_idx)
            2'd0: begin qx_mux = ROT_PUBKEY_QX_0; qy_mux = ROT_PUBKEY_QY_0; end
            2'd1: begin qx_mux = ROT_PUBKEY_QX_1; qy_mux = ROT_PUBKEY_QY_1; end
            2'd2: begin qx_mux = ROT_PUBKEY_QX_2; qy_mux = ROT_PUBKEY_QY_2; end
            2'd3: begin qx_mux = ROT_PUBKEY_QX_3; qy_mux = ROT_PUBKEY_QY_3; end
        endcase
    end

    assign hw_rot_qx = qx_mux;
    assign hw_rot_qy = qy_mux;

    initial begin
        revocation_fuses  = 4'b0000;
        monotonic_counter = 32'd0;
    end

    // -------------------------------------------------------
    // Register Updates: Monotonicity & One-Way OTP Fuses (Non-Volatile)
    // -------------------------------------------------------
    always @(posedge clk) begin
        // Hardware Secure Boot updates take highest priority
        if (hw_update_counter_en) begin
            if (hw_update_counter_val > monotonic_counter)
                monotonic_counter <= hw_update_counter_val;
        end

        // APB Programming
        if (psel && penable && pwrite) begin
                case (paddr[7:0])
                    8'h04: begin // Monotonic Counter Write (Only increases, anti-rollback)
                        if (pwdata > monotonic_counter)
                            monotonic_counter <= pwdata;
                    end
                    8'h08: begin // Revocation Fuse Write (OTP OR logic: once 1, never 0)
                        revocation_fuses <= revocation_fuses | pwdata[3:0];
                    end
                    default: ;
                endcase
            end
        end

    // -------------------------------------------------------
    // APB Read Telemetry
    // -------------------------------------------------------
    always @(*) begin
        case (paddr[7:0])
            8'h00: prdata = {24'h0, 4'h0, revocation_fuses};
            8'h04: prdata = monotonic_counter;
            8'h08: prdata = {28'h0, revocation_fuses};
            8'h0C: prdata = {30'h0, hw_slot_idx};
            default: prdata = 32'h0;
        endcase
    end

endmodule
