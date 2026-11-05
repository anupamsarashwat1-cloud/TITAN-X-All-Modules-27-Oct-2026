// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — OTP eFuse Controller Self-Checking Testbench
`timescale 1ns/1ps

module tb_efuse_ctrl();

    reg        clk, rst_n;
    reg [31:0] paddr;
    reg        psel, penable, pwrite;
    reg [31:0] pwdata;
    wire [31:0] prdata;
    wire       pready, pslverr;

    reg  [1:0]   hw_slot_idx;
    wire [255:0] hw_rot_qx, hw_rot_qy;
    wire         hw_slot_revoked;
    wire [3:0]   hw_revocation_mask;
    wire [31:0]  hw_security_counter;
    reg  [31:0]  hw_update_counter_val;
    reg          hw_update_counter_en;

    integer pass_count = 0;
    integer fail_count = 0;

    efuse_ctrl uut (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .hw_slot_idx(hw_slot_idx),
        .hw_rot_qx(hw_rot_qx),
        .hw_rot_qy(hw_rot_qy),
        .hw_slot_revoked(hw_slot_revoked),
        .hw_revocation_mask(hw_revocation_mask),
        .hw_security_counter(hw_security_counter),
        .hw_update_counter_val(hw_update_counter_val),
        .hw_update_counter_en(hw_update_counter_en)
    );

    always #5.0 clk = ~clk;

    task check(input [255:0] test_name, input condition);
        begin
            if (condition) begin
                $display("PASS [%0t] %0s", $time, test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [%0t] %0s", $time, test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            paddr   <= addr;
            pwdata  <= data;
            pwrite  <= 1'b1;
            psel    <= 1'b1;
            penable <= 1'b0;
            @(posedge clk);
            penable <= 1'b1;
            @(posedge clk);
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
        end
    endtask

    task apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            paddr   <= addr;
            pwrite  <= 1'b0;
            psel    <= 1'b1;
            penable <= 1'b0;
            @(posedge clk);
            penable <= 1'b1;
            @(posedge clk);
            data    = prdata;
            psel    <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    reg [31:0] rdata;

    initial begin
        clk = 0;
        rst_n = 0;
        paddr = 0; psel = 0; penable = 0; pwrite = 0; pwdata = 0;
        hw_slot_idx = 2'd0;
        hw_update_counter_val = 0;
        hw_update_counter_en = 0;

        #25;
        rst_n = 1;
        #15;

        // Test 1: Reset state
        check("TEST 1: Reset fuses unblown (0000)", hw_revocation_mask == 4'b0000);
        check("TEST 2: Reset counter is 0", hw_security_counter == 32'd0);

        // Test 2: Public Key Slot 0 Coordinates
        hw_slot_idx = 2'd0; #1;
        check("TEST 3: Slot 0 Qx matches production root key", 
              hw_rot_qx == 256'h26F4FA43_1A2BEB66_46D953CA_332BC722_911D9B05_E5D92476_06330B61_E6703F52);
        check("TEST 4: Slot 0 not revoked", hw_slot_revoked == 1'b0);

        // Test 3: Public Key Slot 1 Coordinates
        hw_slot_idx = 2'd1; #1;
        check("TEST 5: Slot 1 Qx matches secondary root key",
              hw_rot_qx == 256'h5A86B737_E13F9826_1A2BEB66_46D953CA_332BC722_911D9B05_E5D92476_06330B61);

        // Test 4: Blow revocation fuse for Slot 1
        apb_write(32'h08, 32'h0000_0002); // Set bit 1
        #1;
        check("TEST 6: Slot 1 revocation fuse blown", hw_revocation_mask == 4'b0010);
        check("TEST 7: Slot 1 reports revoked", hw_slot_revoked == 1'b1);
        hw_slot_idx = 2'd0; #1;
        check("TEST 8: Slot 0 remains unrevoked", hw_slot_revoked == 1'b0);

        // Test 5: Irreversibility of OTP fuses (attempt to clear bit 1)
        apb_write(32'h08, 32'h0000_0000);
        #1;
        check("TEST 9: OTP fuse bit remains blown after clear attempt", hw_revocation_mask == 4'b0010);

        // Test 6: Monotonic counter increment via APB
        apb_write(32'h04, 32'd5);
        #1;
        check("TEST 10: Counter upgraded to 5", hw_security_counter == 32'd5);

        // Test 7: Anti-rollback downgrade prevention
        apb_write(32'h04, 32'd2); // Attempt downgrade to 2
        #1;
        check("TEST 11: Counter rejected downgrade (remains 5)", hw_security_counter == 32'd5);

        // Test 8: Hardware update from secure boot
        @(posedge clk);
        hw_update_counter_val <= 32'd8;
        hw_update_counter_en  <= 1'b1;
        @(posedge clk);
        hw_update_counter_en  <= 1'b0;
        #1;
        check("TEST 12: Hardware counter upgraded to 8", hw_security_counter == 32'd8);

        #20;
        $display("\n==============================");
        if (fail_count == 0 && pass_count >= 12) begin
            $display("EFUSE_CTRL VERDICT: PASS — All %0d tests green", pass_count);
        end else begin
            $display("EFUSE_CTRL VERDICT: FAIL — %0d failed, %0d passed", fail_count, pass_count);
        end
        $display("==============================\n");
        $finish;
    end

endmodule
