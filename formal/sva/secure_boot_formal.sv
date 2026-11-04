`timescale 1ns/1ps

module secure_boot_formal (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    output wire [16:0] envm_addr,
    output wire        envm_req,
    input  wire [31:0] envm_rdata,
    input  wire        envm_valid,

    output wire        boot_pass,
    output wire        boot_fail
);

    secure_boot dut (
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
        .envm_addr(envm_addr),
        .envm_req(envm_req),
        .envm_rdata(envm_rdata),
        .envm_valid(envm_valid),
        .boot_pass(boot_pass),
        .boot_fail(boot_fail)
    );

`ifdef FORMAL
    reg [2:0] rst_cnt = 0;
    always @(posedge clk) begin
        if (rst_cnt < 3)
            rst_cnt <= rst_cnt + 1;
    end

    // Standard BMC reset assumption: cycles 0-1 reset asserted, cycle 2+ operational
    always @* begin
        if (rst_cnt < 2)
            assume(!rst_n);
        else
            assume(rst_n);
    end

    // Track latched states
    reg halt_latched = 0;
    reg pass_latched = 0;
    always @(posedge clk) begin
        if (!rst_n) begin
            halt_latched <= 0;
            pass_latched <= 0;
        end else begin
            if (boot_fail)
                halt_latched <= 1;
            if (boot_pass)
                pass_latched <= 1;
        end
    end

    always @(posedge clk) begin
        // Lemma 1: Mutual exclusion of pass and fail
        assert(!(boot_pass && boot_fail));

        // Lemma 2: During active reset, core reset release is strictly forbidden
        if (!rst_n) begin
            assert(boot_pass == 1'b0);
            assert(boot_fail == 1'b0);
        end

        // Lemma 3: Safe latch in HALT state (no unauthorized escape from security halt)
        if (halt_latched && rst_n) begin
            assert(boot_fail == 1'b1);
            assert(boot_pass == 1'b0);
        end

        // Lemma 4: Stable lock in SUCCESS state
        if (pass_latched && rst_n) begin
            assert(boot_pass == 1'b1);
            assert(boot_fail == 1'b0);
        end

        // Lemma 5: APB status telemetric integrity
        if (paddr[7:0] == 8'h00) begin
            if (boot_pass)
                assert(prdata[30] == 1'b1 && prdata[2:0] == 3'd4);
            if (boot_fail)
                assert(prdata[31] == 1'b1 && prdata[2:0] == 3'd5);
        end
    end
`endif

endmodule
