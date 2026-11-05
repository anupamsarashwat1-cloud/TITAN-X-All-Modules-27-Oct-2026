`timescale 1ns / 1ps

module tb_rv_ptw();

    logic clk;
    logic rst_n;
    logic va_req;
    logic asid_req;
    logic satp_ppn;
    logic ptw_req;
    logic access_r;
    logic access_w;
    logic access_x;
    logic priv_s;
    logic ptw_busy;
    logic fill_valid;
    logic fill_va;
    logic fill_pa;
    logic fill_asid;
    logic fill_perm;
    logic fill_level;
    logic page_fault;
    logic fault_addr;
    logic fault_type;
    logic ptw_arvalid;
    logic ptw_arready;
    logic ptw_araddr;
    logic ptw_rvalid;
    logic ptw_rready;
    logic ptw_rdata;
    logic ptw_rresp;

    // DUT Instantiation
    rv_ptw uut (
        .clk(clk),
        .rst_n(rst_n),
        .va_req(va_req),
        .asid_req(asid_req),
        .satp_ppn(satp_ppn),
        .ptw_req(ptw_req),
        .access_r(access_r),
        .access_w(access_w),
        .access_x(access_x),
        .priv_s(priv_s),
        .ptw_busy(ptw_busy),
        .fill_valid(fill_valid),
        .fill_va(fill_va),
        .fill_pa(fill_pa),
        .fill_asid(fill_asid),
        .fill_perm(fill_perm),
        .fill_level(fill_level),
        .page_fault(page_fault),
        .fault_addr(fault_addr),
        .fault_type(fault_type),
        .ptw_arvalid(ptw_arvalid),
        .ptw_arready(ptw_arready),
        .ptw_araddr(ptw_araddr),
        .ptw_rvalid(ptw_rvalid),
        .ptw_rready(ptw_rready),
        .ptw_rdata(ptw_rdata),
        .ptw_rresp(ptw_rresp)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_ptw.vcd");
        $dumpvars(0, tb_rv_ptw);

        // 1. Initialize all data inputs
        va_req = 0;
        asid_req = 0;
        satp_ppn = 0;
        ptw_req = 0;
        access_r = 0;
        access_w = 0;
        access_x = 0;
        priv_s = 0;
        ptw_arready = 0;
        ptw_rvalid = 0;
        ptw_rdata = 0;
        ptw_rresp = 0;

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
            va_req = $random;
            asid_req = $random;
            satp_ppn = $random;
            ptw_req = $random;
            access_r = $random;
            access_w = $random;
            access_x = $random;
            priv_s = $random;
            ptw_arready = $random;
            ptw_rvalid = $random;
            ptw_rdata = $random;
            ptw_rresp = $random;
        end

        #1000;
        $finish;
    end

endmodule
