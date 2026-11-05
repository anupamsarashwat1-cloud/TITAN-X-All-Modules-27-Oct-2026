# SMVDU TITAN-X SoC — Hardware Dependency & Build Map
**Phase 1 Architectural Baseline & Independent Principal SoC Audit**  
**Canonical Repository Baseline:** `TITAN-X-2026-11-04` (`af13cba6bc3bc97b8e0fb4a81badc3f742088821`)  
**Design Authority:** Independent Principal SoC Architect & RTL Design Reviewer  

---

## 1. Top-Level Elaboration Dependency Graph

The top-level root module `titan_x_top` elaborates 53 underlying design modules across a 4-level hierarchy:

```
titan_x_top (top/titan_x_top/titan_x_top.v)
├── Core Cluster Subsystem
│   ├── [4x] rv_core_top (backend/rv_core_top/rv_core_top.v)
│   │   ├── BUFX4 (common/BUFX4/buf_macros.v)
│   │   ├── rv_fetch (frontend/rv_fetch/rv_fetch.v)
│   │   ├── rv_decode (frontend/rv_decode/rv_decode.v)
│   │   │   ├── BUFX4 (common/BUFX4/buf_macros.v)
│   │   │   └── rv_regfile (backend/rv_regfile/rv_regfile.v)
│   │   ├── rv_execute (backend/rv_execute/rv_execute.v)
│   │   │   ├── BUFX4 (common/BUFX4/buf_macros.v)
│   │   │   └── rv_csr (backend/rv_csr/rv_csr.v)
│   │   ├── rv_mem (backend/rv_mem/rv_mem.v)
│   │   ├── rv_writeback (backend/rv_writeback/rv_writeback.v)
│   │   ├── [if ENABLE_L1_CACHE] rv_icache (frontend/rv_icache/rv_icache.v)
│   │   ├── [if ENABLE_L1_CACHE] axi4_burst_to_lite (interconnect/axi4_burst_to_lite.v)
│   │   ├── [if ENABLE_L1_CACHE] rv_dcache (backend/rv_dcache/rv_dcache.v)
│   │   └── [if ENABLE_L1_CACHE] axi4_burst_to_lite (interconnect/axi4_burst_to_lite.v)
│   └── [1x] rv_monitor_core (backend/rv_monitor_core/rv_monitor_core.v)
│       ├── rv_decode (frontend/rv_decode/rv_decode.v)
│       └── rv_execute (backend/rv_execute/rv_execute.v)
│
├── Interconnect Fabric Subsystem
│   ├── interconnect_mpu (interconnect/interconnect_mpu/mpu.v)
│   ├── qos_controller (interconnect/qos_controller/qos_controller.v)
│   ├── axi4_crossbar (interconnect/axi4_crossbar/axi4_crossbar.v)
│   ├── axi4_to_ahb (interconnect/axi4_to_ahb/axi4_to_ahb.v)
│   └── mmu_arbiter (interconnect/mmu_arbiter/mmu_arbiter.v) [Inputs tied 0]
│
├── Memory Subsystem
│   ├── l2_cache_top (memory/l2_cache_top/l2_cache_top.v)
│   │   ├── l2_cache_ctrl (memory/l2_cache_ctrl/l2_cache_ctrl.v)
│   │   ├── l2_snoop_filter (memory/l2_snoop_filter/l2_snoop_filter.v)
│   │   └── axi4_burst_to_lite (interconnect/axi4_burst_to_lite.v)
│   ├── ddr_ctrl_top (memory/ddr_ctrl_top/ddr_ctrl_top.v)
│   │   ├── ddr_scheduler (memory/ddr_scheduler/ddr_scheduler.v)
│   │   └── ddr_phy_if (memory/ddr_phy_if/ddr_phy_if.v)
│   ├── axi_rom (top/axi_rom/axi_rom.v)
│   └── envm_ctrl (security/envm_ctrl/envm_ctrl.v)
│
├── Security Subsystem & Root of Trust
│   ├── secure_boot (security/secure_boot/secure_boot.v)
│   │   ├── sha256_engine (peripherals/sha256_engine/sha256_engine.v)
│   │   └── ecdsa_engine (security/ecdsa_engine/ecdsa_engine.v)
│   ├── sha256_engine (peripherals/sha256_engine/sha256_engine.v) [Standalone APB]
│   ├── ecdsa_engine (security/ecdsa_engine/ecdsa_engine.v) [Standalone APB]
│   ├── aes_engine (peripherals/aes_engine/aes_engine.v)
│   ├── trng (peripherals/trng/trng.v)
│   └── drbg (security/drbg/drbg.v)
│
├── Interrupt & Debug Subsystem
│   ├── plic (backend/plic/plic.v)
│   ├── clint (backend/clint/clint.v)
│   └── rv_debug (backend/rv_debug/rv_debug.v)
│
├── High-Speed Communication & Storage
│   ├── gem_ethernet (peripherals/gem_ethernet/gem_ethernet.v)
│   ├── pcie_top (peripherals/pcie_top/pcie_top.v)
│   │   └── pcie_pipe_if (peripherals/pcie_pipe_if/pcie_pipe_if.v)
│   ├── usb_otg (storage/usb_otg/usb_otg.v)
│   ├── mmc_controller (storage/mmc_controller/mmc_controller.v)
│   └── qspi_controller (storage/qspi_controller/qspi_controller.v)
│
├── Video & Imaging Pipeline
│   ├── mipi_csi2_rx (video/mipi_csi2_rx/mipi_csi2_rx.v)
│   ├── isp_pipeline (video/isp_pipeline/isp_pipeline.v)
│   ├── vdma (video/vdma/vdma.v)
│   └── hdmi_ctrl (video/hdmi_ctrl/hdmi_ctrl.v)
│
└── Low-Speed Peripherals
    ├── [5x] uart_16550 (peripherals/uart_16550/uart_16550.v)
    ├── [2x] can_controller (peripherals/can_controller/can_controller.v)
    ├── spi_master (peripherals/spi_master/spi_master.v)
    ├── i2c_master (peripherals/i2c_master/i2c_master.v)
    ├── gpio_ctrl (peripherals/gpio_ctrl/gpio_ctrl.v)
    ├── watchdog_timer (peripherals/watchdog_timer/watchdog_timer.v)
    └── rtc (peripherals/rtc/rtc.v)
```

---

## 2. Compilation Order & Filelist Sequence (`soc_filelist.f`)

The canonical compilation order enforces leaf-to-root dependency resolution:

1. `Design Files of TITAN X/includes/stdcell_stubs.v` (Foundry cell declarations)
2. `Design Files of TITAN X/common/BUFX4/buf_macros.v` (High-fanout buffer macros)
3. `Design Files of TITAN X/common/cdc_sync/cdc_sync.v` (Clock synchronizer utility)
4. `Design Files of TITAN X/common/fifo_sync/fifo_sync.v` (Synchronous FIFO)
5. `Design Files of TITAN X/common/fifo_async/fifo_async.v` (Asynchronous FIFO)
6. `Design Files of TITAN X/common/reset_sync/reset_sync.v` (Reset synchronizer)
7. `Design Files of TITAN X/frontend/rv_bpu/rv_bpu.v` (Branch predictor)
8. `Design Files of TITAN X/frontend/rv_fetch/rv_fetch.v` (Fetch pipeline stage)
9. `Design Files of TITAN X/frontend/rv_decode/rv_decode.v` (Decode pipeline stage)
10. `Design Files of TITAN X/frontend/rv_icache/rv_icache.v` (L1 instruction cache)
11. `Design Files of TITAN X/backend/rv_regfile/rv_regfile.v` (Integer register file)
12. `Design Files of TITAN X/backend/rv_execute/rv_execute.v` (Execute / ALU stage)
13. `Design Files of TITAN X/backend/rv_fpu/rv_fpu.v` (Floating point unit)
14. `Design Files of TITAN X/backend/rv_csr/rv_csr.v` (Privileged CSR bank)
15. `Design Files of TITAN X/backend/rv_mem/rv_mem.v` (Memory pipeline stage)
16. `Design Files of TITAN X/backend/rv_writeback/rv_writeback.v` (Writeback stage)
17. `Design Files of TITAN X/backend/rv_tlb/rv_tlb.v` (Translation lookaside buffer)
18. `Design Files of TITAN X/backend/rv_ptw/rv_ptw.v` (Page table walker)
19. `Design Files of TITAN X/backend/rv_pmp/rv_pmp.v` (Physical memory protection)
20. `Design Files of TITAN X/backend/rv_mmu/rv_mmu.v` (Sv39 MMU top)
21. `Design Files of TITAN X/backend/rv_dcache/rv_dcache.v` (L1 data cache)
22. `Design Files of TITAN X/backend/clint/clint.v` (Core-local interruptor)
23. `Design Files of TITAN X/backend/plic/plic.v` (Platform interrupt controller)
24. `Design Files of TITAN X/backend/rv_debug/rv_debug.v` (RISC-V debug module)
25. `Design Files of TITAN X/backend/rv_monitor_core/rv_monitor_core.v` (Hart 4 monitor core)
26. `Design Files of TITAN X/backend/rv_core_top/rv_core_top.v` (Hart 0–3 core top)
27. `Design Files of TITAN X/memory/sram_32x64_180nm/sram_32x64_180nm.v` (SRAM macro)
28. `Design Files of TITAN X/memory/sram_512kx8_180nm/sram_512kx8_180nm.v` (SRAM macro)
29. `Design Files of TITAN X/memory/l2_tag_array/l2_tag_array.v` (L2 tag array)
30. `Design Files of TITAN X/memory/l2_data_array/l2_data_array.v` (L2 data array)
31. `Design Files of TITAN X/memory/l2_snoop_filter/l2_snoop_filter.v` (MESI snoop directory)
32. `Design Files of TITAN X/memory/l2_cache_ctrl/l2_cache_ctrl.v` (L2 cache controller)
33. `Design Files of TITAN X/memory/l2_cache_top/l2_cache_top.v` (L2 cache top)
34. `Design Files of TITAN X/memory/ddr_scheduler/ddr_scheduler.v` (DDR command scheduler)
35. `Design Files of TITAN X/memory/ddr_phy_if/ddr_phy_if.v` (DDR physical interface)
36. `Design Files of TITAN X/memory/ddr_ctrl_top/ddr_ctrl_top.v` (DDR controller top)
37. `Design Files of TITAN X/interconnect/axi4_burst_to_lite.v` (Burst adapter shim)
38. `Design Files of TITAN X/interconnect/interconnect_mpu/mpu.v` (Interconnect MPU)
39. `Design Files of TITAN X/interconnect/mmu_arbiter/mmu_arbiter.v` (MMU PTW arbiter)
40. `Design Files of TITAN X/interconnect/qos_controller/qos_controller.v` (Interconnect QoS)
41. `Design Files of TITAN X/interconnect/ahb_to_apb/ahb_to_apb.v` (AHB-to-APB bridge)
42. `Design Files of TITAN X/interconnect/apb_bridge/apb_bridge.v` (APB bridge decoder)
43. `Design Files of TITAN X/interconnect/axi4_to_ahb/axi4_to_ahb.v` (AXI4-to-AHB bridge)
44. `Design Files of TITAN X/interconnect/axi4_crossbar/axi4_crossbar.v` (AXI4 15Mx9S crossbar)
45. `Design Files of TITAN X/peripherals/gpio_ctrl/gpio_ctrl.v` (GPIO controller)
46. `Design Files of TITAN X/peripherals/rtc/rtc.v` (Real-time clock)
47. `Design Files of TITAN X/peripherals/watchdog_timer/watchdog_timer.v` (Watchdog timer)
48. `Design Files of TITAN X/peripherals/uart_16550/uart_16550.v` (16550 UART)
49. `Design Files of TITAN X/peripherals/spi_master/spi_master.v` (SPI master)
50. `Design Files of TITAN X/peripherals/i2c_master/i2c_master.v` (I2C master)
51. `Design Files of TITAN X/peripherals/can_controller/can_controller.v` (CAN 2.0B)
52. `Design Files of TITAN X/peripherals/trng/trng.v` (TRNG entropy source)
53. `Design Files of TITAN X/security/drbg/drbg.v` (NIST SP 800-90A DRBG)
54. `Design Files of TITAN X/peripherals/sha256_engine/sha256_engine.v` (SHA-256 engine)
55. `Design Files of TITAN X/peripherals/aes_engine/aes_engine.v` (AES-256 engine)
56. `Design Files of TITAN X/security/ecdsa_engine/ecdsa_engine.v` (ECDSA P-256 engine)
57. `Design Files of TITAN X/security/envm_ctrl/envm_ctrl.v` (eNVM controller)
58. `Design Files of TITAN X/security/secure_boot/secure_boot.v` (Secure boot engine)
59. `Design Files of TITAN X/peripherals/gem_sgmii_pcs/gem_sgmii_pcs.v` (SGMII PCS)
60. `Design Files of TITAN X/peripherals/gem_ethernet/gem_ethernet.v` (Gigabit Ethernet MAC)
61. `Design Files of TITAN X/peripherals/pcie_pipe_if/pcie_pipe_if.v` (PCIe PIPE interface)
62. `Design Files of TITAN X/peripherals/pcie_top/pcie_top.v` (PCIe Gen2 controller)
63. `Design Files of TITAN X/storage/usb_otg/usb_otg.v` (USB 2.0 OTG)
64. `Design Files of TITAN X/storage/mmc_controller/mmc_controller.v` (SD/MMC host)
65. `Design Files of TITAN X/storage/qspi_controller/qspi_controller.v` (QSPI flash controller)
66. `Design Files of TITAN X/video/mipi_csi2_rx/mipi_csi2_rx.v` (MIPI CSI-2 RX)
67. `Design Files of TITAN X/video/isp_pipeline/isp_pipeline.v` (ISP pipeline)
68. `Design Files of TITAN X/video/vdma/vdma.v` (Video DMA engine)
69. `Design Files of TITAN X/video/hdmi_ctrl/hdmi_ctrl.v` (HDMI controller)
70. `Design Files of TITAN X/top/axi_rom/axi_rom.v` (Boot ROM memory model)
71. `Design Files of TITAN X/top/titan_x_top/titan_x_top.v` (Top-level SoC integration)
72. `Design Files of TITAN X/top/titan_x_top/tb_titan_x_top.v` (System regression testbench)

---

## 3. Include Header Dependencies

| Header File | Source Path | Included By Modules | Purpose |
| :--- | :--- | :--- | :--- |
| `params.vh` | `includes/params.vh` | `rv_core_top`, `rv_monitor_core`, `rv_fetch`, `rv_execute`, `rv_csr`, `rv_dcache`, `rv_icache`, `l2_cache_top` | Global parameter constants (`XLEN`, `L1I_WAYS`, `L1D_WAYS`, `RESET_PC`, address widths) |
| `isa_pkg.vh` | `includes/isa_pkg.vh` | `rv_core_top`, `rv_monitor_core`, `rv_decode`, `rv_execute`, `rv_csr` | RISC-V opcodes, ALU operation codes, privilege levels, trap cause codes |
| `isa_constants.vh` | `includes/isa_constants.vh` | Legacy / Standalone testbenches | Deprecated duplicate of `isa_pkg.vh` (retained for backward compatibility) |

---
