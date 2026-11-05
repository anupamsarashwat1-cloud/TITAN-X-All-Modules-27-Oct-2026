// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Genuine Hardware ECDSA P-256 Verification Engine
// NIST FIPS 186-4 compliant Elliptic Curve Digital Signature Algorithm.
// Synthesizable multicycle architecture using iterative 256-cycle modular multiplier
// and sequential Jacobian point doubling / point addition scheduling.
`timescale 1ns/1ps

module mont_mul_256 #(
    parameter FAST_SIM = 0
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [255:0] a,
    input  wire [255:0] b,
    input  wire [255:0] m,
    output reg  [255:0] res,
    output reg          done,
    output reg          busy
);
    reg [255:0] a_reg;
    reg [255:0] b_reg;
    reg [255:0] m_reg;
    reg [257:0] acc;
    reg [8:0]   cnt;

    wire [257:0] T = {acc[256:0], 1'b0} + (a_reg[255] ? {2'b00, b_reg} : 258'd0);
    wire [257:0] sub2 = T - {m_reg, 1'b0};
    wire [257:0] sub1 = T - {2'b00, m_reg};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc   <= 258'd0;
            cnt   <= 9'd0;
            busy  <= 1'b0;
            done  <= 1'b0;
            res   <= 256'd0;
            a_reg <= 256'd0;
            b_reg <= 256'd0;
            m_reg <= 256'd0;
        end else if (start && !busy) begin
            if (FAST_SIM) begin
                res   <= ((512'd0 + a) * (512'd0 + b)) % (512'd0 + m);
                busy  <= 1'b0;
                done  <= 1'b1;
            end else begin
                acc   <= 258'd0;
                a_reg <= a;
                b_reg <= b;
                m_reg <= m;
                cnt   <= 9'd256;
                busy  <= 1'b1;
                done  <= 1'b0;
            end
        end else if (busy) begin
            if (cnt > 9'd0) begin
                cnt   <= cnt - 9'd1;
                a_reg <= {a_reg[254:0], 1'b0};
                if (!sub2[257]) begin
                    acc <= sub2;
                end else if (!sub1[257]) begin
                    acc <= sub1;
                end else begin
                    acc <= T;
                end
            end else begin
                busy <= 1'b0;
                done <= 1'b1;
                res  <= acc[255:0];
            end
        end else begin
            done <= 1'b0;
        end
    end
endmodule

module ecdsa_engine #(
    parameter FAST_SIM = 0
) (
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

    function [255:0] mod_sub_n;
        input [255:0] x, y;
        begin
            if (x >= y) mod_sub_n = x - y;
            else mod_sub_n = x + N_256 - y;
        end
    endfunction

    // -------------------------------------------------------
    // Multicycle Modular Multiplier Instance
    // -------------------------------------------------------
    reg          mul_start;
    reg  [255:0] mul_a;
    reg  [255:0] mul_b;
    reg  [255:0] mul_m;
    wire [255:0] mul_res;
    wire         mul_done;
    wire         mul_busy;

    mont_mul_256 #(
        .FAST_SIM(FAST_SIM)
    ) u_mont_mul (
        .clk   (clk),
        .rst_n (rst_n),
        .start (mul_start),
        .a     (mul_a),
        .b     (mul_b),
        .m     (mul_m),
        .res   (mul_res),
        .done  (mul_done),
        .busy  (mul_busy)
    );

    // -------------------------------------------------------
    // Execution FSM States
    // -------------------------------------------------------
    localparam S_IDLE              = 6'd0;
    localparam S_VALIDATE_CHECK    = 6'd1;
    localparam S_VAL_QY2           = 6'd2;
    localparam S_VAL_QX2           = 6'd3;
    localparam S_VAL_QX3           = 6'd4;
    localparam S_VAL_COMPARE       = 6'd5;
    localparam S_INV_S_LOOP        = 6'd6;
    localparam S_CALC_U1           = 6'd7;
    localparam S_CALC_U2           = 6'd8;
    localparam S_STRAUS_LOOP       = 6'd9;
    localparam S_DBL_START         = 6'd10;
    localparam S_DBL_1             = 6'd11;
    localparam S_DBL_2             = 6'd12;
    localparam S_DBL_3             = 6'd13;
    localparam S_DBL_4             = 6'd14;
    localparam S_DBL_5             = 6'd15;
    localparam S_DBL_6             = 6'd16;
    localparam S_DBL_7             = 6'd17;
    localparam S_DBL_8             = 6'd18;
    localparam S_DBL_9             = 6'd19;
    localparam S_STRAUS_CHECK_ADD  = 6'd20;
    localparam S_ADD_START         = 6'd21;
    localparam S_ADD_1             = 6'd22;
    localparam S_ADD_2             = 6'd23;
    localparam S_ADD_3             = 6'd24;
    localparam S_ADD_4             = 6'd25;
    localparam S_ADD_5             = 6'd26;
    localparam S_ADD_6             = 6'd27;
    localparam S_ADD_7             = 6'd28;
    localparam S_ADD_8             = 6'd29;
    localparam S_ADD_9             = 6'd30;
    localparam S_ADD_10            = 6'd31;
    localparam S_ADD_11            = 6'd32;
    localparam S_INV_Z2_START      = 6'd33;
    localparam S_INV_Z2_WAIT_MUL   = 6'd34;
    localparam S_INV_Z2_EEA        = 6'd35;
    localparam S_CALC_AFF_X        = 6'd36;
    localparam S_VERIFY            = 6'd37;
    localparam S_DONE              = 6'd38;

    reg [5:0] state;

    // Data and working registers
    reg [255:0] e_val, qx_val, qy_val, r_val, s_val;
    reg [255:0] u1_val, u2_val;
    reg [255:0] rx_reg, ry_reg, rz_reg;
    reg [255:0] aff_x, aff_y;
    reg [8:0]   straus_idx;
    reg         add_second;

    // Working intermediate variables
    reg [255:0] qy2_val;
    reg [255:0] a_val, b_val, c_val, d_val, delta_val, e_val_reg, t_reg;
    reg [255:0] z1sq_val, u2_reg, h_val, r_diff, hsq_val, hcu_val, u1hsq_val;
    reg [255:0] w_val;

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
            aff_y       <= 256'h0;
            straus_idx  <= 9'h0;
            add_second  <= 1'b0;
            qy2_val     <= 256'h0;
            a_val       <= 256'h0;
            b_val       <= 256'h0;
            c_val       <= 256'h0;
            d_val       <= 256'h0;
            delta_val   <= 256'h0;
            e_val_reg   <= 256'h0;
            t_reg       <= 256'h0;
            z1sq_val    <= 256'h0;
            u2_reg      <= 256'h0;
            h_val       <= 256'h0;
            r_diff      <= 256'h0;
            hsq_val     <= 256'h0;
            hcu_val     <= 256'h0;
            u1hsq_val   <= 256'h0;
            w_val       <= 256'h0;
            u_eea       <= 256'h0;
            v_eea       <= 256'h0;
            x1_eea      <= 257'h0;
            x2_eea      <= 257'h0;
            mul_start   <= 1'b0;
            mul_a       <= 256'h0;
            mul_b       <= 256'h0;
            mul_m       <= 256'h0;
        end else begin
            mul_start <= 1'b0; // default pulse

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
                        state  <= S_VALIDATE_CHECK;
                    end
                end

                S_VALIDATE_CHECK: begin
                    // Range checks
                    if (r_val == 256'h0 || r_val >= N_256 || s_val == 256'h0 || s_val >= N_256 ||
                        qx_val == 256'h0 || qx_val >= P_256 || qy_val == 256'h0 || qy_val >= P_256) begin
                        stat_reg[2] <= 1'b0; // Reject
                        state       <= S_DONE;
                    end else begin
                        // Start Qy^2 mod P
                        mul_a     <= qy_val;
                        mul_b     <= qy_val;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_VAL_QY2;
                    end
                end

                S_VAL_QY2: begin
                    if (mul_done) begin
                        qy2_val   <= mul_res;
                        // Start Qx^2 mod P
                        mul_a     <= qx_val;
                        mul_b     <= qx_val;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_VAL_QX2;
                    end
                end

                S_VAL_QX2: begin
                    if (mul_done) begin
                        // Start Qx^3 = Qx * Qx^2 mod P
                        mul_a     <= qx_val;
                        mul_b     <= mul_res;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_VAL_QX3;
                    end
                end

                S_VAL_QX3: begin
                    if (mul_done) begin
                        // rhs = Qx^3 - 3*Qx + B mod P
                        begin : check_curve
                            reg [255:0] qx_times_3;
                            reg [255:0] rhs;
                            qx_times_3 = mod_add_p(mod_add_p(qx_val, qx_val), qx_val);
                            rhs = mod_add_p(mod_sub_p(mul_res, qx_times_3), B_256);
                            if (qy2_val != rhs) begin
                                stat_reg[2] <= 1'b0; // Reject off-curve point
                                state       <= S_DONE;
                            end else begin
                                // Initialize EEA for w = s^-1 mod n
                                u_eea  <= s_val;
                                v_eea  <= N_256;
                                x1_eea <= 257'd1;
                                x2_eea <= 257'd0;
                                state  <= S_INV_S_LOOP;
                            end
                        end
                    end
                end

                S_INV_S_LOOP: begin
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
                        w_val     <= (u_eea == 1) ? x1_eea[255:0] : x2_eea[255:0];
                        mul_a     <= e_val;
                        mul_b     <= (u_eea == 1) ? x1_eea[255:0] : x2_eea[255:0];
                        mul_m     <= N_256;
                        mul_start <= 1'b1;
                        state     <= S_CALC_U1;
                    end
                end

                S_CALC_U1: begin
                    if (mul_done) begin
                        u1_val    <= mul_res;
                        mul_a     <= r_val;
                        mul_b     <= w_val;
                        mul_m     <= N_256;
                        mul_start <= 1'b1;
                        state     <= S_CALC_U2;
                    end
                end

                S_CALC_U2: begin
                    if (mul_done) begin
                        u2_val     <= mul_res;
                        straus_idx <= 9'd256;
                        rx_reg     <= 256'd0;
                        ry_reg     <= 256'd0;
                        rz_reg     <= 256'd0;
                        state      <= S_STRAUS_LOOP;
                    end
                end

                S_STRAUS_LOOP: begin
                    if (straus_idx > 9'd0) begin
                        straus_idx <= straus_idx - 9'd1;
                        if (rz_reg == 256'd0) begin
                            // Point is at infinity, skip doubling!
                            state <= S_STRAUS_CHECK_ADD;
                        end else begin
                            // Start Jacobian Doubling: a = rx^2 mod P
                            mul_a     <= rx_reg;
                            mul_b     <= rx_reg;
                            mul_m     <= P_256;
                            mul_start <= 1'b1;
                            state     <= S_DBL_1;
                        end
                    end else begin
                        if (rz_reg == 256'd0) begin
                            stat_reg[2] <= 1'b0; // Point at infinity -> Reject
                            state       <= S_DONE;
                        end else begin
                            // Start Inverting Rz^2 mod P: first mul rz^2
                            mul_a     <= rz_reg;
                            mul_b     <= rz_reg;
                            mul_m     <= P_256;
                            mul_start <= 1'b1;
                            state     <= S_INV_Z2_WAIT_MUL;
                        end
                    end
                end

                // ---------------------------------------------------
                // Jacobian Doubling Multicycle Sequence (9 muls)
                // ---------------------------------------------------
                S_DBL_1: begin // a = rx^2
                    if (mul_done) begin
                        a_val     <= mul_res;
                        mul_a     <= ry_reg;
                        mul_b     <= ry_reg;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_DBL_2;
                    end
                end

                S_DBL_2: begin // b = ry^2
                    if (mul_done) begin
                        b_val     <= mul_res;
                        mul_a     <= mul_res;
                        mul_b     <= mul_res;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_DBL_3;
                    end
                end

                S_DBL_3: begin // c = b^2
                    if (mul_done) begin
                        c_val     <= mul_res;
                        t_reg     <= mod_add_p(rx_reg, b_val);
                        mul_a     <= mod_add_p(rx_reg, b_val);
                        mul_b     <= mod_add_p(rx_reg, b_val);
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_DBL_4;
                    end
                end

                S_DBL_4: begin // (rx + b)^2
                    if (mul_done) begin
                        begin : calc_d
                            reg [255:0] diff;
                            diff  = mod_sub_p(mod_sub_p(mul_res, a_val), c_val);
                            d_val <= mod_add_p(diff, diff); // d = 2 * diff
                        end
                        mul_a     <= rz_reg;
                        mul_b     <= rz_reg;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_DBL_5;
                    end
                end

                S_DBL_5: begin // delta = rz^2
                    if (mul_done) begin
                        delta_val <= mul_res;
                        mul_a     <= mod_sub_p(rx_reg, mul_res);
                        mul_b     <= mod_add_p(rx_reg, mul_res);
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_DBL_6;
                    end
                end

                S_DBL_6: begin // (rx - delta) * (rx + delta)
                    if (mul_done) begin
                        e_val_reg <= mod_add_p(mod_add_p(mul_res, mul_res), mul_res); // 3 * mul_res
                        mul_a     <= mod_add_p(mod_add_p(mul_res, mul_res), mul_res);
                        mul_b     <= mod_add_p(mod_add_p(mul_res, mul_res), mul_res);
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_DBL_7;
                    end
                end

                S_DBL_7: begin // e^2
                    if (mul_done) begin
                        begin : calc_x3
                            reg [255:0] nx;
                            nx     = mod_sub_p(mul_res, mod_add_p(d_val, d_val)); // x3 = e^2 - 2*d
                            rx_reg <= nx;
                            mul_a  <= e_val_reg;
                            mul_b  <= mod_sub_p(d_val, nx); // e * (d - x3)
                        end
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_DBL_8;
                    end
                end

                S_DBL_8: begin // e * (d - x3)
                    if (mul_done) begin
                        begin : calc_y3
                            reg [255:0] c2, c4, c8;
                            c2 = mod_add_p(c_val, c_val);
                            c4 = mod_add_p(c2, c2);
                            c8 = mod_add_p(c4, c4);
                            ry_reg <= mod_sub_p(mul_res, c8); // y3 = e*(d - x3) - 8*c
                        end
                        mul_a     <= ry_reg;
                        mul_b     <= rz_reg;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_DBL_9;
                    end
                end

                S_DBL_9: begin // ry * rz
                    if (mul_done) begin
                        rz_reg <= mod_add_p(mul_res, mul_res); // z3 = 2 * (ry * rz)
                        state  <= S_STRAUS_CHECK_ADD;
                    end
                end

                // ---------------------------------------------------
                // Straus Check Add
                // ---------------------------------------------------
                S_STRAUS_CHECK_ADD: begin
                    begin : check_bits
                        reg b1, b2;
                        b1 = u1_val[straus_idx];
                        b2 = u2_val[straus_idx];
                        if (b1 == 1'b1 && b2 == 1'b0) begin
                            aff_x      <= GX;
                            aff_y      <= GY;
                            add_second <= 1'b0;
                            state      <= S_ADD_START;
                        end else if (b1 == 1'b0 && b2 == 1'b1) begin
                            aff_x      <= qx_val;
                            aff_y      <= qy_val;
                            add_second <= 1'b0;
                            state      <= S_ADD_START;
                        end else if (b1 == 1'b1 && b2 == 1'b1) begin
                            aff_x      <= GX;
                            aff_y      <= GY;
                            add_second <= 1'b1; // Add Q after G
                            state      <= S_ADD_START;
                        end else begin
                            state <= S_STRAUS_LOOP;
                        end
                    end
                end

                // ---------------------------------------------------
                // Jacobian-Affine Addition Multicycle Sequence (11 muls)
                // ---------------------------------------------------
                S_ADD_START: begin
                    if (rz_reg == 256'd0) begin
                        // Point at infinity + Affine = Affine
                        rx_reg <= aff_x;
                        ry_reg <= aff_y;
                        rz_reg <= 256'd1;
                        if (add_second) begin
                            add_second <= 1'b0;
                            aff_x      <= qx_val;
                            aff_y      <= qy_val;
                            state      <= S_ADD_START;
                        end else begin
                            state <= S_STRAUS_LOOP;
                        end
                    end else begin
                        // z1sq = rz^2
                        mul_a     <= rz_reg;
                        mul_b     <= rz_reg;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_1;
                    end
                end

                S_ADD_1: begin // z1sq
                    if (mul_done) begin
                        z1sq_val  <= mul_res;
                        mul_a     <= aff_x;
                        mul_b     <= mul_res;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_2;
                    end
                end

                S_ADD_2: begin // u2 = aff_x * z1sq
                    if (mul_done) begin
                        u2_reg    <= mul_res;
                        mul_a     <= rz_reg;
                        mul_b     <= z1sq_val;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_3;
                    end
                end

                S_ADD_3: begin // z1cu = rz * z1sq
                    if (mul_done) begin
                        mul_a     <= aff_y;
                        mul_b     <= mul_res;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_4;
                    end
                end

                S_ADD_4: begin // s2 = aff_y * z1cu
                    if (mul_done) begin
                        begin : check_h_r
                            reg [255:0] h, r;
                            h = mod_sub_p(u2_reg, rx_reg);
                            r = mod_sub_p(mul_res, ry_reg);
                            h_val  <= h;
                            r_diff <= r;
                            if (h == 256'd0) begin
                                if (r == 256'd0) begin
                                    state <= S_DBL_START;
                                end else begin
                                    rx_reg <= 256'd0;
                                    ry_reg <= 256'd0;
                                    rz_reg <= 256'd0;
                                    if (add_second) begin
                                        add_second <= 1'b0;
                                        aff_x      <= qx_val;
                                        aff_y      <= qy_val;
                                        state      <= S_ADD_START;
                                    end else begin
                                        state <= S_STRAUS_LOOP;
                                    end
                                end
                            end else begin
                                mul_a     <= h;
                                mul_b     <= h;
                                mul_m     <= P_256;
                                mul_start <= 1'b1;
                                state     <= S_ADD_5;
                            end
                        end
                    end
                end

                S_ADD_5: begin // hsq = h^2
                    if (mul_done) begin
                        hsq_val   <= mul_res;
                        mul_a     <= h_val;
                        mul_b     <= mul_res;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_6;
                    end
                end

                S_ADD_6: begin // hcu = h * hsq
                    if (mul_done) begin
                        hcu_val   <= mul_res;
                        mul_a     <= rx_reg;
                        mul_b     <= hsq_val;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_7;
                    end
                end

                S_ADD_7: begin // u1hsq = rx * hsq
                    if (mul_done) begin
                        u1hsq_val <= mul_res;
                        mul_a     <= r_diff;
                        mul_b     <= r_diff;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_8;
                    end
                end

                S_ADD_8: begin // rsq = r_diff^2
                    if (mul_done) begin
                        begin : calc_add_x3
                            reg [255:0] nx;
                            nx     = mod_sub_p(mod_sub_p(mul_res, hcu_val), mod_add_p(u1hsq_val, u1hsq_val));
                            rx_reg <= nx;
                            mul_a  <= r_diff;
                            mul_b  <= mod_sub_p(u1hsq_val, nx);
                        end
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_9;
                    end
                end

                S_ADD_9: begin // r_diff * (u1hsq - nx)
                    if (mul_done) begin
                        t_reg     <= mul_res;
                        mul_a     <= ry_reg;
                        mul_b     <= hcu_val;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_10;
                    end
                end

                S_ADD_10: begin // ry * hcu
                    if (mul_done) begin
                        ry_reg    <= mod_sub_p(t_reg, mul_res);
                        mul_a     <= rz_reg;
                        mul_b     <= h_val;
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_ADD_11;
                    end
                end

                S_ADD_11: begin // z3 = rz * h
                    if (mul_done) begin
                        rz_reg <= mul_res;
                        if (add_second) begin
                            add_second <= 1'b0;
                            aff_x      <= qx_val;
                            aff_y      <= qy_val;
                            state      <= S_ADD_START;
                        end else begin
                            state <= S_STRAUS_LOOP;
                        end
                    end
                end

                // ---------------------------------------------------
                // Invert Z^2 mod P via EEA
                // ---------------------------------------------------
                S_INV_Z2_WAIT_MUL: begin
                    if (mul_done) begin
                        u_eea  <= mul_res;
                        v_eea  <= P_256;
                        x1_eea <= 257'd1;
                        x2_eea <= 257'd0;
                        state  <= S_INV_Z2_EEA;
                    end
                end

                S_INV_Z2_EEA: begin
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
                        mul_a     <= rx_reg;
                        mul_b     <= (u_eea == 1) ? x1_eea[255:0] : x2_eea[255:0];
                        mul_m     <= P_256;
                        mul_start <= 1'b1;
                        state     <= S_CALC_AFF_X;
                    end
                end

                S_CALC_AFF_X: begin
                    if (mul_done) begin
                        aff_x <= mul_res;
                        state <= S_VERIFY;
                    end
                end

                // ---------------------------------------------------
                // Verification Check: aff_x mod N == r
                // ---------------------------------------------------
                S_VERIFY: begin
                    begin : check_sig
                        reg [255:0] v_val;
                        v_val = (aff_x >= N_256) ? (aff_x - N_256) : aff_x;
                        if (v_val == r_val)
                            stat_reg[2] <= 1'b1; // SUCCESS
                        else
                            stat_reg[2] <= 1'b0; // FAIL
                        state <= S_DONE;
                    end
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
