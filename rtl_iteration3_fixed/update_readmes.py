import os
import re

updates = {
    'peripherals/trng': {
        'overview': "The `trng` module implements a True Random Number Generator based on Free-running Ring Oscillators (FIRO/GARO). It includes a Von Neumann extractor to remove bias and features NIST SP 800-90B health tests (repetition count and adaptive proportion). The module aggregates entropy into a 256-bit accumulator and interfaces via an APB bus for configuration and a hardware DRBG interface for seeding.",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the sequential logic.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus for register access.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.trng_ready`': '- `uut.trng_ready`: Hardware interface ready signal indicating readiness to accept entropy.',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal indicating transfer completion.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal indicating transfer failure.',
            '- `uut.trng_entropy`': '- `uut.trng_entropy`: 256-bit output entropy data bus.',
            '- `uut.trng_valid`': '- `uut.trng_valid`: Signal indicating that the 256-bit entropy output is valid.',
            '- `uut.trng_irq`': '- `uut.trng_irq`: Interrupt request signal indicating a health test failure.'
        }
    },
    'peripherals/uart_16550': {
        'overview': "The `uart_16550` module is a Multi-Mode UART based on the standard 16550 architecture. It provides support for Local Interconnect Network (LIN), Infrared Data Association (IrDA), and 9-bit data transmission modes. The module interfaces over an APB bus for configuration and provides separated multiplexed pins for standard serial, IrDA, and LIN communications.",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the sequential logic.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus for register access.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.rxd`': '- `uut.rxd`: Standard serial receive data input pin.',
            '- `uut.irda_rx`': '- `uut.irda_rx`: IrDA receive data input pin.',
            '- `uut.lin_rx`': '- `uut.lin_rx`: LIN receive data input pin.',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal indicating transfer completion.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal indicating transfer failure.',
            '- `uut.uart_irq`': '- `uut.uart_irq`: Interrupt request signal from the UART core.',
            '- `uut.txd`': '- `uut.txd`: Standard serial transmit data output pin.',
            '- `uut.irda_tx`': '- `uut.irda_tx`: IrDA transmit data output pin.',
            '- `uut.lin_tx`': '- `uut.lin_tx`: LIN transmit data output pin.'
        }
    },
    'peripherals/watchdog_timer': {
        'overview': "The `watchdog_timer` module implements a robust APB-accessible system watchdog. It features a 32-bit down counter with a programmable reload value and a dedicated unlock key mechanism (0x1ACCE551) to prevent accidental control register writes. Upon the first expiry, it asserts an interrupt, and upon a subsequent expiry without being serviced, it asserts an active-low system reset.",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the sequential logic.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus (4-bit) for register access.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal indicating transfer completion.',
            '- `uut.wdt_reset_n`': '- `uut.wdt_reset_n`: Active-low system reset output asserted when the watchdog timer expires twice.',
            '- `uut.irq`': '- `uut.irq`: Interrupt request signal asserted upon the first watchdog timer expiry.'
        }
    },
    'storage/mmc_controller': {
        'overview': "The `mmc_controller` module implements an eMMC 5.1 / SD 3.0 Host Controller. It supports an AXI4 Master interface for direct memory access (DMA) block transfers, allowing efficient reading and writing of data. Configuration and status monitoring, including SD Host Controller Standard (SDHC) registers, are accessed via an APB slave interface. It also directly drives the physical SD/eMMC bus pins including clock, command, and data lines.",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the sequential logic.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.m_awready`': '- `uut.m_awready`: AXI4 write address ready signal from the slave.',
            '- `uut.m_wready`': '- `uut.m_wready`: AXI4 write data ready signal from the slave.',
            '- `uut.m_bvalid`': '- `uut.m_bvalid`: AXI4 write response valid signal from the slave.',
            '- `uut.m_bresp`': '- `uut.m_bresp`: AXI4 write response status from the slave.',
            '- `uut.m_bid`': '- `uut.m_bid`: AXI4 write response ID from the slave.',
            '- `uut.m_arready`': '- `uut.m_arready`: AXI4 read address ready signal from the slave.',
            '- `uut.m_rvalid`': '- `uut.m_rvalid`: AXI4 read data valid signal from the slave.',
            '- `uut.m_rdata`': '- `uut.m_rdata`: AXI4 read data bus from the slave.',
            '- `uut.m_rresp`': '- `uut.m_rresp`: AXI4 read response status from the slave.',
            '- `uut.m_rlast`': '- `uut.m_rlast`: AXI4 read last transfer signal from the slave.',
            '- `uut.m_rid`': '- `uut.m_rid`: AXI4 read ID from the slave.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus for register access.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.m_awvalid`': '- `uut.m_awvalid`: AXI4 write address valid signal.',
            '- `uut.m_awaddr`': '- `uut.m_awaddr`: AXI4 write address bus.',
            '- `uut.m_awid`': '- `uut.m_awid`: AXI4 write address ID.',
            '- `uut.m_awlen`': '- `uut.m_awlen`: AXI4 write burst length.',
            '- `uut.m_awsize`': '- `uut.m_awsize`: AXI4 write burst size.',
            '- `uut.m_wvalid`': '- `uut.m_wvalid`: AXI4 write data valid signal.',
            '- `uut.m_wdata`': '- `uut.m_wdata`: AXI4 write data bus.',
            '- `uut.m_wstrb`': '- `uut.m_wstrb`: AXI4 write strobe bus.',
            '- `uut.m_wlast`': '- `uut.m_wlast`: AXI4 write last transfer signal.',
            '- `uut.m_bready`': '- `uut.m_bready`: AXI4 write response ready signal.',
            '- `uut.m_arvalid`': '- `uut.m_arvalid`: AXI4 read address valid signal.',
            '- `uut.m_araddr`': '- `uut.m_araddr`: AXI4 read address bus.',
            '- `uut.m_arid`': '- `uut.m_arid`: AXI4 read address ID.',
            '- `uut.m_arlen`': '- `uut.m_arlen`: AXI4 read burst length.',
            '- `uut.m_arsize`': '- `uut.m_arsize`: AXI4 read burst size.',
            '- `uut.m_rready`': '- `uut.m_rready`: AXI4 read data ready signal.',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal indicating transfer completion.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal indicating transfer failure.',
            '- `uut.mmc_irq`': '- `uut.mmc_irq`: Interrupt request signal from the MMC controller.',
            '- `uut.sd_clk`': '- `uut.sd_clk`: Clock output for the SD/eMMC physical interface.',
            '- `uut.sd_reset_n`': '- `uut.sd_reset_n`: Active-low reset output for the SD/eMMC physical interface.'
        }
    },
    'storage/qspi_controller': {
        'overview': "The `qspi_controller` module implements a Quad-SPI Controller with Execute-in-Place (XIP) capability. It translates AXI4-Lite read transactions into standard QSPI commands (such as Fast Read Quad I/O), allowing a host processor to execute code directly from connected SPI flash memory. The module also features an APB slave interface for configuring SPI parameters like clock polarity (CPOL), clock phase (CPHA), and dummy cycles.",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the sequential logic.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.s_arvalid`': '- `uut.s_arvalid`: AXI4-Lite read address valid signal.',
            '- `uut.s_araddr`': '- `uut.s_araddr`: AXI4-Lite read address bus for XIP fetching.',
            '- `uut.s_rready`': '- `uut.s_rready`: AXI4-Lite read data ready signal.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus for register access.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.s_arready`': '- `uut.s_arready`: AXI4-Lite read address ready signal.',
            '- `uut.s_rvalid`': '- `uut.s_rvalid`: AXI4-Lite read data valid signal.',
            '- `uut.s_rdata`': '- `uut.s_rdata`: AXI4-Lite read data bus containing XIP data.',
            '- `uut.s_rresp`': '- `uut.s_rresp`: AXI4-Lite read response status.',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal indicating transfer completion.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal indicating transfer failure.',
            '- `uut.qspi_sclk`': '- `uut.qspi_sclk`: QSPI physical interface clock output.',
            '- `uut.qspi_cs_n`': '- `uut.qspi_cs_n`: QSPI physical interface active-low chip select output.'
        }
    },
    'storage/usb_otg': {
        'overview': "The `usb_otg` module implements a USB 2.0 On-The-Go (OTG) Controller supporting both Device and Host modes. It interfaces with an external USB PHY via a standard ULPI interface running at 60 MHz. Internally, the controller uses an AXI4 Master interface to perform scatter-gather DMA operations, and it is configured through an APB slave interface compatible with standard EHCI/OTG register sets.",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the sequential logic.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.ulpi_clk`': '- `uut.ulpi_clk`: 60 MHz clock input from the external ULPI PHY.',
            '- `uut.ulpi_dir`': '- `uut.ulpi_dir`: ULPI direction signal from the PHY.',
            '- `uut.ulpi_nxt`': '- `uut.ulpi_nxt`: ULPI next signal from the PHY.',
            '- `uut.m_awready`': '- `uut.m_awready`: AXI4 write address ready signal from the slave.',
            '- `uut.m_wready`': '- `uut.m_wready`: AXI4 write data ready signal from the slave.',
            '- `uut.m_bvalid`': '- `uut.m_bvalid`: AXI4 write response valid signal from the slave.',
            '- `uut.m_bresp`': '- `uut.m_bresp`: AXI4 write response status from the slave.',
            '- `uut.m_bid`': '- `uut.m_bid`: AXI4 write response ID from the slave.',
            '- `uut.m_arready`': '- `uut.m_arready`: AXI4 read address ready signal from the slave.',
            '- `uut.m_rvalid`': '- `uut.m_rvalid`: AXI4 read data valid signal from the slave.',
            '- `uut.m_rdata`': '- `uut.m_rdata`: AXI4 read data bus from the slave.',
            '- `uut.m_rresp`': '- `uut.m_rresp`: AXI4 read response status from the slave.',
            '- `uut.m_rlast`': '- `uut.m_rlast`: AXI4 read last transfer signal from the slave.',
            '- `uut.m_rid`': '- `uut.m_rid`: AXI4 read ID from the slave.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus for register access.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.ulpi_stp`': '- `uut.ulpi_stp`: ULPI stop signal to the PHY.',
            '- `uut.ulpi_reset`': '- `uut.ulpi_reset`: Active-high reset signal to the ULPI PHY.',
            '- `uut.m_awvalid`': '- `uut.m_awvalid`: AXI4 write address valid signal.',
            '- `uut.m_awaddr`': '- `uut.m_awaddr`: AXI4 write address bus.',
            '- `uut.m_awid`': '- `uut.m_awid`: AXI4 write address ID.',
            '- `uut.m_awlen`': '- `uut.m_awlen`: AXI4 write burst length.',
            '- `uut.m_awsize`': '- `uut.m_awsize`: AXI4 write burst size.',
            '- `uut.m_wvalid`': '- `uut.m_wvalid`: AXI4 write data valid signal.',
            '- `uut.m_wdata`': '- `uut.m_wdata`: AXI4 write data bus.',
            '- `uut.m_wstrb`': '- `uut.m_wstrb`: AXI4 write strobe bus.',
            '- `uut.m_wlast`': '- `uut.m_wlast`: AXI4 write last transfer signal.',
            '- `uut.m_bready`': '- `uut.m_bready`: AXI4 write response ready signal.',
            '- `uut.m_arvalid`': '- `uut.m_arvalid`: AXI4 read address valid signal.',
            '- `uut.m_araddr`': '- `uut.m_araddr`: AXI4 read address bus.',
            '- `uut.m_arid`': '- `uut.m_arid`: AXI4 read address ID.',
            '- `uut.m_arlen`': '- `uut.m_arlen`: AXI4 read burst length.',
            '- `uut.m_arsize`': '- `uut.m_arsize`: AXI4 read burst size.',
            '- `uut.m_rready`': '- `uut.m_rready`: AXI4 read data ready signal.',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal indicating transfer completion.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal indicating transfer failure.',
            '- `uut.usb_irq`': '- `uut.usb_irq`: Interrupt request signal from the USB OTG controller.'
        }
    },
    'video/hdmi_ctrl': {
        'overview': "The `hdmi_ctrl` module implements an HDMI 1.4 Display Controller. It accepts pixel data via an AXI4-Stream interface (typically from a Video DMA engine) and generates the necessary horizontal and vertical timing signals (HSYNC, VSYNC, VDE) based on APB-configurable display parameters. The controller also features built-in TMDS encoders to serialize the pixel and control data for the physical HDMI output over differential pairs.",
        'signals': {
            '- `uut.clk_pixel`': '- `uut.clk_pixel`: Pixel clock input (e.g., 74.25 MHz for 720p or 148.5 MHz for 1080p).',
            '- `uut.clk_tmds`': '- `uut.clk_tmds`: TMDS clock input, typically 10x the pixel clock for serialization.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.s_axis_tdata`': '- `uut.s_axis_tdata`: AXI4-Stream input data bus (RGB 8:8:8 pixel data).',
            '- `uut.s_axis_tvalid`': '- `uut.s_axis_tvalid`: AXI4-Stream input valid signal.',
            '- `uut.s_axis_tuser`': '- `uut.s_axis_tuser`: AXI4-Stream user signal, typically indicating Start of Frame (SOF).',
            '- `uut.s_axis_tlast`': '- `uut.s_axis_tlast`: AXI4-Stream last signal, typically indicating End of Line (EOL).',
            '- `uut.pclk`': '- `uut.pclk`: APB interface clock.',
            '- `uut.prst_n`': '- `uut.prst_n`: APB interface active-low asynchronous reset.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.s_axis_tready`': '- `uut.s_axis_tready`: AXI4-Stream ready signal to accept pixel data.',
            '- `uut.tmds_clk_p`': '- `uut.tmds_clk_p`: Differential TMDS clock output (positive).',
            '- `uut.tmds_clk_n`': '- `uut.tmds_clk_n`: Differential TMDS clock output (negative).',
            '- `uut.tmds_data_p`': '- `uut.tmds_data_p`: Differential TMDS data output lanes (positive).',
            '- `uut.tmds_data_n`': '- `uut.tmds_data_n`: Differential TMDS data output lanes (negative).',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal.'
        }
    },
    'video/isp_pipeline': {
        'overview': "The `isp_pipeline` module implements a basic Image Signal Processor (ISP) pipeline. It receives a raw video stream via an AXI4-Stream interface (typically from a MIPI CSI-2 receiver) and processes it through multiple stages, including Bayer to RGB bilinear interpolation, a 3x3 color correction matrix (CCM), and a Gamma correction lookup table (LUT). Configuration such as bypass mode and gamma parameters is controlled via an APB slave interface, and the processed pixel stream is output over another AXI4-Stream interface (typically to a VDMA).",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the sequential logic.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.s_axis_tdata`': '- `uut.s_axis_tdata`: AXI4-Stream input data bus containing raw pixels.',
            '- `uut.s_axis_tvalid`': '- `uut.s_axis_tvalid`: AXI4-Stream input valid signal.',
            '- `uut.s_axis_tuser`': '- `uut.s_axis_tuser`: AXI4-Stream input user signal (Start of Frame).',
            '- `uut.s_axis_tlast`': '- `uut.s_axis_tlast`: AXI4-Stream input last signal (End of Line).',
            '- `uut.m_axis_tready`': '- `uut.m_axis_tready`: AXI4-Stream output ready signal from the downstream receiver.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.s_axis_tready`': '- `uut.s_axis_tready`: AXI4-Stream input ready signal.',
            '- `uut.m_axis_tdata`': '- `uut.m_axis_tdata`: AXI4-Stream output data bus containing processed pixels.',
            '- `uut.m_axis_tvalid`': '- `uut.m_axis_tvalid`: AXI4-Stream output valid signal.',
            '- `uut.m_axis_tuser`': '- `uut.m_axis_tuser`: AXI4-Stream output user signal (Start of Frame).',
            '- `uut.m_axis_tlast`': '- `uut.m_axis_tlast`: AXI4-Stream output last signal (End of Line).',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal.'
        }
    },
    'video/mipi_csi2_rx': {
        'overview': "The `mipi_csi2_rx` module is a MIPI Camera Serial Interface 2 (CSI-2) Receiver designed to accept pixel streams from a D-PHY. It unpacks the high-speed serialized byte stream into a standardized AXI4-Stream output interface (providing signals like Start of Frame and End of Line) suitable for downstream image processing. It also provides an APB configuration interface to manage control and status registers, such as monitoring the active link status.",
        'signals': {
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.rxbyteclkhs`': '- `uut.rxbyteclkhs`: High-speed byte clock input from the D-PHY.',
            '- `uut.rxdatahs`': '- `uut.rxdatahs`: High-speed receive data lanes from the D-PHY.',
            '- `uut.rxvalidhs`': '- `uut.rxvalidhs`: High-speed receive valid signal lanes.',
            '- `uut.rxactivehs`': '- `uut.rxactivehs`: High-speed receive active signal lanes.',
            '- `uut.rxsyncbhs`': '- `uut.rxsyncbhs`: High-speed receive sync signal lanes.',
            '- `uut.rxdata_lp`': '- `uut.rxdata_lp`: Low-power receive data lanes.',
            '- `uut.m_axis_tready`': '- `uut.m_axis_tready`: AXI4-Stream output ready signal from the downstream receiver.',
            '- `uut.pclk`': '- `uut.pclk`: APB interface clock.',
            '- `uut.prst_n`': '- `uut.prst_n`: APB interface active-low asynchronous reset.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.m_axis_tdata`': '- `uut.m_axis_tdata`: AXI4-Stream output data bus containing pixels.',
            '- `uut.m_axis_tvalid`': '- `uut.m_axis_tvalid`: AXI4-Stream output valid signal.',
            '- `uut.m_axis_tuser`': '- `uut.m_axis_tuser`: AXI4-Stream output user signal (Start of Frame).',
            '- `uut.m_axis_tlast`': '- `uut.m_axis_tlast`: AXI4-Stream output last signal (End of Line).',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal.'
        }
    },
    'video/vdma': {
        'overview': "The `vdma` (Video DMA) module acts as a high-performance bridge between continuous AXI4-Stream video data and memory-mapped AXI4 (e.g., DDR memory). It features separate Write (S2MM) and Read (MM2S) channels, supporting advanced capabilities like triple buffering and 2D transfer strides. Configuration registers (such as frame sizes, strides, and buffer base addresses) are accessible via an APB slave interface, making it ideal for interfacing camera inputs and display outputs.",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the sequential logic.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.s_axis_s2mm_tdata`': '- `uut.s_axis_s2mm_tdata`: AXI4-Stream IN (S2MM) data bus.',
            '- `uut.s_axis_s2mm_tvalid`': '- `uut.s_axis_s2mm_tvalid`: AXI4-Stream IN (S2MM) valid signal.',
            '- `uut.s_axis_s2mm_tuser`': '- `uut.s_axis_s2mm_tuser`: AXI4-Stream IN (S2MM) user signal (Start of Frame).',
            '- `uut.s_axis_s2mm_tlast`': '- `uut.s_axis_s2mm_tlast`: AXI4-Stream IN (S2MM) last signal (End of Line).',
            '- `uut.m_axis_mm2s_tready`': '- `uut.m_axis_mm2s_tready`: AXI4-Stream OUT (MM2S) ready signal.',
            '- `uut.m_axi_awready`': '- `uut.m_axi_awready`: AXI4 Master write address ready.',
            '- `uut.m_axi_wready`': '- `uut.m_axi_wready`: AXI4 Master write data ready.',
            '- `uut.m_axi_bvalid`': '- `uut.m_axi_bvalid`: AXI4 Master write response valid.',
            '- `uut.m_axi_bresp`': '- `uut.m_axi_bresp`: AXI4 Master write response status.',
            '- `uut.m_axi_arready`': '- `uut.m_axi_arready`: AXI4 Master read address ready.',
            '- `uut.m_axi_rvalid`': '- `uut.m_axi_rvalid`: AXI4 Master read data valid.',
            '- `uut.m_axi_rdata`': '- `uut.m_axi_rdata`: AXI4 Master read data bus.',
            '- `uut.m_axi_rresp`': '- `uut.m_axi_rresp`: AXI4 Master read response status.',
            '- `uut.m_axi_rlast`': '- `uut.m_axi_rlast`: AXI4 Master read last signal.',
            '- `uut.paddr`': '- `uut.paddr`: APB slave address bus.',
            '- `uut.psel`': '- `uut.psel`: APB slave select signal.',
            '- `uut.penable`': '- `uut.penable`: APB slave enable signal.',
            '- `uut.pwrite`': '- `uut.pwrite`: APB slave write enable signal.',
            '- `uut.pwdata`': '- `uut.pwdata`: APB slave write data bus.',
            '- `uut.s_axis_s2mm_tready`': '- `uut.s_axis_s2mm_tready`: AXI4-Stream IN (S2MM) ready signal.',
            '- `uut.m_axis_mm2s_tdata`': '- `uut.m_axis_mm2s_tdata`: AXI4-Stream OUT (MM2S) data bus.',
            '- `uut.m_axis_mm2s_tvalid`': '- `uut.m_axis_mm2s_tvalid`: AXI4-Stream OUT (MM2S) valid signal.',
            '- `uut.m_axis_mm2s_tuser`': '- `uut.m_axis_mm2s_tuser`: AXI4-Stream OUT (MM2S) user signal (Start of Frame).',
            '- `uut.m_axis_mm2s_tlast`': '- `uut.m_axis_mm2s_tlast`: AXI4-Stream OUT (MM2S) last signal (End of Line).',
            '- `uut.m_axi_awvalid`': '- `uut.m_axi_awvalid`: AXI4 Master write address valid.',
            '- `uut.m_axi_awaddr`': '- `uut.m_axi_awaddr`: AXI4 Master write address bus.',
            '- `uut.m_axi_awlen`': '- `uut.m_axi_awlen`: AXI4 Master write burst length.',
            '- `uut.m_axi_awsize`': '- `uut.m_axi_awsize`: AXI4 Master write burst size.',
            '- `uut.m_axi_wvalid`': '- `uut.m_axi_wvalid`: AXI4 Master write data valid.',
            '- `uut.m_axi_wdata`': '- `uut.m_axi_wdata`: AXI4 Master write data bus.',
            '- `uut.m_axi_wstrb`': '- `uut.m_axi_wstrb`: AXI4 Master write strobe bus.',
            '- `uut.m_axi_wlast`': '- `uut.m_axi_wlast`: AXI4 Master write last signal.',
            '- `uut.m_axi_bready`': '- `uut.m_axi_bready`: AXI4 Master write response ready.',
            '- `uut.m_axi_arvalid`': '- `uut.m_axi_arvalid`: AXI4 Master read address valid.',
            '- `uut.m_axi_araddr`': '- `uut.m_axi_araddr`: AXI4 Master read address bus.',
            '- `uut.m_axi_arlen`': '- `uut.m_axi_arlen`: AXI4 Master read burst length.',
            '- `uut.m_axi_arsize`': '- `uut.m_axi_arsize`: AXI4 Master read burst size.',
            '- `uut.m_axi_rready`': '- `uut.m_axi_rready`: AXI4 Master read data ready.',
            '- `uut.prdata`': '- `uut.prdata`: APB slave read data bus.',
            '- `uut.pready`': '- `uut.pready`: APB slave ready signal.',
            '- `uut.pslverr`': '- `uut.pslverr`: APB slave error signal.',
            '- `uut.vdma_irq`': '- `uut.vdma_irq`: Interrupt request signal from the VDMA controller.'
        }
    },
    'top/titan_x_top': {
        'overview': "The `titan_x_top` module serves as the top-level integration wrapper for the SMVDU-TITAN-X System-on-Chip (SoC). It instantiates and interconnects all major subsystems via a central AXI4 crossbar, including four RV64GC processing cores, an RV64IMAC monitor core, an L2 cache and DDR4 memory controller, various high-speed interfaces (PCIe, Gigabit Ethernet, USB OTG), a complete video pipeline (MIPI CSI-2, ISP, VDMA, HDMI), a secure boot and crypto subsystem, and numerous low-speed peripherals (UART, CAN, RTC). This module ties all external I/O pins to their respective internal IP blocks.",
        'signals': {
            '- `uut.clk`': '- `uut.clk`: The main system clock driving the SoC.',
            '- `uut.rst_n`': '- `uut.rst_n`: Active-low asynchronous reset signal.',
            '- `uut.pipe_clk`': '- `uut.pipe_clk`: Clock for the PCIe PIPE interface.',
            '- `uut.eth_tx_clk`': '- `uut.eth_tx_clk`: Transmit clock for the Ethernet MAC.',
            '- `uut.eth_rx_clk`': '- `uut.eth_rx_clk`: Receive clock for the Ethernet MAC.',
            '- `uut.ulpi_clk`': '- `uut.ulpi_clk`: 60 MHz clock from the external USB PHY.',
            '- `uut.mipi_rxbyteclkhs`': '- `uut.mipi_rxbyteclkhs`: High-speed byte clock from the MIPI D-PHY.',
            '- `uut.hdmi_clk_pixel`': '- `uut.hdmi_clk_pixel`: Pixel clock for the HDMI controller.',
            '- `uut.hdmi_clk_tmds`': '- `uut.hdmi_clk_tmds`: TMDS clock for the HDMI controller.',
            '- `uut.rtc_clk`': '- `uut.rtc_clk`: Low-frequency clock for the Real-Time Clock module.',
            '- `uut.uart_rx`': '- `uut.uart_rx`: 5-bit input vector for UART receive lines.',
            '- `uut.can_rx`': '- `uut.can_rx`: 2-bit input vector for CAN receive lines.',
            '- `uut.ddr_addr`': '- `uut.ddr_addr`: DDR4 memory interface address bus.',
            '- `uut.ddr_ba`': '- `uut.ddr_ba`: DDR4 memory interface bank address.',
            '- `uut.ddr_bg`': '- `uut.ddr_bg`: DDR4 memory interface bank group.',
            '- `uut.ddr_ck_p`': '- `uut.ddr_ck_p`: DDR4 memory differential clock (positive).',
            '- `uut.ddr_ck_n`': '- `uut.ddr_ck_n`: DDR4 memory differential clock (negative).',
            '- `uut.ddr_cke`': '- `uut.ddr_cke`: DDR4 memory clock enable.',
            '- `uut.ddr_cs_n`': '- `uut.ddr_cs_n`: DDR4 memory active-low chip select.',
            '- `uut.ddr_ras_n`': '- `uut.ddr_ras_n`: DDR4 memory active-low row address strobe.',
            '- `uut.ddr_cas_n`': '- `uut.ddr_cas_n`: DDR4 memory active-low column address strobe.',
            '- `uut.ddr_we_n`': '- `uut.ddr_we_n`: DDR4 memory active-low write enable.',
            '- `uut.ddr_reset_n`': '- `uut.ddr_reset_n`: DDR4 memory active-low reset.',
            '- `uut.ddr_odt`': '- `uut.ddr_odt`: DDR4 memory on-die termination.',
            '- `uut.ddr_act_n`': '- `uut.ddr_act_n`: DDR4 memory active-low activation command.',
            '- `uut.hdmi_tmds_clk_p`': '- `uut.hdmi_tmds_clk_p`: Differential HDMI TMDS clock (positive).',
            '- `uut.hdmi_tmds_clk_n`': '- `uut.hdmi_tmds_clk_n`: Differential HDMI TMDS clock (negative).',
            '- `uut.hdmi_tmds_data_p`': '- `uut.hdmi_tmds_data_p`: Differential HDMI TMDS data lanes (positive).',
            '- `uut.hdmi_tmds_data_n`': '- `uut.hdmi_tmds_data_n`: Differential HDMI TMDS data lanes (negative).',
            '- `uut.uart_tx`': '- `uut.uart_tx`: 5-bit output vector for UART transmit lines.',
            '- `uut.can_tx`': '- `uut.can_tx`: 2-bit output vector for CAN transmit lines.'
        }
    }
}

base_path = '/home/anupam-sarashwat/rtl_verification_handoff'

for module, data in updates.items():
    readme_path = os.path.join(base_path, module, 'README.md')
    if not os.path.exists(readme_path):
        print(f"Skipping {readme_path}")
        continue
    
    with open(readme_path, 'r') as f:
        content = f.read()

    # Update Overview
    # Find the paragraph under ## 📝 Overview and replace or append to it.
    overview_match = re.search(r'(## 📝 Overview\n[^\n]+)', content)
    if overview_match:
        original = overview_match.group(1)
        if data['overview'] not in original:
            new_overview = original + "\n\n" + data['overview']
            content = content.replace(original, new_overview)

    # Update Signals
    for old_sig, new_sig in data['signals'].items():
        # Match exactly the old_sig line avoiding multiple matches
        # The line is usually "- `uut.clk`"
        pattern = re.compile(rf'^{re.escape(old_sig)}$', re.MULTILINE)
        content = pattern.sub(new_sig, content)

    with open(readme_path, 'w') as f:
        f.write(content)
        
print("Success!")
