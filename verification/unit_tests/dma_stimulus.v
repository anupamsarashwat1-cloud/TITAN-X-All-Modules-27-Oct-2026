module dma_stimulus;
    initial begin
        // Wait for system reset to deassert
        wait(tb_titan_x_top.uut.core_rst_n == 1'b1);
        #1000;
        
        // Force DMA masters active by forcing the internal signals
        // connected to the top-level ports or internal busses.
        $display("Forcing DMA masters active...");
        force tb_titan_x_top.uut.axm_awvalid[10] = 1'b1;
        force tb_titan_x_top.uut.axm_arvalid[10] = 1'b1;
    end
endmodule
