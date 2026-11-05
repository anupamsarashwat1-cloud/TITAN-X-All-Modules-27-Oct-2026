`timescale 1ns / 1ps

module tb_rv_tlb();

    logic clk;
    logic rst_n;
    logic va_in;
    logic asid_in;
    logic req_valid;
    logic pa_out;
    logic hit;
    logic perm_r;
    logic perm_w;
    logic perm_x;
    logic perm_u;
    logic page_fault;
    logic fill_valid;
    logic fill_va;
    logic fill_pa;
    logic fill_asid;
    logic fill_perm;
    logic fill_level;
    logic sfence_vma;
    logic sfence_asid;
    logic sfence_asid_val;
    logic sfence_va;
    logic sfence_va_val;
    logic access_r;
    logic access_w;
    logic access_x;
    logic priv_s;

    // DUT Instantiation
    rv_tlb uut (
        .clk(clk),
        .rst_n(rst_n),
        .va_in(va_in),
        .asid_in(asid_in),
        .req_valid(req_valid),
        .pa_out(pa_out),
        .hit(hit),
        .perm_r(perm_r),
        .perm_w(perm_w),
        .perm_x(perm_x),
        .perm_u(perm_u),
        .page_fault(page_fault),
        .fill_valid(fill_valid),
        .fill_va(fill_va),
        .fill_pa(fill_pa),
        .fill_asid(fill_asid),
        .fill_perm(fill_perm),
        .fill_level(fill_level),
        .sfence_vma(sfence_vma),
        .sfence_asid(sfence_asid),
        .sfence_asid_val(sfence_asid_val),
        .sfence_va(sfence_va),
        .sfence_va_val(sfence_va_val),
        .access_r(access_r),
        .access_w(access_w),
        .access_x(access_x),
        .priv_s(priv_s)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_tlb.vcd");
        $dumpvars(0, tb_rv_tlb);

        // 1. Initialize all data inputs
        va_in = 0;
        asid_in = 0;
        req_valid = 0;
        fill_valid = 0;
        fill_va = 0;
        fill_pa = 0;
        fill_asid = 0;
        fill_perm = 0;
        fill_level = 0;
        sfence_vma = 0;
        sfence_asid = 0;
        sfence_asid_val = 0;
        sfence_va = 0;
        sfence_va_val = 0;
        access_r = 0;
        access_w = 0;
        access_x = 0;
        priv_s = 0;

        // 2. Assert Resets
        #10;
        rst_n = 0; // Active low
        #100;
        // 3. De-assert Resets
        rst_n = 1;
        #20;

        // 4. Constrained Random Stimulus Injection
        // Generating aggressive random toggling to exercise internal logic
        repeat(500) begin
            #10;
            va_in = $random;
            asid_in = $random;
            req_valid = $random;
            fill_valid = $random;
            fill_va = $random;
            fill_pa = $random;
            fill_asid = $random;
            fill_perm = $random;
            fill_level = $random;
            sfence_vma = $random;
            sfence_asid = $random;
            sfence_asid_val = $random;
            sfence_va = $random;
            sfence_va_val = $random;
            access_r = $random;
            access_w = $random;
            access_x = $random;
            priv_s = $random;
        end

        #1000;
        $finish;
    end

endmodule
