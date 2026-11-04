// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Genuine Hardware ECDSA P-256 Verification Engine
// NIST FIPS 186-4 compliant Elliptic Curve Digital Signature Algorithm.
// Performs real field arithmetic, point doubling/addition, modular inversion,
// scalar multiplication (Shamir/Straus trick), and signature verification.
`timescale 1ns/1ps

module ecdsa_engine (
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave Interface
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Interrupt
    output wire        ecdsa_irq
);

    // -------------------------------------------------------
    // NIST P-256 (secp256r1) Curve Parameters
    // -------------------------------------------------------
    localparam [255:0] P_256 = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam [255:0] N_256 = 256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    localparam [255:0] A_256 = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
    localparam [255:0] B_256 = 256'h5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
    localparam [255:0] GX    = 256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    localparam [255:0] GY    = 256'h4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;

    // -------------------------------------------------------
    // APB Registers & Address Decoding
    // -------------------------------------------------------
    wire [3:0] reg_bank = (paddr[19:16] != 4'h0) ? paddr[19:16] : paddr[11:8];
    wire [4:0] reg_word = paddr[6:2];

    reg [31:0] ctrl_reg; // bit 0 = start, bit 1 = mode (0=P256), bit 2 = op (0=verify)
    reg [31:0] stat_reg; // bit 0 = busy, bit 1 = done, bit 2 = pass/fail

    reg [31:0] hash_ram [0:7];  // e (256-bit message digest)
    reg [31:0] key_ram  [0:15]; // Qx: key_ram[0..7], Qy: key_ram[8..15]
    reg [31:0] r_ram    [0:7];  // Signature r
    reg [31:0] s_ram    [0:7];  // Signature s

    assign pready  = 1'b1;
    assign pslverr = 1'b0;
    assign ecdsa_irq = stat_reg[1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg <= 32'h0;
        end else if (psel && penable && pwrite) begin
            case (reg_bank)
                4'h0: if (paddr[7:0] == 8'h00) ctrl_reg <= pwdata;
                4'h1: hash_ram[reg_word[2:0]] <= pwdata;
                4'h2: key_ram[reg_word[3:0]]  <= pwdata;
                4'h3: r_ram[reg_word[2:0]]    <= pwdata;
                4'h4: s_ram[reg_word[2:0]]    <= pwdata;
            endcase
        end else if (stat_reg[0] && ctrl_reg[0]) begin
            ctrl_reg[0] <= 1'b0; // Auto-clear start
        end
    end

    reg [31:0] prdata_reg;
    always @(*) begin
        case (reg_bank)
            4'h0: begin
                if (paddr[7:0] == 8'h00) prdata_reg = ctrl_reg;
                else if (paddr[7:0] == 8'h04) prdata_reg = stat_reg;
                else prdata_reg = 32'h0;
            end
            4'h1: prdata_reg = hash_ram[reg_word[2:0]];
            4'h2: prdata_reg = key_ram[reg_word[3:0]];
            4'h3: prdata_reg = r_ram[reg_word[2:0]];
            4'h4: prdata_reg = s_ram[reg_word[2:0]];
            default: prdata_reg = 32'h0;
        endcase
    end
    assign prdata = prdata_reg;

    // -------------------------------------------------------
    // Modular Arithmetic Functions
    // -------------------------------------------------------
    function [255:0] mod_add_p;
        input [255:0] x, y;
        reg [256:0] sum;
        begin
            sum = x + y;
            if (sum >= {1'b0, P_256}) mod_add_p = sum - P_256;
            else mod_add_p = sum[255:0];
        end
    endfunction

    function [255:0] mod_sub_p;
        input [255:0] x, y;
        begin
            if (x >= y) mod_sub_p = x - y;
            else mod_sub_p = x + P_256 - y;
        end
    endfunction

    function [255:0] mod_mul_p;
        input [255:0] x, y;
        reg [511:0] prod;
        begin
            prod = x * y;
            mod_mul_p = prod % P_256;
        end
    endfunction

    function [255:0] mod_add_n;
        input [255:0] x, y;
        reg [256:0] sum;
        begin
            sum = x + y;
            if (sum >= {1'b0, N_256}) mod_add_n = sum - N_256;
            else mod_add_n = sum[255:0];
        end
    endfunction

    function [255:0] mod_sub_n;
        input [255:0] x, y;
        begin
            if (x >= y) mod_sub_n = x - y;
            else mod_sub_n = x + N_256 - y;
        end
    endfunction

    function [255:0] mod_mul_n;
        input [255:0] x, y;
        reg [511:0] prod;
        begin
            prod = x * y;
            mod_mul_n = prod % N_256;
        end
    endfunction

    // -------------------------------------------------------
    // Jacobian Point Arithmetic Tasks
    // -------------------------------------------------------
    task automatic jac_double;
        input  [255:0] in_x, in_y, in_z;
        output [255:0] out_x, out_y, out_z;
        reg [255:0] a_val, b_val, c_val, d_val, delta, e_val;
        begin
            if (in_z == 256'h0 || in_y == 256'h0) begin
                out_x = 256'h0; out_y = 256'h0; out_z = 256'h0;
            end else begin
                a_val = mod_mul_p(in_x, in_x);
                b_val = mod_mul_p(in_y, in_y);
                c_val = mod_mul_p(b_val, b_val);
                d_val = mod_mul_p(256'd2, mod_sub_p(mod_mul_p(mod_add_p(in_x, b_val), mod_add_p(in_x, b_val)), mod_add_p(a_val, c_val)));
                delta = mod_mul_p(in_z, in_z);
                e_val = mod_mul_p(256'd3, mod_mul_p(mod_sub_p(in_x, delta), mod_add_p(in_x, delta)));
                out_x = mod_sub_p(mod_mul_p(e_val, e_val), mod_mul_p(256'd2, d_val));
                out_y = mod_sub_p(mod_mul_p(e_val, mod_sub_p(d_val, out_x)), mod_mul_p(256'd8, c_val));
                out_z = mod_mul_p(256'd2, mod_mul_p(in_y, in_z));
            end
        end
    endtask

    task automatic jac_add_aff;
        input  [255:0] in_x, in_y, in_z;
        input  [255:0] aff_x, aff_y;
        output [255:0] out_x, out_y, out_z;
        reg [255:0] z1sq, u2_val, s2_val, h_val, r_val, hsq, hcu, u1hsq;
        begin
            if (in_z == 256'h0) begin
                out_x = aff_x; out_y = aff_y; out_z = 256'd1;
            end else begin
                z1sq   = mod_mul_p(in_z, in_z);
                u2_val = mod_mul_p(aff_x, z1sq);
                s2_val = mod_mul_p(aff_y, mod_mul_p(in_z, z1sq));
                h_val  = mod_sub_p(u2_val, in_x);
                r_val  = mod_sub_p(s2_val, in_y);
                if (h_val == 256'h0) begin
                    if (r_val == 256'h0) begin
                        jac_double(in_x, in_y, in_z, out_x, out_y, out_z);
                    end else begin
                        out_x = 256'h0; out_y = 256'h0; out_z = 256'h0;
                    end
                end else begin
                    hsq   = mod_mul_p(h_val, h_val);
                    hcu   = mod_mul_p(h_val, hsq);
                    u1hsq = mod_mul_p(in_x, hsq);
                    out_x = mod_sub_p(mod_sub_p(mod_mul_p(r_val, r_val), hcu), mod_mul_p(256'd2, u1hsq));
                    out_y = mod_sub_p(mod_mul_p(r_val, mod_sub_p(u1hsq, out_x)), mod_mul_p(in_y, hcu));
                    out_z = mod_mul_p(in_z, h_val);
                end
            end
        end
    endtask

    // -------------------------------------------------------
    // Execution FSM
    // -------------------------------------------------------
    localparam S_IDLE      = 3'd0;
    localparam S_VALIDATE  = 3'd1;
    localparam S_INV_S     = 3'd2;
    localparam S_STRAUS    = 3'd3;
    localparam S_INV_RZ    = 3'd4;
    localparam S_VERIFY    = 3'd5;
    localparam S_DONE      = 3'd6;

    reg [2:0] state;

    reg [255:0] e_val, qx_val, qy_val, r_val, s_val;
    reg [255:0] u1_val, u2_val;
    reg [255:0] rx_reg, ry_reg, rz_reg;
    reg [255:0] aff_x;
    reg [8:0]   straus_idx;

    // Binary EEA working registers
    reg [255:0] u_eea, v_eea;
    reg [256:0] x1_eea, x2_eea;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            stat_reg    <= 32'h0;
            e_val       <= 256'h0;
            qx_val      <= 256'h0;
            qy_val      <= 256'h0;
            r_val       <= 256'h0;
            s_val       <= 256'h0;
            u1_val      <= 256'h0;
            u2_val      <= 256'h0;
            rx_reg      <= 256'h0;
            ry_reg      <= 256'h0;
            rz_reg      <= 256'h0;
            aff_x       <= 256'h0;
            straus_idx  <= 9'h0;
            u_eea       <= 256'h0;
            v_eea       <= 256'h0;
            x1_eea      <= 257'h0;
            x2_eea      <= 257'h0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (ctrl_reg[0] && !stat_reg[0]) begin
                        stat_reg[0] <= 1'b1; // Busy
                        stat_reg[1] <= 1'b0; // Done = 0
                        stat_reg[2] <= 1'b0; // Pass = 0

                        // Assemble 256-bit big-endian integers from RAMs
                        e_val  <= {hash_ram[0], hash_ram[1], hash_ram[2], hash_ram[3], hash_ram[4], hash_ram[5], hash_ram[6], hash_ram[7]};
                        qx_val <= {key_ram[0],  key_ram[1],  key_ram[2],  key_ram[3],  key_ram[4],  key_ram[5],  key_ram[6],  key_ram[7]};
                        qy_val <= {key_ram[8],  key_ram[9],  key_ram[10], key_ram[11], key_ram[12], key_ram[13], key_ram[14], key_ram[15]};
                        r_val  <= {r_ram[0],    r_ram[1],    r_ram[2],    r_ram[3],    r_ram[4],    r_ram[5],    r_ram[6],    r_ram[7]};
                        s_val  <= {s_ram[0],    s_ram[1],    s_ram[2],    s_ram[3],    s_ram[4],    s_ram[5],    s_ram[6],    s_ram[7]};
                        state  <= S_VALIDATE;
                    end
                end

                S_VALIDATE: begin
                    // 1. Signature range check: 1 <= r, s < n
                    // 2. Public key range check: 1 <= Qx, Qy < p
                    // 3. Curve equation check: Qy^2 == Qx^3 + a*Qx + b (mod p)
                    if (r_val == 256'h0 || r_val >= N_256 || s_val == 256'h0 || s_val >= N_256 ||
                        qx_val == 256'h0 || qx_val >= P_256 || qy_val == 256'h0 || qy_val >= P_256 ||
                        mod_mul_p(qy_val, qy_val) != mod_add_p(mod_add_p(mod_mul_p(mod_mul_p(qx_val, qx_val), qx_val), mod_mul_p(A_256, qx_val)), B_256)) begin
                        stat_reg[2] <= 1'b0; // Reject
                        state       <= S_DONE;
                    end else begin
                        // Initialize EEA for w = s^-1 mod n
                        u_eea    <= s_val;
                        v_eea    <= N_256;
                        x1_eea   <= 257'd1;
                        x2_eea   <= 257'd0;
                        state    <= S_INV_S;
                    end
                end

                S_INV_S: begin
                    // Binary EEA loop
                    if (u_eea != 0 && v_eea != 0 && u_eea != 1 && v_eea != 1) begin
                        if (u_eea[0] == 1'b0) begin
                            u_eea <= u_eea >> 1;
                            x1_eea <= x1_eea[0] ? ({1'b0, x1_eea[255:0]} + {1'b0, N_256}) >> 1 : x1_eea >> 1;
                        end else if (v_eea[0] == 1'b0) begin
                            v_eea <= v_eea >> 1;
                            x2_eea <= x2_eea[0] ? ({1'b0, x2_eea[255:0]} + {1'b0, N_256}) >> 1 : x2_eea >> 1;
                        end else if (u_eea >= v_eea) begin
                            u_eea  <= u_eea - v_eea;
                            x1_eea <= {1'b0, mod_sub_n(x1_eea[255:0], x2_eea[255:0])};
                        end else begin
                            v_eea  <= v_eea - u_eea;
                            x2_eea <= {1'b0, mod_sub_n(x2_eea[255:0], x1_eea[255:0])};
                        end
                    end else begin
                        // w = s^-1 mod n is ready
                        begin : calc_u1_u2
                            reg [255:0] w_val;
                            w_val = (u_eea == 1) ? x1_eea[255:0] : x2_eea[255:0];
                            u1_val <= mod_mul_n(e_val, w_val);
                            u2_val <= mod_mul_n(r_val, w_val);
                        end
                        straus_idx <= 9'd256;
                        rx_reg     <= 256'd0;
                        ry_reg     <= 256'd0;
                        rz_reg     <= 256'd0;
                        state      <= S_STRAUS;
                    end
                end

                S_STRAUS: begin
                    if (straus_idx > 0) begin
                        straus_idx <= straus_idx - 9'd1;
                        begin : straus_step
                            reg [255:0] nx, ny, nz;
                            reg [255:0] tx, ty, tz;
                            reg [255:0] res_x, res_y, res_z;
                            reg b1, b2;
                            jac_double(rx_reg, ry_reg, rz_reg, nx, ny, nz);
                            b1 = u1_val[straus_idx - 1];
                            b2 = u2_val[straus_idx - 1];
                            if (b1 == 1'b1 && b2 == 1'b0) begin
                                jac_add_aff(nx, ny, nz, GX, GY, res_x, res_y, res_z);
                            end else if (b1 == 1'b0 && b2 == 1'b1) begin
                                jac_add_aff(nx, ny, nz, qx_val, qy_val, res_x, res_y, res_z);
                            end else if (b1 == 1'b1 && b2 == 1'b1) begin
                                jac_add_aff(nx, ny, nz, GX, GY, tx, ty, tz);
                                jac_add_aff(tx, ty, tz, qx_val, qy_val, res_x, res_y, res_z);
                            end else begin
                                res_x = nx;
                                res_y = ny;
                                res_z = nz;
                            end
                            rx_reg <= res_x;
                            ry_reg <= res_y;
                            rz_reg <= res_z;
                        end
                    end else begin
                        if (rz_reg == 256'd0) begin
                            stat_reg[2] <= 1'b0; // Point at infinity -> Reject
                            state       <= S_DONE;
                        end else begin
                            // Invert rz^2 mod p via EEA
                            u_eea  <= mod_mul_p(rz_reg, rz_reg);
                            v_eea  <= P_256;
                            x1_eea <= 257'd1;
                            x2_eea <= 257'd0;
                            state  <= S_INV_RZ;
                        end
                    end
                end

                S_INV_RZ: begin
                    if (u_eea != 0 && v_eea != 0 && u_eea != 1 && v_eea != 1) begin
                        if (u_eea[0] == 1'b0) begin
                            u_eea <= u_eea >> 1;
                            x1_eea <= x1_eea[0] ? ({1'b0, x1_eea[255:0]} + {1'b0, P_256}) >> 1 : x1_eea >> 1;
                        end else if (v_eea[0] == 1'b0) begin
                            v_eea <= v_eea >> 1;
                            x2_eea <= x2_eea[0] ? ({1'b0, x2_eea[255:0]} + {1'b0, P_256}) >> 1 : x2_eea >> 1;
                        end else if (u_eea >= v_eea) begin
                            u_eea  <= u_eea - v_eea;
                            x1_eea <= {1'b0, mod_sub_p(x1_eea[255:0], x2_eea[255:0])};
                        end else begin
                            v_eea  <= v_eea - u_eea;
                            x2_eea <= {1'b0, mod_sub_p(x2_eea[255:0], x1_eea[255:0])};
                        end
                    end else begin
                        begin : calc_aff_x
                            reg [255:0] inv_z2;
                            inv_z2 = (u_eea == 1) ? x1_eea[255:0] : x2_eea[255:0];
                            aff_x  <= mod_mul_p(rx_reg, inv_z2);
                        end
                        state <= S_VERIFY;
                    end
                end

                S_VERIFY: begin
                    if ((aff_x % N_256) == r_val)
                        stat_reg[2] <= 1'b1; // SUCCESS
                    else
                        stat_reg[2] <= 1'b0; // FAIL
                    state <= S_DONE;
                end

                S_DONE: begin
                    stat_reg[0] <= 1'b0; // Not busy
                    stat_reg[1] <= 1'b1; // Done
                    state       <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
