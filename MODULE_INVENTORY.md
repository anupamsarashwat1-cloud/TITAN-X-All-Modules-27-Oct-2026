# SMVDU TITAN-X — Complete Hardware Module Inventory
Generated during Phase 1 Architecture Qualification.
| Module Name | Source RTL File | Subsystem | Domain | Actual Function & Integration Status | Notes / Baseline Defect |
|:---|:---|:---|:---:|:---|:---|
| `BUFX4` | `includes/stdcell_stubs.v` | includes | clk/rst_n | Standard Cell Stub | Foundry library cell |
| `ICGX4` | `includes/stdcell_stubs.v` | includes | clk/rst_n | Standard Cell Stub | Foundry library cell |
| `BUFX4` | `common/BUFX4/buf_macros.v` | common | clk/rst_n | Standard Cell Stub | Foundry library cell |
| `cdc_sync` | `common/cdc_sync/cdc_sync.v` | common | clk/rst_n | Integrated | Functional |
| `fifo_sync` | `common/fifo_sync/fifo_sync.v` | common | clk/rst_n | Integrated | Functional |
| `fifo_async` | `common/fifo_async/fifo_async.v` | common | clk/rst_n | Integrated | Functional |
| `reset_sync` | `common/reset_sync/reset_sync.v` | common | clk/rst_n | Integrated | Functional |
| `rv_bpu` | `frontend/rv_bpu/rv_bpu.v` | frontend | clk/rst_n | Integrated | Functional |
| `rv_fetch` | `frontend/rv_fetch/rv_fetch.v` | frontend | clk/rst_n | Integrated | Functional |
| `rv_decode` | `frontend/rv_decode/rv_decode.v` | frontend | clk/rst_n | Integrated | Functional |
| `rv_icache` | `frontend/rv_icache/rv_icache.v` | frontend | clk/rst_n | Integrated | Functional |
| `rv_regfile` | `backend/rv_regfile/rv_regfile.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_execute` | `backend/rv_execute/rv_execute.v` | backend | clk/rst_n | Integrated | Functional |
| `as` | `backend/rv_execute/rv_execute.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_fpu` | `backend/rv_fpu/rv_fpu.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_csr` | `backend/rv_csr/rv_csr.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_mem` | `backend/rv_mem/rv_mem.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_writeback` | `backend/rv_writeback/rv_writeback.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_tlb` | `backend/rv_tlb/rv_tlb.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_ptw` | `backend/rv_ptw/rv_ptw.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_pmp` | `backend/rv_pmp/rv_pmp.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_mmu` | `backend/rv_mmu/rv_mmu.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_dcache` | `backend/rv_dcache/rv_dcache.v` | backend | clk/rst_n | Integrated -> Under Remediation | Baseline Defect B: snoop handling in idle only, sub-word sizing |
| `clint` | `backend/clint/clint.v` | backend | clk/rst_n | Integrated | Functional |
| `plic` | `backend/plic/plic.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_debug` | `backend/rv_debug/rv_debug.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_monitor_core` | `backend/rv_monitor_core/rv_monitor_core.v` | backend | clk/rst_n | Integrated | Functional |
| `rv_core_top` | `backend/rv_core_top/rv_core_top.v` | backend | clk/rst_n | Integrated -> Under Remediation | Baseline Defect B: L1 cache bus interfacing |
| `sram_32x64_180nm` | `memory/sram_32x64_180nm/sram_32x64_180nm.v` | memory | clk/rst_n | Behavioral Macro | Target 180nm SRAM model |
| `sram_512kx8_180nm` | `memory/sram_512kx8_180nm/sram_512kx8_180nm.v` | memory | clk/rst_n | Behavioral Macro | Target 180nm SRAM model |
| `l2_tag_array` | `memory/l2_tag_array/l2_tag_array.v` | memory | clk/rst_n | Integrated | Functional |
| `l2_data_array` | `memory/l2_data_array/l2_data_array.v` | memory | clk/rst_n | Integrated | Functional |
| `l2_snoop_filter` | `memory/l2_snoop_filter/l2_snoop_filter.v` | memory | clk/rst_n | Integrated | Functional |
| `l2_cache_ctrl` | `memory/l2_cache_ctrl/l2_cache_ctrl.v` | memory | clk/rst_n | Partially Integrated -> Under Remediation | Baseline Defect C: single-word write-through, way 0 only |
| `l2_cache_top` | `memory/l2_cache_top/l2_cache_top.v` | memory | clk/rst_n | Partially Integrated -> Under Remediation | Baseline Defect C: single-word write-through, way 0 only |
| `ddr_scheduler` | `memory/ddr_scheduler/ddr_scheduler.v` | memory | clk/rst_n | Integrated | Functional |
| `ddr_phy_if` | `memory/ddr_phy_if/ddr_phy_if.v` | memory | clk/rst_n | Integrated | Functional |
| `ddr_ctrl_top` | `memory/ddr_ctrl_top/ddr_ctrl_top.v` | memory | clk/rst_n | Integrated | Functional |
| `axi4_burst_to_lite` | `interconnect/axi4_burst_to_lite.v` | interconnect | clk/rst_n | Integrated | Functional |
| `interconnect_mpu` | `interconnect/interconnect_mpu/mpu.v` | interconnect | clk/rst_n | Integrated | Functional |
| `mmu_arbiter` | `interconnect/mmu_arbiter/mmu_arbiter.v` | interconnect | clk/rst_n | Integrated | Functional |
| `qos_controller` | `interconnect/qos_controller/qos_controller.v` | interconnect | clk/rst_n | Integrated | Functional |
| `ahb_to_apb` | `interconnect/ahb_to_apb/ahb_to_apb.v` | interconnect | clk/rst_n | Integrated | Functional |
| `apb_bridge` | `interconnect/apb_bridge/apb_bridge.v` | interconnect | clk/rst_n | Integrated | Functional |
| `axi4_to_ahb` | `interconnect/axi4_to_ahb/axi4_to_ahb.v` | interconnect | clk/rst_n | Integrated | Functional |
| `axi4_crossbar` | `interconnect/axi4_crossbar/axi4_crossbar.v` | interconnect | clk/rst_n | Integrated | Functional |
| `gpio_ctrl` | `peripherals/gpio_ctrl/gpio_ctrl.v` | peripherals | clk/rst_n | Integrated | Functional |
| `rtc` | `peripherals/rtc/rtc.v` | peripherals | clk/rst_n | Integrated | Functional |
| `watchdog_timer` | `peripherals/watchdog_timer/watchdog_timer.v` | peripherals | clk/rst_n | Integrated | Functional |
| `uart_16550` | `peripherals/uart_16550/uart_16550.v` | peripherals | clk/rst_n | Integrated | Functional |
| `spi_master` | `peripherals/spi_master/spi_master.v` | peripherals | clk/rst_n | Integrated | Functional |
| `i2c_master` | `peripherals/i2c_master/i2c_master.v` | peripherals | clk/rst_n | Integrated | Functional |
| `can_controller` | `peripherals/can_controller/can_controller.v` | peripherals | clk/rst_n | Integrated | Functional |
| `trng` | `peripherals/trng/trng.v` | peripherals | clk/rst_n | Integrated | Functional |
| `drbg` | `security/drbg/drbg.v` | security | clk/rst_n | Integrated | Functional |
| `sha256_engine` | `peripherals/sha256_engine/sha256_engine.v` | peripherals | clk/rst_n | Integrated | Functional |
| `aes_engine` | `peripherals/aes_engine/aes_engine.v` | peripherals | clk/rst_n | Integrated | Functional |
| `ecdsa_engine` | `security/ecdsa_engine/ecdsa_engine.v` | security | clk/rst_n | Stub -> Under Remediation | Baseline Defect A: 16-cycle dummy counter |
| `envm_ctrl` | `security/envm_ctrl/envm_ctrl.v` | security | clk/rst_n | Integrated | Functional |
| `secure_boot` | `security/secure_boot/secure_boot.v` | security | clk/rst_n | Partially Integrated -> Under Remediation | Baseline Defect A: 32-bit hash check & rolling hash bypass |
| `gem_sgmii_pcs` | `peripherals/gem_sgmii_pcs/gem_sgmii_pcs.v` | peripherals | clk/rst_n | Integrated | Functional |
| `gem_ethernet` | `peripherals/gem_ethernet/gem_ethernet.v` | peripherals | clk/rst_n | Integrated | Functional |
| `pcie_pipe_if` | `peripherals/pcie_pipe_if/pcie_pipe_if.v` | peripherals | clk/rst_n | Integrated | Functional |
| `pcie_top` | `peripherals/pcie_top/pcie_top.v` | peripherals | clk/rst_n | Integrated | Functional |
| `usb_otg` | `storage/usb_otg/usb_otg.v` | storage | clk/rst_n | Integrated | Functional |
| `mmc_controller` | `storage/mmc_controller/mmc_controller.v` | storage | clk/rst_n | Integrated | Functional |
| `qspi_controller` | `storage/qspi_controller/qspi_controller.v` | storage | clk/rst_n | Integrated | Functional |
| `mipi_csi2_rx` | `video/mipi_csi2_rx/mipi_csi2_rx.v` | video | clk/rst_n | Integrated | Functional |
| `isp_pipeline` | `video/isp_pipeline/isp_pipeline.v` | video | clk/rst_n | Integrated | Functional |
| `vdma` | `video/vdma/vdma.v` | video | clk/rst_n | Integrated | Functional |
| `hdmi_ctrl` | `video/hdmi_ctrl/hdmi_ctrl.v` | video | clk/rst_n | Integrated | Functional |
| `axi_rom` | `top/axi_rom/axi_rom.v` | top | clk/rst_n | Integrated | Functional |
| `titan_x_top` | `top/titan_x_top/titan_x_top.v` | top | clk/rst_n | Integrated | Functional |
| `tb_titan_x_top` | `top/titan_x_top/tb_titan_x_top.v` | top | clk/rst_n | Integrated | Functional |
