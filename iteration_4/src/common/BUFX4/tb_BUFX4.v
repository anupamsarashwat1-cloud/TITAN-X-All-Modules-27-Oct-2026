`timescale 1ns / 1ps

module tb_BUFX4();

    reg  A;
    wire Y;

    // DUT Instantiation
    BUFX4 uut (
        .A(A),
        .Y(Y)
    );

    // Initial block for stimulus and VCD dumping
    initial begin
        $dumpfile("tb_BUFX4.vcd");
        $dumpvars(0, tb_BUFX4);

        // Initialize inputs
        A = 0;

        // Add manual test stimulus here...

        #1000;
        $finish;
    end

endmodule
