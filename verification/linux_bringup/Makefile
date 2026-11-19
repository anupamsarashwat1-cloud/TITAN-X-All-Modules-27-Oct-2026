# Automatically ensure ../rtl symlink exists pointing to the RTL directory
$(shell [ -e ../rtl ] || ln -s "../Design Files of TITAN X" ../rtl)

VERILATOR = verilator
VERILATOR_FLAGS = -Wno-fatal -Wno-COMBDLY -Wno-PINCONNECTEMPTY -Wno-DECLFILENAME -Wno-SYNCASYNCNET -Wno-SYMRSVDWORD -Wno-MULTIDRIVEN -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-PINMISSING -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNOPTFLAT -O3 -DSIM_AXI_RAM=1 -DFAST_SIM=1 -GBOOT_ADDR=64\'h0000000080000000 -GFAST_SIM=1 --cc --exe --build -j 4
V_TOP = ../rtl/top/titan_x_top/titan_x_top.v

INC_DIRS = -I../rtl/includes -I../rtl/top/titan_x_top -I../rtl/top/axi_rom -I../rtl/interconnect/axi4_crossbar -I../rtl/security/secure_boot -I../rtl/core -I../rtl/peripherals -I../rtl/backend/rv_core_top -I../rtl/backend/rv_execute -I../rtl/backend/rv_fetch -I../rtl/backend/rv_mmu -I../rtl/backend/rv_decode -I../rtl/backend/rv_writeback -I../rtl/backend/rv_pmp -I../rtl/backend/rv_ptw -I../rtl/backend/rv_tlb -I../rtl/backend/rv_mem -I../rtl/frontend/rv_fetch -I../rtl/frontend/rv_decode -I../rtl/frontend/rv_bpu -I../rtl/frontend/rv_icache -I../rtl/backend/rv_dcache -I../rtl/security/aes_engine -I../rtl/security/drbg -I../rtl/security/envm_ctrl -I../rtl/peripherals/uart_16550 -I../rtl/peripherals/rtc -I../rtl/peripherals/can_controller -I../rtl/peripherals/gem_ethernet -I../rtl/video/hdmi_ctrl -I../rtl/video/isp_pipeline -I../rtl/video/mipi_csi2_rx -I../rtl/peripherals/pcie_top -I../rtl/peripherals/usb_otg -I../rtl/interconnect/axi4_to_ahb -I../rtl/backend/rv_monitor_core -I../rtl/backend/l2_cache_top -I../rtl/common -I..

V_SRC_FILES = $(shell find -L ../rtl -name "*.v" | grep -v "ddr_ctrl_top" | grep -v "tb_" | grep -v "debug_xbar" | grep -v "bfm")
V_SRC_FILES += ./axi_ram.v

all: sim

sim: sim_main.cpp $(V_SRC_FILES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(INC_DIRS) --top-module titan_x_top $(V_SRC_FILES) sim_main.cpp

run: sim
	./obj_dir/Vtitan_x_top

clean:
	rm -rf obj_dir
