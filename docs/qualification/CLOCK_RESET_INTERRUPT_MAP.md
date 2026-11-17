# SMVDU TITAN X — Clock, Reset and Interrupt Architecture Map

**Reference Specification:** SMVDU TITAN X SoC Release Baseline  
**Top Module:** `titan_x_top`  
**Target Node:** SCL 180nm CMOS Standard Cell / SMT Tapeout Baseline  

---

## 1. Clock Domain Topology

The TITAN X SoC features 8 primary synchronous and asynchronous clock domains managed at the top-level boundary:

| Clock Domain | Port Name | Nominal Frequency | Source / Generator | Target Subsystems | CDC Strategy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **System Core Clock** | `clk` | 50 - 100 MHz | Primary PLL / On-Chip Oscillator | 4x RV64IM_Zicsr Cores, L1/L2 Caches, AXI4 Crossbar, APB Fabric, Crypto Engines, UARTs, CANs, I2C, SPI | Synchronous Backbone |
| **PCIe PIPE Clock** | `pipe_clk` | 125 / 250 MHz | External PCIe Transceiver | PCIe Gen2 x4 PIPE 3.0 Interface (`u_pcie`) | Asynchronous FIFO (`fifo_async`) |
| **Ethernet TX Clock** | `eth_tx_clk` | 125 MHz (1Gbps) | External PHY TX Clock | Gigabit Ethernet MAC Transmit Datapath (`u_gem`) | Asynchronous FIFO (`fifo_async`) |
| **Ethernet RX Clock** | `eth_rx_clk` | 125 MHz (1Gbps) | External PHY RX Clock | Gigabit Ethernet MAC Receive Datapath (`u_gem`) | Asynchronous FIFO (`fifo_async`) |
| **USB ULPI Clock** | `ulpi_clk` | 60 MHz | USB 2.0 PHY Clock | USB 2.0 OTG Controller (`u_usb`) | Asynchronous FIFO (`fifo_async`) |
| **MIPI Byte Clock** | `mipi_rxbyteclkhs`| 100 - 200 MHz | MIPI D-PHY Receiver | MIPI CSI-2 Camera Receiver (`u_mipi`) | Asynchronous FIFO (`fifo_async`) |
| **HDMI Pixel Clock** | `hdmi_clk_pixel` | 25 - 74.25 MHz | Video Display PLL | Video Display Controller (`u_hdmi`) | Dual-Clock Buffer |
| **HDMI TMDS Clock** | `hdmi_clk_tmds` | 250 - 742.5 MHz | Video Serializer PLL | 10x Serializer TMDS Output Drivers (`u_hdmi`) | Direct Fast Clock |
| **RTC Clock** | `rtc_clk` | 32.768 kHz | Low-Power Crystal Oscillator | Real-Time Clock Counter (`u_rtc`) | 1-Bit Toggle Pulse Synchronizer (`cdc_sync`) |
| **JTAG TCK Clock** | `jtag_tck` | 10 - 20 MHz | External JTAG Probe | RISC-V Debug Module TAP Controller (`u_debug`) | Dual-Flop Synchronizer to `clk` |

---

## 2. Reset Domain Topology & Release Sequencing

| Reset Signal | Polarity | Domain / Driven By | Destination | Release Sequence & Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| `rst_n` | Active-Low | Master Chip Reset Pin | SoC Peripherals, Interconnect, Caches, Security RoT | Primary power-on reset input. Must be held low during VDD ramp. |
| `core_rst_n` | Active-Low | Derived: `rst_n & boot_pass & wdt_reset_n` | 4x `rv_core_top` and `rv_monitor_core` | Released only after RoT authentication succeeds (`boot_pass=1`) and WDT is healthy (`wdt_reset_n=1`). |
| `debug_rst_n`| Active-Low | Derived: `(jtag_trst_n === 1'b0) ? 1'b0 : rst_n` | `rv_debug` TAP & DTM Controller | Independent TAP reset via `jtag_trst_n`; recovers cleanly if TRST pin floats or asserts. |
| `ddr_reset_n`| Active-Low | Static: Tied to `rst_n` | External DDR4 SDRAM Chips | Released synchronously with DDR memory controller initialization. |
| `sd_reset_n` | Active-Low | Controller Output: `u_mmc` | External SD/eMMC Card | Driven by software command register in MMC controller. |
| `ulpi_reset` | Active-High | Controller Output: `u_usb` | External USB PHY | Inverted active-high reset driven by USB OTG core. |

---

## 3. Interrupt Routing Architecture (PLIC & CLINT)

### A. Core-Local Interruptor (`u_clint`)
- **Aperture:** `0x0200_0000 - 0x0200_FFFF` (mapped via APB at `0x4001_5000` alias)
- **Targets:** 5 Harts (Hart 0..3 Application Cores, Hart 4 Monitor Core)
- **Signals:**
  - `msip[4:0]`: Machine Software Interrupt per Hart (triggers CSR `mip.MSIP`)
  - `mtip[4:0]`: Machine Timer Interrupt per Hart (triggered when `mtime >= mtimecmp[c]`, triggers CSR `mip.MTIP`)

### B. Platform-Level Interrupt Controller (`u_plic`)
- **Aperture:** `0x0C00_0000 - 0x0FFF_FFFF` (mapped via APB at `0x40D0_0000` alias)
- **Sources:** 186 total interrupt lines
- **Targets:** 10 Contexts (5 Harts x 2 Privileges: M-mode Context `2*c`, S-mode reserved `2*c+1`)
- **Priority Levels:** 7 (3-bit priority registers per source)

#### Critical Peripheral Interrupt Line Mapping:
| PLIC IRQ ID | Source Subsystem | Driving Instance | Trigger Condition |
| :--- | :--- | :--- | :--- |
| **8** | Hardware TRNG | `u_trng` | Entropy FIFO threshold reached |
| **9** | ECDSA P-256 Engine | `u_ecdsa` | Signature verification or key generation complete |
| **10** | DRBG Engine | `u_drbg` | Random bit generation complete |
| **11** | AES-256 Engine | `u_aes` | Cipher block processing done |
| **12** | SHA-256 Engine | `u_sha256` | Message digest computed |
| **13** | GPIO Controller | `u_gpio` | Pin change/edge detected |
| **14** | Watchdog Timer | `u_wdt` | Watchdog counter pre-warning |
| **15** | SPI Master | `u_spi` | TX FIFO empty / RX byte received |
| **16** | I2C Master | `u_i2c` | Transfer done / ACK error |
| **20** | UART0 | `u_uart0` | RX Data Ready / TX Holding Empty |
| **21** | UART1 | `u_uart1` | RX Data Ready / TX Holding Empty |
| **22** | UART2 | `u_uart2` | RX Data Ready / TX Holding Empty |
| **23** | UART3 | `u_uart3` | RX Data Ready / TX Holding Empty |
| **24** | UART4 | `u_uart4` | RX Data Ready / TX Holding Empty |
| **25** | CAN Controller 0 | `u_can0` | Message frame received / Bus error |
| **26** | CAN Controller 1 | `u_can1` | Message frame received / Bus error |
| **27** | Gigabit Ethernet MAC| `u_gem` | Frame transmitted / Frame received |
| **28** | USB 2.0 OTG | `u_usb` | USB transaction packet complete |
| **29** | SD/eMMC Controller | `u_mmc` | Command response / Block transfer done |
