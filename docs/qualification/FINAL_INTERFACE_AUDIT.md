# SMVDU TITAN X — Complete Interface and Protocol Audit Report

**Audit Date:** 2026-11-18  
**Scope:** Synthesizable SoC Boundary and Internal Inter-Module Busses  
**Audit Methodology:** Static AST Parse, Port Direction Reconciliation, Width Verification, and Waveform Validation  

---

## 1. Top-Level Physical Interface Conformance

Every pin declared on `titan_x_top` has been audited against its electrical, directional, and functional specifications:

| Pin Group | Port Signals | Width | Direction | Verified Internal Destination | Protocol Compliance |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **System Clock & Reset** | `clk`, `rst_n` | 1, 1 | In, In | Primary clock tree & reset synchronizers | Active-low reset with synchronous deassertion |
| **DDR4 SDRAM Interface** | `ddr_addr`, `ddr_ba`, `ddr_bg`, `ddr_ck_p/n`, `ddr_cke`, `ddr_cs_n`, `ddr_ras_n`, `ddr_cas_n`, `ddr_we_n`, `ddr_reset_n`, `ddr_odt`, `ddr_act_n`, `ddr_dq[63:0]`, `ddr_dqs_p/n[7:0]` | 16+3+2+2+1+1+1+1+1+1+1+1+64+16 | Out / Inout | `u_ddr_ctrl` (`ddr_phy_if` & `ddr_scheduler`) | JEDEC JESD79-4B DDR4 SDRAM Timing Standard |
| **Gigabit Ethernet GMII**| `gmii_txd[7:0]`, `gmii_tx_en`, `gmii_tx_er`, `gmii_rxd[7:0]`, `gmii_rx_dv`, `gmii_rx_er`, `gmii_crs`, `gmii_col` | 8+1+1+8+1+1+1+1 | Out / In | `u_gem` (`gem_ethernet`) | IEEE 802.3z GMII Gigabit Ethernet Standard |
| **PCIe PIPE 3.0** | `pipe_tx_data[63:0]`, `pipe_tx_datak[7:0]`, `pipe_rx_data[63:0]`, `pipe_rx_datak[7:0]`, `pipe_tx_rate`, `pipe_tx_elecidle`, `pipe_tx_compliance`, `pipe_rx_polarity`, `pipe_power_down`, `pipe_rx_valid`, `pipe_rx_elecidle`, `pipe_rx_status`, `pipe_phy_status` | 64+8+64+8+2+4+4+4+8+4+4+12+4 | Out / In | `u_pcie` (`pcie_top`) | Intel PHY Interface for the PCI Express Architecture (PIPE) v3.0 |
| **USB 2.0 OTG ULPI** | `ulpi_data[7:0]`, `ulpi_dir`, `ulpi_nxt`, `ulpi_stp`, `ulpi_reset` | 8+1+1+1+1 | Inout / In / Out | `u_usb` (`usb_otg`) | UTMI+ Low Pin Interface (ULPI) v1.1 Standard |
| **SD/eMMC Storage** | `sd_clk`, `sd_cmd`, `sd_dat[7:0]`, `sd_reset_n` | 1+1+8+1 | Out / Inout | `u_mmc` (`mmc_controller`) | SD Card Physical Layer Spec v3.01 / JEDEC eMMC v4.51 |
| **Quad-SPI Storage** | `qspi_sclk`, `qspi_cs_n`, `qspi_io[3:0]` | 1+1+4 | Out / Inout | `u_qspi` (`qspi_controller`) | Quad Serial Peripheral Interface (x1, x2, x4 modes) |
| **Video MIPI CSI-2** | `mipi_rxbyteclkhs` | 1 | In | `u_mipi` (`mipi_csi2_rx`) | MIPI Alliance Specification for D-PHY / CSI-2 |
| **Video HDMI Display** | `hdmi_clk_pixel`, `hdmi_clk_tmds`, `hdmi_tmds_clk_p/n`, `hdmi_tmds_data_p/n[2:0]` | 1+1+2+6 | In / Out | `u_hdmi` (`hdmi_ctrl`) | DVI 1.0 / HDMI 1.4b TMDS Differential Signaling |
| **RISC-V Debug / JTAG** | `jtag_tck`, `jtag_tms`, `jtag_tdi`, `jtag_tdo`, `jtag_trst_n` | 1+1+1+1+1 | In / Out | `u_debug` (`rv_debug`) | IEEE 1149.1 Standard Test Access Port & RISC-V Debug Spec 0.13 |
| **Serial Communications** | `uart_tx/rx[4:0]`, `can_tx/rx[1:0]` | 5+5+2+2 | Out / In | `u_uart0..4`, `u_can0..1` | EIA RS-232 / ISO 11898-1 CAN 2.0B |

---

## 2. Internal Bus Matrix Protocol Verification

1. **AXI4-Full System Interconnect (`axi4_crossbar`):**
   - Address Width: 40 bits (`AW=40`).
   - Data Width: 64 bits (`DW=64`).
   - ID Width: 4 bits (`IDW=4`).
   - Master Ports: 15 (Cores 0-3 Inst/Data, Monitor Core Inst/Data, Ethernet, PCIe, USB, MMC, VDMA).
   - Slave Ports: 9 (DDR4/L2, APB Fabric, Boot ROM, On-Chip SRAM, QSPI, PCIe, Video, eNVM, DECERR).
   - Arbitration: Round-robin with priority fairness and active unmapped address `2'b11 (DECERR)` response.

2. **AHB-to-APB Protocol Bridge (`axi4_to_ahb` & Peripheral Decoders):**
   - Converts 64-bit AXI4 single/burst transactions into 32-bit AHB-Lite and 32-bit APB3 transfers.
   - PSEL decoding guarantees 1-hot mutual exclusion across all 28 integrated peripheral apertures.
   - PREADY wait-state handling supported; zero wait-state combinational PRDATA multiplexing verified.

3. **L2 MESI Coherence Snoop Protocol (`l2_snoop_filter`):**
   - Snoop Request Types: `2'b00 (Shared/Read)`, `2'b01 (Clean/Writeback)`, `2'b10 (Invalidate)`, `2'b11 (Reserved)`.
   - Invalidation Accumulation: `ack_accum[3:0]` and `dirty_accum` registers guarantee zero deadlock and zero lost dirty lines under staggered or delayed multi-core responses.
