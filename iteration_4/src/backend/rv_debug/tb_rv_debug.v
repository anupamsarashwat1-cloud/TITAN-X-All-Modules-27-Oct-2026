`timescale 1ns / 1ps

module tb_rv_debug();

    logic clk;
    logic rst_n;
    logic tck;
    logic tms;
    logic tdi;
    logic tdo;
    logic halt_req;
    logic resume_req;
    logic hart_halted;
    logic hart_running;
    logic hart_unavail;
    logic reg_sel;
    logic reg_wr;
    logic reg_wdata;
    logic reg_rdata;
    logic cmd_exec;
    logic cmd_done;
    logic cmd_err;
    logic sb_arvalid;
    logic sb_arready;
    logic sb_araddr;
    logic sb_rvalid;
    logic sb_rready;
    logic sb_rdata;
    logic sb_rresp;
    logic sb_awvalid;
    logic sb_awready;
    logic sb_awaddr;
    logic sb_wvalid;
    logic sb_wready;
    logic sb_wdata;
    logic sb_wstrb;
    logic sb_wlast;
    logic sb_bvalid;
    logic sb_bready;

    // DUT Instantiation
    rv_debug uut (
        .clk(clk),
        .rst_n(rst_n),
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .halt_req(halt_req),
        .resume_req(resume_req),
        .hart_halted(hart_halted),
        .hart_running(hart_running),
        .hart_unavail(hart_unavail),
        .reg_sel(reg_sel),
        .reg_wr(reg_wr),
        .reg_wdata(reg_wdata),
        .reg_rdata(reg_rdata),
        .cmd_exec(cmd_exec),
        .cmd_done(cmd_done),
        .cmd_err(cmd_err),
        .sb_arvalid(sb_arvalid),
        .sb_arready(sb_arready),
        .sb_araddr(sb_araddr),
        .sb_rvalid(sb_rvalid),
        .sb_rready(sb_rready),
        .sb_rdata(sb_rdata),
        .sb_rresp(sb_rresp),
        .sb_awvalid(sb_awvalid),
        .sb_awready(sb_awready),
        .sb_awaddr(sb_awaddr),
        .sb_wvalid(sb_wvalid),
        .sb_wready(sb_wready),
        .sb_wdata(sb_wdata),
        .sb_wstrb(sb_wstrb),
        .sb_wlast(sb_wlast),
        .sb_bvalid(sb_bvalid),
        .sb_bready(sb_bready)
    );

    // Advanced Clock Generation (138.8 MHz -> ~7.2ns period)
    initial begin
        clk = 0;
    end

    always #3.6 clk = ~clk;

    // Main Functional Stimulus Block
    initial begin
        $dumpfile("tb_rv_debug.vcd");
        $dumpvars(0, tb_rv_debug);

        // 1. Initialize all data inputs
        tck = 0;
        tms = 0;
        tdi = 0;
        hart_halted = 0;
        hart_running = 0;
        hart_unavail = 0;
        reg_rdata = 0;
        cmd_done = 0;
        cmd_err = 0;
        sb_arready = 0;
        sb_rvalid = 0;
        sb_rdata = 0;
        sb_rresp = 0;
        sb_awready = 0;
        sb_wready = 0;
        sb_bvalid = 0;

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
            tck = $random;
            tms = $random;
            tdi = $random;
            hart_halted = $random;
            hart_running = $random;
            hart_unavail = $random;
            reg_rdata = $random;
            cmd_done = $random;
            cmd_err = $random;
            sb_arready = $random;
            sb_rvalid = $random;
            sb_rdata = $random;
            sb_rresp = $random;
            sb_awready = $random;
            sb_wready = $random;
            sb_bvalid = $random;
        end

        #1000;
        $finish;
    end

endmodule
