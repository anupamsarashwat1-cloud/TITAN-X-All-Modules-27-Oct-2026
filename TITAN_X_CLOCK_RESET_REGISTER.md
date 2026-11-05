# SMVDU TITAN-X SoC — Clock and Reset Architecture Register
**Phase 1 Architectural Baseline & Independent Principal SoC Audit**  
**Canonical Repository Baseline:** `TITAN-X-2026-11-04` (`af13cba6bc3bc97b8e0fb4a81badc3f742088821`)  
**Design Authority:** Independent Principal SoC Architect & RTL Design Reviewer  

---

## 1. Global Clock Domain Architecture

The TITAN-X SoC implements a multi-clock heterogeneous domain architecture comprising 1 primary system clock domain, 1 low-frequency clock domain, and 7 high-speed asynchronous I/O peripheral clock domains.

### 1.1 Complete Clock Domain Register

| Clock Port Name | Clock Domain | Target Freq (Nominal) | Source Type | Destination Subsystems / Modules | Phase / Relationship | Evidence Reference |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `clk` | System Core Domain (`CLK_SYS`) | 125 – 200 MHz | Primary External Oscillator / PLL | Application Cores 0–3 (`u_core`), Monitor Core (`u_monitor`), AXI4 Crossbar (`u_crossbar`), L2 Cache (`u_l2_cache`), DDR4 Controller (`u_ddr_ctrl`), Boot ROM (`u_boot_rom`), PLIC (`u_plic`), CLINT (`u_clint`), Debug Module (`u_debug`), Security Engines (`u_secure_boot`, `u_sha256`, `u_ecdsa`, `u_aes`, `u_trng`, `u_drbg`, `u_envm`), Low-Speed Peripherals (`u_uart0..4`, `u_can0..1`, `u_spi`, `u_i2c`, `u_gpio`, `u_wdt`), DMA Controllers | Primary reference clock; synchronous backbone | `top/titan_x_top/titan_x_top.v:8` |
| `rtc_clk` | Real-Time Clock Domain (`CLK_RTC`) | 32.768 kHz | External Watch Crystal | RTC Subsystem (`u_rtc.rtc_clk`) | Asynchronous to `clk` | `top/titan_x_top/titan_x_top.v:45, 1006` |
| `pipe_clk` | PCIe Gen2 PIPE Domain (`CLK_PIPE`) | 125 / 250 MHz | External PCIe PHY Oscillator | PCIe Controller (`u_pcie.pipe_clk`, `u_pipe_if.pipe_clk`) | Asynchronous to `clk` | `top/titan_x_top/titan_x_top.v:30, 749` |
| `eth_tx_clk` | Ethernet Transmit Domain (`CLK_ETH_TX`)| 125 MHz (GbE) / 25 MHz (100M)| External Ethernet PHY | Gigabit Ethernet MAC TX Datapath (`u_gem.tx_clk`) | Asynchronous to `clk` | `top/titan_x_top/titan_x_top.v:31, 728` |
| `eth_rx_clk` | Ethernet Receive Domain (`CLK_ETH_RX`) | 125 MHz (GbE) / 25 MHz (100M)| Recovered by External PHY | Gigabit Ethernet MAC RX Datapath (`u_gem.rx_clk`) | Asynchronous to `clk` and `eth_tx_clk` | `top/titan_x_top/titan_x_top.v:32, 728` |
| `ulpi_clk` | USB ULPI PHY Domain (`CLK_ULPI`) | 60.000 MHz | External USB 2.0 PHY | USB OTG Controller (`u_usb.ulpi_clk`) | Asynchronous to `clk` | `top/titan_x_top/titan_x_top.v:33, 764` |
| `mipi_rxbyteclkhs` | MIPI CSI-2 RX Byte Clock (`CLK_MIPI`) | Up to 100 – 125 MHz | Camera Sensor D-PHY | MIPI CSI-2 RX Controller (`u_mipi.rxbyteclkhs`) | Asynchronous to `clk` | `top/titan_x_top/titan_x_top.v:36, 1086` |
| `hdmi_clk_pixel` | HDMI Pixel Clock Domain (`CLK_PIX`) | 25 – 148.5 MHz | Video PLL / Clock Synthesizer | HDMI Controller Pixel Pipeline (`u_hdmi.clk_pixel`) | Asynchronous to `clk` | `top/titan_x_top/titan_x_top.v:37, 1100` |
| `hdmi_clk_tmds` | HDMI TMDS Serializer Domain (`CLK_TMDS`) | 5x Pixel Clock (125 – 742.5 MHz) | Video PLL Multiplier | HDMI TMDS Output Serializers (`u_hdmi.clk_tmds`) | Synchronous to `hdmi_clk_pixel` (5:1 gear ratio) | `top/titan_x_top/titan_x_top.v:38, 1100` |

---

## 2. Clock-Domain Crossing (CDC) Analysis

### 2.1 Unintegrated CDC Synchronizer Modules
The repository contains four dedicated synchronization and crossing modules in `Design Files of TITAN X/common/`:
- `cdc_sync.v`: Configurable 2-stage / 3-stage flip-flop synchronizer.
- `fifo_sync.v`: Synchronous circular FIFO.
- `fifo_async.v`: Dual-clock asynchronous Gray-code pointer FIFO.
- `reset_sync.v`: Asynchronous-assert / synchronous-deassert reset synchronizer.

**Critical Finding:** None of these four modules are instantiated in `titan_x_top.v` or the top-level subsystem wrappers.
- The top-level design relies on internal ad-hoc clock crossing logic inside peripheral IP blocks (e.g. `u_gem`, `u_usb`, `u_hdmi`, `u_rtc`).
- Top-level asynchronous clock inputs (`rtc_clk`, `pipe_clk`, `eth_tx_clk`, `eth_rx_clk`, `ulpi_clk`, `mipi_rxbyteclkhs`, `hdmi_clk_pixel`, `hdmi_clk_tmds`) are connected directly to module input ports without boundary synchronizers.

---

## 3. Global Reset Architecture

### 3.1 Reset Signals & Polarities

| Reset Net Name | Polarity | Type | Source | Destinations / Gated Sinks | Release Dependencies | Evidence Reference |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `rst_n` | Active-Low | Asynchronous Input | External Pad Reset Pin | Top-level logic, Security subsystem (`u_secure_boot`, `u_sha256`, `u_ecdsa`, `u_trng`, `u_drbg`, `u_aes`, `u_envm`), Peripherals, L2 Cache, DDR Controller | External board power supply / supervisor | `top/titan_x_top/titan_x_top.v:9` |
| `core_rst_n` | Active-Low | Synchronous Gated Reset | Internal AND gate: `rst_n & boot_pass` | Application Cores 0–3 (`u_core[0..3].rst_n`), Monitor Core (`u_monitor.rst_n`), AXI4 Crossbar (`u_crossbar.rst_n`) | **Hardware Root-of-Trust Signature Verification (`boot_pass`)** | `top/titan_x_top/titan_x_top.v:97-98` |
| `ddr_reset_n` | Active-Low | Direct Output Passthrough | `assign ddr_reset_n = rst_n` | External DDR4 DRAM Pin | `rst_n` deassertion | `top/titan_x_top/titan_x_top.v:500` |
| `wdt_reset_n` | Active-Low | Internal Wire (No Sink) | Watchdog Timer (`u_wdt.wdt_reset_n`) | **DISCONNECTED (No Sink)** | Watchdog timeout | `top/titan_x_top/titan_x_top.v:1036, 1042` |
| `sd_reset_n` | Active-Low | Peripheral Output | SD/MMC Controller (`u_mmc.sd_reset_n`) | External SD/eMMC Card | Software register control | `top/titan_x_top/titan_x_top.v:87, 789` |
| `ulpi_reset` | Active-High | Peripheral Output | USB OTG Controller (`u_usb.ulpi_reset`) | External USB PHY | Software register control | `top/titan_x_top/titan_x_top.v:81, 770` |

---

## 4. Reset Sequencing & Root-of-Trust Release Dependency

### 4.1 Reset Release State Sequence

```
1. Power-On Reset Asserted (rst_n = 0)
   ├── All SoC logic held in reset
   ├── boot_pass = 0, boot_fail = 0
   └── core_rst_n = 0 (CPU cores & crossbar locked in reset)

2. External Reset Deasserted (rst_n: 0 -> 1)
   ├── Security subsystem, peripherals, L2, DDR released from reset
   ├── core_rst_n remains 0 (rst_n & boot_pass == 1 & 0 == 0)
   ├── Cores 0-4 held quiescent in reset
   ├── AXI4 Crossbar held quiescent in reset
   └── secure_boot state machine enters S_READ_HEADER

3. Cryptographic Boot Verification Phase (secure_boot.v)
   ├── Reads eNVM table words 0-2 (Validates "TITN" magic & Key ID)
   ├── Latches expected SHA-256 hash, public key (Qx, Qy), signature (r, s)
   ├── Streams 16-word payload to internal SHA-256 engine -> Computes digest
   ├── Compares digest with expected hash
   └── Triggers internal NIST P-256 ECDSA engine -> Verifies signature

4A. Verification PASS (ECDSA Valid)
   ├── secure_boot asserts boot_pass = 1
   ├── core_rst_n transitions 0 -> 1
   ├── AXI4 Crossbar emerges from reset and begins arbitration
   └── Cores 0-4 emerge from reset and fetch RESET_PC (0x1000_0000)

4B. Verification FAIL (Digest mismatch, Signature invalid, or Magic wrong)
   ├── secure_boot transitions to S_HALT and asserts boot_fail = 1
   ├── boot_pass remains 0
   └── core_rst_n permanently locked at 0 (System halted)
```

---

## 5. Reset Hazards & Critical Baseline Findings

1. **Watchdog Timer Reset Disconnection (DEF-ARCH-02):**
   - Signal `wdt_reset_n` is driven by `watchdog_timer.v:1042`, but in `titan_x_top.v` it is declared as a local wire with **zero load fanout**.
   - If software deadlocks and the watchdog expires, the hardware reset pulse is completely lost. Only an interrupt (`plic_irq[14]`) is delivered, which cannot recover a crashed CPU core.
2. **Reset-Domain Crossing Hazard on `core_rst_n`:**
   - `core_rst_n` is generated via a combinational AND gate (`assign core_rst_n = rst_n & boot_pass;`).
   - If `boot_pass` asserts asynchronously relative to `clk`, flip-flops across Cores 0–4 and the AXI Crossbar will experience asynchronous reset deassertion without a reset synchronizer, creating standard metastability hazards during reset exit.
   - Recommended remediation: Pass `core_rst_n` through `reset_sync.v` before distributing to the core cluster.

---
