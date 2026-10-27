# SMVDU TITAN-X SoC — Complete Unified Design, Verification & Firmware Repository

> **Architecture:** Quad-Core RV64GC + Monitor RV64IMAC • Sv39 MMU • 15M×9S AXI4 Crossbar • DDR4 • PCIe • GbE • USB OTG • HDMI • MIPI CSI-2  
> **Process Target:** SCL 180 nm • **Last Updated:** 27 October 2026

This repository is the **complete, unified, and self-contained workspace** for the SMVDU TITAN-X System-on-Chip. It contains:
* **All 71 Pure Verilog Design Modules** (`.v`) organized into logical subsystem hierarchies.
* **Complete Testbench Suite** (`tb_*.v`) for all 63 sub-modules, 6 integration testbenches, and top-level integration.
* **GTKWave Visual Debug Configs** (`tb_*.gtkw`) for instant signal inspection.
* **Bus Functional Models (BFMs)** in `bfm/` for DDR4, AXI memory, PCIe, GMII, MIPI, and ULPI.
* **System Architecture & Verification Packages** (`includes/`): `isa_pkg.vh`, `params.vh`, `isa_constants.vh`, `tb_bfms.vh`, `tb_macros.vh`, and standard cell stubs.
* **Firmware & Boot ROM Payloads** (`firmware/` and `top/axi_rom/`): `firmware.hex`, `boot.mem`, C source (`main.c`), startup assembly (`start.S`), linker scripts, and ELF/bin binaries.
* **Instruction Memory Test Vectors & Golden Traces** (`backend/rv_core_top/*.hex`, `*.mem`): 30 verification files covering RV64I, Compliance, CSR, IRQ, M-extension, and Word Operations.
* **Automated Regression Suite** (`scripts/run_regress.py`, `scripts/waves.py`, etc.).
* **Per-Module Documentation**: Each module directory includes an individual `README.md` with full port tables, functional descriptions, hierarchical block diagrams, and signal-level Mermaid diagrams.
* **Verification Guides**: [`VERIFICATION_GUIDE.md`](VERIFICATION_GUIDE.md) and [`MANUAL_VERIFICATION_GUIDE.md`](MANUAL_VERIFICATION_GUIDE.md) detailing bottom-up verification commands.

---

## 📐 SoC Architecture — Microscopic Diagrams

The full SoC is split into **8 focused subsystem diagrams** below, each showing exact module instances, signal connections, and bus protocols. Together they cover **all 71 Verilog modules**.

---

### Diagram 1 — Top-Level SoC Block Interconnect

Shows the major functional blocks of `titan_x_top.v`, AXI master/slave port assignments, boot gating, and clock distribution.

```mermaid
graph TB
    subgraph PADS["External I/O Pads"]
        pad_clk(["clk"])
        pad_rst_n(["rst_n"])
        pad_ddr(["DDR4: ddr_addr/ba/bg/ck/cke/cs/ras/cas/we<br/>ddr_dq[63:0], ddr_dqs_p/n[7:0]"])
        pad_hdmi(["HDMI: tmds_clk_p/n, tmds_data_p/n[2:0]"])
        pad_uart(["uart_rx/tx[4:0]"])
        pad_can(["can_rx/tx[1:0]"])
        pad_eth(["eth_tx_clk, eth_rx_clk"])
        pad_pcie(["pipe_clk"])
        pad_usb(["ulpi_clk"])
        pad_mipi(["mipi_rxbyteclkhs"])
        pad_hdmi_clk(["hdmi_clk_pixel/tmds"])
        pad_rtc(["rtc_clk (32.768 kHz)"])
    end

    subgraph BOOT["🔐 Secure Boot Gate"]
        reset_sync["reset_sync.v"]
        u_secure_boot["secure_boot.v<br/>(SHA-256 verify)"]
        boot_pass{{"boot_pass"}}
        core_rst{{"core_rst_n = rst_n & boot_pass"}}
        reset_sync --> u_secure_boot
        u_secure_boot -->|"boot_pass"| boot_pass --> core_rst
    end

    CPU["🧠 CPU Cluster<br/>4× rv_core_top (RV64GC)<br/>1× rv_monitor_core (RV64IMAC)<br/>rv_debug (JTAG)"]
    XBAR["🔀 AXI4 Crossbar<br/>axi4_crossbar.v (15M×9S)<br/>+ qos_controller + mpu<br/>+ axi4_burst_to_lite<br/>+ mmu_arbiter"]
    MEM["💾 Memory Subsystem<br/>l2_cache_top → ddr_ctrl_top<br/>+ SRAM macros<br/>(Slave 0)"]
    BRIDGE["🌉 Bridge Chain<br/>axi4_to_ahb → ahb_to_apb<br/>→ apb_bridge → APB bus<br/>(Slave 1)"]
    BOOTROM["📖 Boot ROM<br/>axi_rom.v<br/>(Slave 2, 0x1000_0000)"]
    DMA["⚡ DMA Masters<br/>gem_ethernet (M10)<br/>pcie_top (M11)<br/>usb_otg (M12)"]
    PERIPH["📡 APB Peripherals<br/>5× UART, 2× CAN, RTC<br/>GPIO, I2C, SPI, WDT"]
    SEC["🔒 Security<br/>DRBG, AES, SHA-256<br/>ECDSA, eNVM, TRNG"]
    VIDEO["🎬 Video Pipeline<br/>MIPI CSI-2 → ISP → HDMI<br/>+ VDMA"]
    STORAGE["💿 Storage<br/>mmc_controller<br/>qspi_controller"]
    IRQ["🚨 Interrupts<br/>PLIC + CLINT"]
    COMMON["🔧 Common<br/>cdc_sync, fifo_async/sync<br/>reset_sync, BUFX4, stdcell_stubs"]

    pad_rst_n --> BOOT
    core_rst --> CPU
    pad_clk --> CPU & XBAR & MEM & BRIDGE

    CPU -->|"M0-M3: imem AR/R<br/>M4-M7: dmem Full<br/>M8-M9: monitor"| XBAR
    DMA -->|"M10-M12: AXI4 Full"| XBAR

    XBAR -->|"S0: 0x8000_0000"| MEM
    XBAR -->|"S1: 0x1000_0000"| BRIDGE
    XBAR -->|"S2: 0x1000_0000 (RO)"| BOOTROM

    BRIDGE --> PERIPH
    BRIDGE --> SEC
    BRIDGE --> VIDEO
    BRIDGE --> DMA

    MEM --> pad_ddr
    VIDEO --> pad_hdmi
    PERIPH --> pad_uart & pad_can
    pad_eth --> DMA
    pad_pcie --> DMA
    pad_usb --> DMA
    pad_mipi --> VIDEO
    pad_hdmi_clk --> VIDEO
    pad_rtc --> PERIPH

    PERIPH -->|"plic_irq[20-28]"| IRQ
    SEC -->|"plic_irq[10-11]"| IRQ
    IRQ -->|"irq_m_ext[4:0]<br/>timer_irq[4:0]<br/>sw_irq[4:0]"| CPU

    u_secure_boot -->|"envm_addr/req"| SEC
    SEC -->|"envm_rdata/valid"| u_secure_boot

    classDef padN fill:#dfe6e9,stroke:#b2bec3,stroke-width:2px,color:#2d3436
    classDef bootN fill:#fd79a8,stroke:#e84393,stroke-width:2px,color:#fff
    classDef coreN fill:#74b9ff,stroke:#0984e3,stroke-width:2px,color:#2d3436
    classDef xbarN fill:#fab1a0,stroke:#e17055,stroke-width:2px,color:#2d3436
    classDef memN fill:#a29bfe,stroke:#6c5ce7,stroke-width:2px,color:#fff
    classDef perN fill:#55efc4,stroke:#00b894,stroke-width:2px,color:#2d3436
    classDef secN fill:#fd79a8,stroke:#e84393,stroke-width:2px,color:#fff
    classDef vidN fill:#fdcb6e,stroke:#e17055,stroke-width:2px,color:#2d3436
    classDef irqN fill:#ff7675,stroke:#d63031,stroke-width:2px,color:#fff
    classDef dmaN fill:#00cec9,stroke:#00b894,stroke-width:2px,color:#2d3436
    classDef storN fill:#e17055,stroke:#d63031,stroke-width:2px,color:#fff
    classDef comN fill:#b2bec3,stroke:#636e72,stroke-width:2px,color:#2d3436

    class pad_clk,pad_rst_n,pad_ddr,pad_hdmi,pad_uart,pad_can,pad_eth,pad_pcie,pad_usb,pad_mipi,pad_hdmi_clk,pad_rtc padN
    class reset_sync,u_secure_boot,boot_pass,core_rst bootN
    class CPU coreN
    class XBAR xbarN
    class MEM memN
    class BRIDGE xbarN
    class BOOTROM memN
    class DMA dmaN
    class PERIPH perN
    class SEC secN
    class VIDEO vidN
    class IRQ irqN
    class STORAGE storN
    class COMMON comN
```

---

### Diagram 2 — CPU Core 0 Internal Pipeline (rv_core_top.v)

Fully expanded view of one RV64GC core — all 16 sub-modules with every inter-stage signal.

```mermaid
graph LR
    subgraph S1["Stage 1: Fetch"]
        FETCH["rv_fetch.v<br/>• PC gen (RESET_PC)<br/>• AXI AR channel<br/>• Redirect drain FSM"]
        BPU["rv_bpu.v<br/>• Tournament predictor<br/>• 2K×2-bit BHT<br/>• 12-bit GHR, 8-entry RAS"]
        ICACHE["rv_icache.v<br/>• 32KB 8-way SA VIPT<br/>• SECDED ECC<br/>• AXI 8-beat refill"]
        FETCH -.-> BPU
        FETCH -.-> ICACHE
    end

    subgraph S2["Stage 2: Decode"]
        DECODE["rv_decode.v<br/>• Imm gen (I/S/B/U/J)<br/>• Control decode<br/>• CSR/SYSTEM instrs"]
        REGFILE["rv_regfile.v<br/>• 32×64-bit GPRs<br/>• 2R1W, x0=0"]
        DECODE <-->|"rs1/rs2_addr[4:0]<br/>rs1/rs2_data[63:0]"| REGFILE
    end

    subgraph S3["Stage 3: Execute"]
        EXECUTE["rv_execute.v<br/>• 64-bit ALU (ADD-SRA-SLT)<br/>• MUL/DIV (64-cyc)<br/>• AMO (A-ext)<br/>• Branch resolution<br/>• Forwarding mux"]
        CSR["rv_csr.v<br/>• mstatus/mtvec/mepc<br/>• mcause/mip/mie<br/>• satp/sstatus<br/>• M/S/U privilege"]
        FPU["rv_fpu.v<br/>• F/D extensions<br/>• FMADD/FSQRT<br/>• 32×64-bit FPRs"]
        EXECUTE <-->|"csr_addr/wdata/rdata"| CSR
        EXECUTE <-->|"fpu_result/valid"| FPU
    end

    subgraph S4["Stage 4: Memory"]
        MEM["rv_mem.v<br/>• AXI AW/W/B (store)<br/>• AXI AR/R (load)<br/>• Load sign-extend<br/>• Store byte-enable"]
        DCACHE["rv_dcache.v<br/>• 32KB 8-way SA<br/>• Write-back, PLRU<br/>• AXI refill/evict"]
        MEM -.-> DCACHE
    end

    subgraph S5["Stage 5: Writeback"]
        WB["rv_writeback.v<br/>• rd commit<br/>• fwd_wb_data/rd/valid"]
    end

    FETCH -->|"fe_pc[63:0]<br/>fe_instr[31:0]<br/>fe_valid"| DECODE
    DECODE -->|"de_pc, de_rs1/rs2[63:0]<br/>de_imm, de_rd[4:0]<br/>de_aluop, de_f3/f7/op<br/>de_memr/w, de_regw<br/>de_branch/jal/jalr<br/>de_iscsr, de_csrop<br/>de_ecall/ebreak/mret"| EXECUTE
    EXECUTE -->|"ex_alures[63:0]<br/>ex_rs2, ex_rd[4:0]<br/>ex_memr/w, ex_regw"| MEM
    MEM -->|"mem_result[63:0]<br/>mem_rd[4:0]<br/>mem_regw, mem_valid"| WB

    MEM -.->|"fwd_mem_data[63:0]<br/>fwd_mem_rd, fwd_mem_valid"| EXECUTE
    WB -.->|"fwd_wb_data[63:0]<br/>fwd_wb_rd, fwd_wb_valid"| EXECUTE
    WB -.->|"wb_data[63:0]<br/>wb_rd[4:0], wb_we"| DECODE
    EXECUTE -->|"branch_taken<br/>branch_target[63:0]"| FETCH

    classDef fetchS fill:#74b9ff,stroke:#0984e3,stroke-width:2px,color:#2d3436
    classDef decodeS fill:#81ecec,stroke:#00cec9,stroke-width:2px,color:#2d3436
    classDef execS fill:#ffeaa7,stroke:#fdcb6e,stroke-width:2px,color:#2d3436
    classDef memS fill:#fab1a0,stroke:#e17055,stroke-width:2px,color:#2d3436
    classDef wbS fill:#a29bfe,stroke:#6c5ce7,stroke-width:2px,color:#fff

    class FETCH,BPU,ICACHE fetchS
    class DECODE,REGFILE decodeS
    class EXECUTE,CSR,FPU execS
    class MEM,DCACHE memS
    class WB wbS
```

---

### Diagram 3 — Hazard Control & MMU Subsystem (inside rv_core_top.v)

```mermaid
graph TB
    subgraph HAZARD["Hazard & Pipeline Control"]
        STALL["stall = mul_div_stall<br/>|| mem_stall || halt_req"]
        FLUSH["flush = branch_taken<br/>|| exception"]
        BUFX4["buf_macros.v (BUFX4×2)<br/>High-fanout flush buffers"]
        FLUSH --> BUFX4
    end

    subgraph MMU["MMU Subsystem"]
        rv_mmu["rv_mmu.v<br/>• Sv39 VA→PA<br/>• satp.MODE select"]
        rv_tlb["rv_tlb.v<br/>• 64-entry FA<br/>• ASID tagging<br/>• sfence.vma flush"]
        rv_ptw["rv_ptw.v<br/>• 3-level walk (L2→L1→L0)<br/>• AXI read for PTE"]
        rv_pmp["rv_pmp.v<br/>• 16 PMP entries<br/>• TOR/NAPOT/NA4<br/>• R/W/X permissions"]
        rv_mmu --> rv_tlb
        rv_mmu --> rv_ptw
        rv_mmu --> rv_pmp
        rv_ptw -->|"TLB fill (VPN→PPN)"| rv_tlb
    end

    EX_STAGE["rv_execute"] -->|"mul_div_stall"| STALL
    MEM_STAGE["rv_mem"] -->|"mem_stall"| STALL
    DEBUG["rv_debug.v<br/>halt_req"] -->|"halt_req"| STALL

    STALL -->|"stall"| FETCH_S["rv_fetch"]
    STALL -->|"stall"| DECODE_S["rv_decode"]
    STALL -->|"stall_ex (no self-loop)"| EX_STAGE
    BUFX4 -->|"flush_de_1"| DECODE_S
    BUFX4 -->|"flush_de_4"| EX_STAGE

    FETCH_S -.->|"va[63:0]"| rv_mmu
    MEM_STAGE -.->|"va[63:0]"| rv_mmu

    classDef hazN fill:#ff7675,stroke:#d63031,stroke-width:2px,color:#fff
    classDef mmuN fill:#fd79a8,stroke:#e84393,stroke-width:2px,color:#fff
    classDef pipeN fill:#74b9ff,stroke:#0984e3,stroke-width:2px,color:#2d3436

    class STALL,FLUSH,BUFX4 hazN
    class rv_mmu,rv_tlb,rv_ptw,rv_pmp mmuN
    class EX_STAGE,MEM_STAGE,FETCH_S,DECODE_S,DEBUG pipeN
```

---

### Diagram 4 — AXI4 Interconnect Fabric & Master Connections

```mermaid
graph TB
    subgraph MASTERS["AXI4 Masters (15)"]
        M0["M0: Core 0 rv_fetch<br/>(imem AR/R, read-only)"]
        M1["M1: Core 1 rv_fetch"]
        M2["M2: Core 2 rv_fetch"]
        M3["M3: Core 3 rv_fetch"]
        M4["M4: Core 0 rv_mem<br/>(dmem AW/W/B/AR/R)"]
        M5["M5: Core 1 rv_mem"]
        M6["M6: Core 2 rv_mem"]
        M7["M7: Core 3 rv_mem"]
        M8["M8: Monitor imem (RO)"]
        M9["M9: Monitor dmem (WO)"]
        M10["M10: gem_ethernet DMA"]
        M11["M11: pcie_top DMA"]
        M12["M12: usb_otg DMA"]
        M13["M13: Tied off"]
        M14["M14: Tied off"]
    end

    subgraph FABRIC["AXI4 Interconnect Fabric"]
        QOS["qos_controller.v<br/>• Per-master QoS<br/>• Bandwidth throttle<br/>• cfg_base/boost_qos"]
        MPU["mpu.v<br/>• 16 address regions<br/>• Per-master permission<br/>• Fault DECERR"]
        B2L["axi4_burst_to_lite.v<br/>• Burst→single-beat<br/>• INCR/WRAP→FIXED"]
        ARB["mmu_arbiter.v<br/>• 5-port round-robin<br/>• PTW request merge"]
        XBAR["axi4_crossbar.v<br/>━━━━━━━━━━━━━━━━<br/>• 15M × 9S switch<br/>• Address decoder<br/>• Round-robin arbiter<br/>• Per-port FIFOs<br/>• DECERR responder"]
        QOS --> XBAR
        MPU --> XBAR
        B2L --> XBAR
    end

    subgraph SLAVES["AXI4 Slaves (9)"]
        S0["S0: L2→DDR (0x8000_0000)"]
        S1["S1: AXI→AHB→APB (0x1000_0000)"]
        S2["S2: Boot ROM (0x1000_0000, RO)"]
        S3_8["S3-S8: Tied off (DECERR)"]
    end

    M0 & M1 & M2 & M3 -->|"arvalid/araddr[39:0]<br/>rdata[63:0]/rvalid"| XBAR
    M4 & M5 & M6 & M7 -->|"awvalid/awaddr/wdata[63:0]<br/>wstrb[7:0]/arvalid/araddr"| XBAR
    M8 & M9 -->|"imem AR/R, dmem AW/W"| XBAR
    M10 & M11 & M12 -->|"Full AXI4 AW/W/B/AR/R"| XBAR
    XBAR --> S0 & S1 & S2 & S3_8

    classDef masterN fill:#74b9ff,stroke:#0984e3,stroke-width:2px,color:#2d3436
    classDef fabricN fill:#fab1a0,stroke:#e17055,stroke-width:2px,color:#2d3436
    classDef slaveN fill:#a29bfe,stroke:#6c5ce7,stroke-width:2px,color:#fff

    class M0,M1,M2,M3,M4,M5,M6,M7,M8,M9 masterN
    class M10,M11,M12 masterN
    class M13,M14 masterN
    class QOS,MPU,B2L,ARB,XBAR fabricN
    class S0,S1,S2,S3_8 slaveN
```

---

### Diagram 5 — Memory Subsystem (Slave 0)

```mermaid
graph TB
    XBAR_S0(["From AXI Crossbar S0<br/>awvalid/awaddr/awid<br/>wvalid/wdata/wstrb<br/>arvalid/araddr/arid"])

    subgraph L2["L2 Cache — l2_cache_top.v"]
        l2_ctrl["l2_cache_ctrl.v<br/>• Hit/miss FSM<br/>• Line fill control<br/>• Eviction policy<br/>• Writeback buffer"]
        l2_tag["l2_tag_array.v<br/>• Tag + valid + dirty<br/>• 28-bit tag, 64 sets<br/>• Parity protection"]
        l2_data["l2_data_array.v<br/>• Data SRAM banks<br/>• Read/write port<br/>• Bank interleave"]
        l2_snoop["l2_snoop_filter.v<br/>• Coherence tracker<br/>• Sharers bitmap[3:0]<br/>• Snoop hit/miss<br/>• MOESI directory"]
        l2_ctrl -->|"tag_rd/wr, tag_addr<br/>tag_din[27:0]"| l2_tag
        l2_ctrl -->|"data_rd/wr<br/>data_addr, data_din"| l2_data
        l2_ctrl -->|"snoop_req, snoop_addr"| l2_snoop
        l2_tag -->|"tag_hit, tag_dout"| l2_ctrl
        l2_data -->|"data_dout, data_valid"| l2_ctrl
        l2_snoop -->|"snoop_hit, sharers[3:0]"| l2_ctrl
    end

    subgraph DDR["DDR4 Controller — ddr_ctrl_top.v"]
        ddr_sched["ddr_scheduler.v<br/>• Command queue<br/>• Bank state FSM (8 banks)<br/>• Open-page policy<br/>• tRCD/tRP/tRAS timing"]
        ddr_phy["ddr_phy_if.v<br/>• DFI → PHY timing<br/>• DQS strobe gen<br/>• Read/write leveling"]
        ddr_sched -->|"dfi_cs/ras/cas/we_n<br/>dfi_bank/bg/addr<br/>dfi_wrdata[63:0]"| ddr_phy
        ddr_phy -->|"dfi_rddata[63:0]<br/>dfi_rddata_valid"| ddr_sched
    end

    subgraph SRAM["SRAM Macros (SCL 180nm)"]
        sram32["sram_32x64_180nm.v<br/>• 32×64-bit, 1-port"]
        sram512["sram_512kx8_180nm.v<br/>• 512K×8-bit, 1-port"]
    end

    DDR_PADS(["DDR4 Pads<br/>ddr_addr[15:0], ddr_ba[2:0]<br/>ddr_dq[63:0] ↔ ddr_dqs_p/n"])

    XBAR_S0 -->|"AXI4 Slave port"| L2
    L2 -->|"AXI4 Master: evict/refill"| DDR
    l2_data --> sram32 & sram512
    l2_tag --> sram32
    ddr_phy --> DDR_PADS

    classDef l2N fill:#a29bfe,stroke:#6c5ce7,stroke-width:2px,color:#fff
    classDef ddrN fill:#6c5ce7,stroke:#341f97,stroke-width:2px,color:#fff
    classDef sramN fill:#dfe6e9,stroke:#b2bec3,stroke-width:2px,color:#2d3436

    class l2_ctrl,l2_tag,l2_data,l2_snoop l2N
    class ddr_sched,ddr_phy ddrN
    class sram32,sram512 sramN
```

---

### Diagram 6 — Bridge Chain & APB Peripheral Bus (Slave 1)

```mermaid
graph TB
    XBAR_S1(["From AXI Crossbar S1"])

    subgraph BRIDGE["Bridge Chain"]
        u_axi2ahb["axi4_to_ahb.v<br/>• AXI4→AHB-Lite<br/>• haddr/hwdata/htrans"]
        ahb2apb["ahb_to_apb.v<br/>• AHB→APB<br/>• paddr=haddr<br/>• psel=htrans[1]"]
        apb_br["apb_bridge.v<br/>• APB space manager<br/>• Multi-periph mux"]
        apb_dec["APB Address Decoder<br/>17 psel signals"]
        prdata_mux["prdata_mux<br/>17-input read mux"]
    end

    XBAR_S1 --> u_axi2ahb
    u_axi2ahb -->|"haddr/hwdata/hwrite/htrans"| ahb2apb
    ahb2apb -->|"paddr/pwdata/psel/penable/pwrite"| apb_br --> apb_dec
    prdata_mux -->|"hrdata[31:0]"| u_axi2ahb

    subgraph UARTS["UART × 5"]
        u0["uart_16550 u_uart0<br/>0x10000, IRQ[20]"]
        u1["uart_16550 u_uart1<br/>0x10001, IRQ[21]"]
        u2["uart_16550 u_uart2<br/>0x10002, IRQ[22]"]
        u3["uart_16550 u_uart3<br/>0x10003, IRQ[23]"]
        u4["uart_16550 u_uart4<br/>0x10004, IRQ[24]"]
    end

    subgraph CANS["CAN × 2"]
        can0["can_controller u_can0<br/>0x30000, IRQ[25]"]
        can1["can_controller u_can1<br/>0x30001, IRQ[26]"]
    end

    rtc_inst["rtc.v @ 0x10010<br/>• 64-bit mtime<br/>• 5× mtimecmp<br/>• timer_irq[4:0]"]
    gpio_inst["gpio_ctrl.v<br/>• 32-bit GPIO<br/>• Per-pin IRQ"]
    i2c_inst["i2c_master.v<br/>• SCL/SDA open-drain<br/>• 7/10-bit addr"]
    spi_inst["spi_master.v<br/>• Mode 0-3<br/>• 4 chip selects"]
    wdt_inst["watchdog_timer.v<br/>• Windowed WDT<br/>• wdt_reset_n"]

    apb_dec -->|"psel_uart0..4"| UARTS
    apb_dec -->|"psel_can0/1"| CANS
    apb_dec -->|"psel_rtc"| rtc_inst
    apb_dec --> gpio_inst & i2c_inst & spi_inst & wdt_inst

    UARTS & CANS & rtc_inst & gpio_inst & i2c_inst & spi_inst & wdt_inst -->|"prdata"| prdata_mux

    IO_UART(["uart_rx/tx[4:0]"])
    IO_CAN(["can_rx/tx[1:0]"])
    IO_RTC(["rtc_clk"])
    UARTS --> IO_UART
    CANS --> IO_CAN
    IO_RTC --> rtc_inst

    classDef brN fill:#fab1a0,stroke:#e17055,stroke-width:2px,color:#2d3436
    classDef perN fill:#55efc4,stroke:#00b894,stroke-width:2px,color:#2d3436
    classDef ioN fill:#dfe6e9,stroke:#b2bec3,stroke-width:2px,color:#2d3436

    class u_axi2ahb,ahb2apb,apb_br,apb_dec,prdata_mux brN
    class u0,u1,u2,u3,u4,can0,can1,rtc_inst,gpio_inst,i2c_inst,spi_inst,wdt_inst perN
    class IO_UART,IO_CAN,IO_RTC ioN
```

---

### Diagram 7 — Security Subsystem, DMA Masters & Video Pipeline

```mermaid
graph TB
    subgraph SEC["🔒 Security Subsystem (APB)"]
        u_drbg["drbg.v @ 0x20000<br/>• CTR-DRBG (NIST)<br/>• AES-256 core<br/>• IRQ → PLIC[10]"]
        u_aes["aes_engine.v @ 0x20010<br/>• AES-128/192/256<br/>• ECB/CBC/CTR<br/>• IRQ → PLIC[11]"]
        u_envm["envm_ctrl.v @ 0x20020<br/>• eNVM flash ctrl<br/>• Program/erase/read"]
        u_sha256["sha256_engine.v<br/>• 64-round compression<br/>• 256-bit digest"]
        u_trng["trng.v<br/>• Ring oscillator<br/>• Von Neumann debias<br/>• NIST SP 800-90B"]
        u_ecdsa["ecdsa_engine.v<br/>• P-256 curve<br/>• Sign/verify"]
        u_secboot["secure_boot.v @ 0x20030<br/>• SHA-256 image verify<br/>• boot_pass/fail"]
        u_trng -->|"trng_entropy[127:0]<br/>trng_valid"| u_drbg
        u_secboot -->|"envm_addr[31:0]<br/>envm_req"| u_envm
        u_envm -->|"envm_rdata[31:0]<br/>envm_valid"| u_secboot
    end

    subgraph DMA["⚡ DMA Masters"]
        u_gem["gem_ethernet.v<br/>• GbE MAC (802.3)<br/>• Scatter-gather DMA<br/>• M10, IRQ[27]"]
        u_sgmii["gem_sgmii_pcs.v<br/>• 8b/10b encode<br/>• Auto-negotiation"]
        u_pcie["pcie_top.v<br/>• PCIe Gen2 x1<br/>• TLP engine<br/>• M11"]
        u_pipe["pcie_pipe_if.v<br/>• PIPE PHY I/F<br/>• TX/RX data lanes"]
        u_usb["usb_otg.v<br/>• USB 2.0 OTG<br/>• Host+Device<br/>• M12, IRQ[28]"]
        u_gem --> u_sgmii
        u_pcie --> u_pipe
    end

    subgraph VID["🎬 Video Pipeline"]
        u_mipi["mipi_csi2_rx.v @ 0x10040<br/>• 4-lane D-PHY<br/>• Packet decoder"]
        u_isp["isp_pipeline.v @ 0x10050<br/>• Bayer demosaic<br/>• White balance<br/>• Gamma, NR"]
        u_hdmi["hdmi_ctrl.v @ 0x10060<br/>• TMDS 8b/10b<br/>• Video timing gen"]
        u_vdma["vdma.v<br/>• Frame buffer R/W<br/>• Triple buffer<br/>• AXI4 master"]
        u_mipi -->|"m_axis_tdata[31:0]<br/>tvalid/tlast/tuser"| u_isp
        u_isp -->|"m_axis_tdata[31:0]<br/>tvalid/tlast"| u_hdmi
        u_vdma -.->|"Frame buffer DMA"| u_isp
    end

    subgraph STOR["💿 Storage"]
        u_mmc["mmc_controller.v<br/>• eMMC/SD<br/>• HS200/HS400<br/>• AXI4 DMA master"]
        u_qspi["qspi_controller.v<br/>• Quad-SPI flash<br/>• XIP mode<br/>• AXI4-Lite slave"]
    end

    APB_BUS(["APB Bus<br/>psel/paddr/pwdata"])
    AXI_XBAR(["AXI4 Crossbar"])
    HDMI_PAD(["HDMI tmds_clk/data_p/n"])
    MIPI_PAD(["mipi_rxbyteclkhs"])
    ETH_PAD(["eth_tx/rx_clk"])
    PCIE_PAD(["pipe_clk"])
    USB_PAD(["ulpi_clk"])

    APB_BUS --> SEC & VID
    u_gem & u_pcie & u_usb -->|"M10-M12: AXI4"| AXI_XBAR
    APB_BUS --> u_gem & u_usb
    u_hdmi --> HDMI_PAD
    MIPI_PAD --> u_mipi
    ETH_PAD --> u_gem
    PCIE_PAD --> u_pipe
    USB_PAD --> u_usb

    classDef secN fill:#fd79a8,stroke:#e84393,stroke-width:2px,color:#fff
    classDef dmaN fill:#00cec9,stroke:#00b894,stroke-width:2px,color:#2d3436
    classDef vidN fill:#fdcb6e,stroke:#e17055,stroke-width:2px,color:#2d3436
    classDef storN fill:#e17055,stroke:#d63031,stroke-width:2px,color:#fff
    classDef ioN fill:#dfe6e9,stroke:#b2bec3,stroke-width:2px,color:#2d3436

    class u_drbg,u_aes,u_envm,u_sha256,u_trng,u_ecdsa,u_secboot secN
    class u_gem,u_sgmii,u_pcie,u_pipe,u_usb dmaN
    class u_mipi,u_isp,u_hdmi,u_vdma vidN
    class u_mmc,u_qspi storN
    class APB_BUS,AXI_XBAR,HDMI_PAD,MIPI_PAD,ETH_PAD,PCIE_PAD,USB_PAD ioN
```

---

### Diagram 8 — Interrupt Controllers & Common Utilities

```mermaid
graph TB
    subgraph IRQ["🚨 Interrupt Controllers"]
        u_plic["plic.v<br/>━━━━━━━━━━━━━━<br/>• 186 interrupt sources<br/>• 10 contexts (5 harts × M/S)<br/>• Priority 1-7 + threshold<br/>• Claim/complete protocol<br/>• irq_targets[9:0] output"]
        u_clint["clint.v<br/>━━━━━━━━━━━━━━<br/>• 5× msip registers<br/>• 64-bit mtime counter<br/>• 5× mtimecmp[63:0]<br/>• msip[4:0], mtip[4:0] output"]
    end

    u0_irq(["uart0 → PLIC[20]"])
    u1_irq(["uart1 → PLIC[21]"])
    u2_irq(["uart2 → PLIC[22]"])
    u3_irq(["uart3 → PLIC[23]"])
    u4_irq(["uart4 → PLIC[24]"])
    can0_irq(["can0 → PLIC[25]"])
    can1_irq(["can1 → PLIC[26]"])
    gem_irq(["gem → PLIC[27]"])
    usb_irq(["usb → PLIC[28]"])
    drbg_irq(["drbg → PLIC[10]"])
    aes_irq(["aes → PLIC[11]"])

    u0_irq & u1_irq & u2_irq & u3_irq & u4_irq --> u_plic
    can0_irq & can1_irq --> u_plic
    gem_irq & usb_irq --> u_plic
    drbg_irq & aes_irq --> u_plic

    Core0(["Core 0"])
    Core1(["Core 1"])
    Core2(["Core 2"])
    Core3(["Core 3"])
    Monitor(["Monitor Core"])

    u_plic -->|"irq_m_ext[0]"| Core0
    u_plic -->|"irq_m_ext[1]"| Core1
    u_plic -->|"irq_m_ext[2]"| Core2
    u_plic -->|"irq_m_ext[3]"| Core3
    u_plic -->|"irq_m_ext[4]"| Monitor

    RTC_T(["rtc timer_irq"])
    RTC_T -->|"timer_irq[0-4]"| Core0 & Core1 & Core2 & Core3 & Monitor

    u_clint -->|"sw_irq[0]"| Core0
    u_clint -->|"sw_irq[1]"| Core1
    u_clint -->|"sw_irq[2]"| Core2
    u_clint -->|"sw_irq[3]"| Core3
    u_clint -->|"sw_irq[4]"| Monitor

    subgraph COMMON["🔧 Common Utility Modules"]
        fifo_sync["fifo_sync.v<br/>• Parameterized depth<br/>• Used in UART, SPI, AXI queues"]
        fifo_async["fifo_async.v<br/>• Gray-code pointers<br/>• CDC-safe<br/>• Used in USB, GbE, MIPI"]
        cdc_sync["cdc_sync.v<br/>• N-FF synchronizer<br/>• Used across all CDC"]
        reset_sync["reset_sync.v<br/>• 2-FF async→sync<br/>• Per-domain reset"]
        bufx4["buf_macros.v (BUFX4)<br/>• SCL 180nm wrapper<br/>• Used for flush nets"]
        stdcell["stdcell_stubs.v<br/>• Simulation models<br/>• BUFX4, CLKBUF stubs"]
    end

    classDef irqN fill:#ff7675,stroke:#d63031,stroke-width:2px,color:#fff
    classDef comN fill:#b2bec3,stroke:#636e72,stroke-width:2px,color:#2d3436
    classDef coreN fill:#74b9ff,stroke:#0984e3,stroke-width:2px,color:#2d3436
    classDef srcN fill:#dfe6e9,stroke:#b2bec3,stroke-width:1px,color:#2d3436

    class u_plic,u_clint irqN
    class fifo_sync,fifo_async,cdc_sync,reset_sync,bufx4,stdcell comN
    class Core0,Core1,Core2,Core3,Monitor coreN
    class u0_irq,u1_irq,u2_irq,u3_irq,u4_irq,can0_irq,can1_irq,gem_irq,usb_irq,drbg_irq,aes_irq,RTC_T srcN
```

---

## 📂 Complete Module Directory Map (71 Modules)

| # | Category | Module | File | Description |
|---|----------|--------|------|-------------|
| 1 | **Top** | `titan_x_top` | [`titan_x_top.v`](top/titan_x_top/) | SoC top-level integration |
| 2 | **Top** | `axi_rom` | [`axi_rom.v`](top/axi_rom/) | Boot ROM (AXI slave, firmware.hex) |
| 3 | **Frontend** | `rv_fetch` | [`rv_fetch.v`](frontend/rv_fetch/) | Instruction fetch + PC gen + redirect drain |
| 4 | **Frontend** | `rv_decode` | [`rv_decode.v`](frontend/rv_decode/) | Decode + immediate gen + CSR decode |
| 5 | **Frontend** | `rv_bpu` | [`rv_bpu.v`](frontend/rv_bpu/) | Branch predictor (tournament, 2K BHT, GHR, RAS) |
| 6 | **Frontend** | `rv_icache` | [`rv_icache.v`](frontend/rv_icache/) | 32KB 8-way I-cache, SECDED ECC, AXI refill |
| 7 | **Backend** | `rv_core_top` | [`rv_core_top.v`](backend/rv_core_top/) | Core pipeline integration (5-stage spine) |
| 8 | **Backend** | `rv_execute` | [`rv_execute.v`](backend/rv_execute/) | ALU + MUL/DIV (M-ext) + AMO (A-ext) + branch |
| 9 | **Backend** | `rv_mem` | [`rv_mem.v`](backend/rv_mem/) | Memory stage (AXI data, load/store) |
| 10 | **Backend** | `rv_writeback` | [`rv_writeback.v`](backend/rv_writeback/) | Writeback + forwarding output |
| 11 | **Backend** | `rv_csr` | [`rv_csr.v`](backend/rv_csr/) | CSR unit (M/S/U modes, trap vectoring) |
| 12 | **Backend** | `rv_regfile` | [`rv_regfile.v`](backend/rv_regfile/) | 32×64-bit register file (2R1W) |
| 13 | **Backend** | `rv_fpu` | [`rv_fpu.v`](backend/rv_fpu/) | Floating-point unit (F/D-ext) |
| 14 | **Backend** | `rv_debug` | [`rv_debug.v`](backend/rv_debug/) | Debug module (JTAG DTM, halt/resume) |
| 15 | **Backend** | `rv_mmu` | [`rv_mmu.v`](backend/rv_mmu/) | MMU top (Sv39 VA→PA translation) |
| 16 | **Backend** | `rv_tlb` | [`rv_tlb.v`](backend/rv_tlb/) | TLB (64-entry, fully-associative, ASID) |
| 17 | **Backend** | `rv_ptw` | [`rv_ptw.v`](backend/rv_ptw/) | Page table walker (3-level Sv39) |
| 18 | **Backend** | `rv_pmp` | [`rv_pmp.v`](backend/rv_pmp/) | Physical memory protection (16 entries) |
| 19 | **Backend** | `rv_dcache` | [`rv_dcache.v`](backend/rv_dcache/) | 32KB 8-way D-cache, write-back, PLRU |
| 20 | **Backend** | `rv_monitor_core` | [`rv_monitor_core.v`](backend/rv_monitor_core/) | Monitor core (RV64IMAC, reduced pipeline) |
| 21 | **Backend** | `clint` | [`clint.v`](backend/clint/) | Core-local interruptor (msip, mtime) |
| 22 | **Backend** | `plic` | [`plic.v`](backend/plic/) | Platform-level interrupt ctrl (32 sources) |
| 23 | **Interconnect** | `axi4_crossbar` | [`axi4_crossbar.v`](interconnect/axi4_crossbar/) | 15M×9S AXI4 crossbar |
| 24 | **Interconnect** | `axi4_to_ahb` | [`axi4_to_ahb.v`](interconnect/axi4_to_ahb/) | AXI4 → AHB-Lite bridge |
| 25 | **Interconnect** | `ahb_to_apb` | [`ahb_to_apb.v`](interconnect/ahb_to_apb/) | AHB → APB bridge |
| 26 | **Interconnect** | `apb_bridge` | [`apb_bridge.v`](interconnect/apb_bridge/) | APB peripheral bridge |
| 27 | **Interconnect** | `axi4_burst_to_lite` | [`axi4_burst_to_lite.v`](interconnect/) | Burst → single-beat converter |
| 28 | **Interconnect** | `mpu` | [`mpu.v`](interconnect/interconnect_mpu/) | Interconnect MPU (address protection) |
| 29 | **Interconnect** | `mmu_arbiter` | [`mmu_arbiter.v`](interconnect/mmu_arbiter/) | Multi-core MMU request arbiter |
| 30 | **Interconnect** | `qos_controller` | [`qos_controller.v`](interconnect/qos_controller/) | QoS controller (bandwidth management) |
| 31 | **Memory** | `ddr_ctrl_top` | [`ddr_ctrl_top.v`](memory/ddr_ctrl_top/) | DDR4 controller top |
| 32 | **Memory** | `ddr_scheduler` | [`ddr_scheduler.v`](memory/ddr_scheduler/) | DDR command scheduler (bank FSM) |
| 33 | **Memory** | `ddr_phy_if` | [`ddr_phy_if.v`](memory/ddr_phy_if/) | DDR PHY interface (DFI, leveling) |
| 34 | **Memory** | `l2_cache_top` | [`l2_cache_top.v`](memory/l2_cache_top/) | L2 cache top integration |
| 35 | **Memory** | `l2_cache_ctrl` | [`l2_cache_ctrl.v`](memory/l2_cache_ctrl/) | L2 cache controller (FSM, hit/miss) |
| 36 | **Memory** | `l2_tag_array` | [`l2_tag_array.v`](memory/l2_tag_array/) | L2 tag array (valid/dirty bits) |
| 37 | **Memory** | `l2_data_array` | [`l2_data_array.v`](memory/l2_data_array/) | L2 data array (SRAM banks) |
| 38 | **Memory** | `l2_snoop_filter` | [`l2_snoop_filter.v`](memory/l2_snoop_filter/) | L2 snoop filter (coherence tracker) |
| 39 | **Memory** | `sram_32x64_180nm` | [`sram_32x64_180nm.v`](memory/sram_32x64_180nm/) | SRAM macro 32×64 (SCL 180nm) |
| 40 | **Memory** | `sram_512kx8_180nm` | [`sram_512kx8_180nm.v`](memory/sram_512kx8_180nm/) | SRAM macro 512K×8 (SCL 180nm) |
| 41 | **Peripherals** | `uart_16550` | [`uart_16550.v`](peripherals/uart_16550/) | UART 16550 (×5 instances, IrDA/LIN) |
| 42 | **Peripherals** | `spi_master` | [`spi_master.v`](peripherals/spi_master/) | SPI master (mode 0-3, configurable) |
| 43 | **Peripherals** | `i2c_master` | [`i2c_master.v`](peripherals/i2c_master/) | I²C master (7/10-bit addr, multi-master) |
| 44 | **Peripherals** | `gpio_ctrl` | [`gpio_ctrl.v`](peripherals/gpio_ctrl/) | 32-bit GPIO controller |
| 45 | **Peripherals** | `rtc` | [`rtc.v`](peripherals/rtc/) | Real-time clock (mtime, 5× mtimecmp) |
| 46 | **Peripherals** | `watchdog_timer` | [`watchdog_timer.v`](peripherals/watchdog_timer/) | Windowed watchdog timer |
| 47 | **Peripherals** | `can_controller` | [`can_controller.v`](peripherals/can_controller/) | CAN 2.0B controller (×2 instances) |
| 48 | **Peripherals** | `aes_engine` | [`aes_engine.v`](peripherals/aes_engine/) | AES-128/256 crypto engine |
| 49 | **Peripherals** | `sha256_engine` | [`sha256_engine.v`](peripherals/sha256_engine/) | SHA-256 hash engine |
| 50 | **Peripherals** | `trng` | [`trng.v`](peripherals/trng/) | True random number generator |
| 51 | **Peripherals** | `gem_ethernet` | [`gem_ethernet.v`](peripherals/gem_ethernet/) | GbE MAC + scatter-gather DMA |
| 52 | **Peripherals** | `gem_sgmii_pcs` | [`gem_sgmii_pcs.v`](peripherals/gem_sgmii_pcs/) | SGMII PCS (8b/10b, auto-neg) |
| 53 | **Peripherals** | `pcie_top` | [`pcie_top.v`](peripherals/pcie_top/) | PCIe Gen2 x1 controller + DMA |
| 54 | **Peripherals** | `pcie_pipe_if` | [`pcie_pipe_if.v`](peripherals/pcie_pipe_if/) | PCIe PIPE PHY interface |
| 55 | **Security** | `secure_boot` | [`secure_boot.v`](security/secure_boot/) | Secure boot validator (SHA-256 verify) |
| 56 | **Security** | `drbg` | [`drbg.v`](security/drbg/) | CTR-DRBG (NIST SP 800-90A) |
| 57 | **Security** | `ecdsa_engine` | [`ecdsa_engine.v`](security/ecdsa_engine/) | ECDSA P-256 signature engine |
| 58 | **Security** | `envm_ctrl` | [`envm_ctrl.v`](security/envm_ctrl/) | eNVM flash controller |
| 59 | **Storage** | `mmc_controller` | [`mmc_controller.v`](storage/mmc_controller/) | eMMC/SD controller (HS200/HS400) |
| 60 | **Storage** | `qspi_controller` | [`qspi_controller.v`](storage/qspi_controller/) | Quad-SPI flash (XIP, 4 CS) |
| 61 | **Storage** | `usb_otg` | [`usb_otg.v`](storage/usb_otg/) | USB 2.0 OTG (host+device, DMA) |
| 62 | **Video** | `hdmi_ctrl` | [`hdmi_ctrl.v`](video/hdmi_ctrl/) | HDMI 1.4 TMDS encoder |
| 63 | **Video** | `isp_pipeline` | [`isp_pipeline.v`](video/isp_pipeline/) | Image signal processor (demosaic, WB, gamma) |
| 64 | **Video** | `mipi_csi2_rx` | [`mipi_csi2_rx.v`](video/mipi_csi2_rx/) | MIPI CSI-2 receiver (4-lane D-PHY) |
| 65 | **Video** | `vdma` | [`vdma.v`](video/vdma/) | Video DMA engine (frame buffer) |
| 66 | **Common** | `cdc_sync` | [`cdc_sync.v`](common/cdc_sync/) | N-FF clock-domain crossing sync |
| 67 | **Common** | `fifo_async` | [`fifo_async.v`](common/fifo_async/) | Async FIFO (Gray-code pointers) |
| 68 | **Common** | `fifo_sync` | [`fifo_sync.v`](common/fifo_sync/) | Synchronous FIFO (parameterized) |
| 69 | **Common** | `reset_sync` | [`reset_sync.v`](common/reset_sync/) | 2-FF async reset synchronizer |
| 70 | **Common** | `buf_macros` | [`buf_macros.v`](common/BUFX4/) | BUFX4 standard cell wrapper |
| 71 | **Common** | `stdcell_stubs` | [`stdcell_stubs.v`](includes/) | Standard cell simulation stubs |

---

## 🗺 AXI4 Crossbar Port Map

### Masters (15)
| Port | Module | Instance | Bus Type | Signal Widths |
|------|--------|----------|----------|---------------|
| M0 | rv_core_top #0 → rv_fetch | gen_cores[0].u_core | Instruction (AR/R only) | araddr[39:0], rdata[63:0] |
| M1 | rv_core_top #1 → rv_fetch | gen_cores[1].u_core | Instruction (AR/R only) | araddr[39:0], rdata[63:0] |
| M2 | rv_core_top #2 → rv_fetch | gen_cores[2].u_core | Instruction (AR/R only) | araddr[39:0], rdata[63:0] |
| M3 | rv_core_top #3 → rv_fetch | gen_cores[3].u_core | Instruction (AR/R only) | araddr[39:0], rdata[63:0] |
| M4 | rv_core_top #0 → rv_mem | gen_cores[0].u_core | Data (AW/W/B/AR/R) | awaddr[39:0], wdata[63:0], wstrb[7:0] |
| M5 | rv_core_top #1 → rv_mem | gen_cores[1].u_core | Data (AW/W/B/AR/R) | awaddr[39:0], wdata[63:0], wstrb[7:0] |
| M6 | rv_core_top #2 → rv_mem | gen_cores[2].u_core | Data (AW/W/B/AR/R) | awaddr[39:0], wdata[63:0], wstrb[7:0] |
| M7 | rv_core_top #3 → rv_mem | gen_cores[3].u_core | Data (AW/W/B/AR/R) | awaddr[39:0], wdata[63:0], wstrb[7:0] |
| M8 | rv_monitor_core | u_monitor | Instruction (AR/R only) | araddr[39:0], rdata[63:0] |
| M9 | rv_monitor_core | u_monitor | Data (AW/W/B only) | awaddr[39:0], wdata[63:0] |
| M10 | gem_ethernet | u_gem | DMA (AW/W/B/AR/R) | Full AXI4 |
| M11 | pcie_top | u_pcie | DMA (AW/W/B/AR/R) | Full AXI4 |
| M12 | usb_otg | u_usb | DMA (AW/W/B/AR/R) | Full AXI4 |
| M13 | *Tied off* | — | Reserved | All signals grounded |
| M14 | *Tied off* | — | Reserved | All signals grounded |

### Slaves (9)
| Port | Module | Instance | Address Range | Access |
|------|--------|----------|---------------|--------|
| S0 | ddr_ctrl_top (via L2 cache) | u_ddr_ctrl | `0x8000_0000_0000_0000` | Full R/W |
| S1 | axi4_to_ahb → APB peripherals | u_axi2ahb | `0x0000_0000_1000_0000` | Full R/W |
| S2 | axi_rom (Boot ROM) | u_boot_rom | `0x0000_0000_1000_0000` | Read-only |
| S3 | *Tied off (reserved)* | — | — | DECERR |
| S4 | *Tied off (reserved)* | — | — | DECERR |
| S5 | *Tied off (reserved)* | — | — | DECERR |
| S6 | *Tied off (reserved)* | — | — | DECERR |
| S7 | *Tied off (reserved)* | — | — | DECERR |
| S8 | *Tied off (reserved)* | — | — | DECERR |

---

## 🔐 APB Address Map

| Base Address | Peripheral | Instance | IRQ | Description |
|-------------|------------|----------|-----|-------------|
| `0x10000_000` | uart_16550 | u_uart0 | PLIC[20] | UART channel 0 |
| `0x10001_000` | uart_16550 | u_uart1 | PLIC[21] | UART channel 1 |
| `0x10002_000` | uart_16550 | u_uart2 | PLIC[22] | UART channel 2 |
| `0x10003_000` | uart_16550 | u_uart3 | PLIC[23] | UART channel 3 |
| `0x10004_000` | uart_16550 | u_uart4 | PLIC[24] | UART channel 4 |
| `0x10010_000` | rtc | u_rtc | timer_irq[4:0] | Real-time clock |
| `0x10020_000` | gem_ethernet | u_gem (config) | PLIC[27] | GbE MAC config |
| `0x10030_000` | usb_otg | u_usb (config) | PLIC[28] | USB OTG config |
| `0x10040_000` | mipi_csi2_rx | u_mipi | — | MIPI CSI-2 config |
| `0x10050_000` | isp_pipeline | u_isp | — | ISP config |
| `0x10060_000` | hdmi_ctrl | u_hdmi | — | HDMI config |
| `0x20000_000` | drbg | u_drbg | PLIC[10] | CTR-DRBG PRNG |
| `0x20010_000` | aes_engine | u_aes | PLIC[11] | AES crypto |
| `0x20020_000` | envm_ctrl | u_envm | — | eNVM controller |
| `0x20030_000` | secure_boot | u_secure_boot | — | Boot validator |
| `0x30000_000` | can_controller | u_can0 | PLIC[25] | CAN bus 0 |
| `0x30001_000` | can_controller | u_can1 | PLIC[26] | CAN bus 1 |

---

## 🚨 Interrupt Map

### PLIC Sources (plic_irq[31:0])
| IRQ # | Source Module | Instance | Trigger |
|-------|-------------|----------|---------|
| 10 | drbg | u_drbg | DRBG operation complete |
| 11 | aes_engine | u_aes | AES operation complete |
| 20 | uart_16550 | u_uart0 | TX/RX FIFO threshold |
| 21 | uart_16550 | u_uart1 | TX/RX FIFO threshold |
| 22 | uart_16550 | u_uart2 | TX/RX FIFO threshold |
| 23 | uart_16550 | u_uart3 | TX/RX FIFO threshold |
| 24 | uart_16550 | u_uart4 | TX/RX FIFO threshold |
| 25 | can_controller | u_can0 | Message TX/RX/Error |
| 26 | can_controller | u_can1 | Message TX/RX/Error |
| 27 | gem_ethernet | u_gem | Frame TX/RX complete |
| 28 | usb_otg | u_usb | Transfer complete |

### Timer Interrupts (timer_irq[4:0])
| Bit | Target | Source |
|-----|--------|--------|
| 0 | Core 0 | rtc.mtimecmp[0] vs mtime |
| 1 | Core 1 | rtc.mtimecmp[1] vs mtime |
| 2 | Core 2 | rtc.mtimecmp[2] vs mtime |
| 3 | Core 3 | rtc.mtimecmp[3] vs mtime |
| 4 | Monitor | rtc.mtimecmp[4] vs mtime |

### Software Interrupts (sw_irq[4:0])
| Bit | Target | Source |
|-----|--------|--------|
| 0 | Core 0 | clint.msip[0] |
| 1 | Core 1 | clint.msip[1] |
| 2 | Core 2 | clint.msip[2] |
| 3 | Core 3 | clint.msip[3] |
| 4 | Monitor | clint.msip[4] |

---

## 🔗 Top-Level Internal Net Table

| Net Name | Width | Direction | Connected Modules | Description |
|----------|-------|-----------|-------------------|-------------|
| `clk` | 1 | input | All modules | System clock |
| `rst_n` | 1 | input | reset_sync, secure_boot, ddr_ctrl, bridges | Active-low async reset |
| `core_rst_n` | 1 | internal | = rst_n & boot_pass → all cores | Gated reset (post-boot) |
| `boot_pass` | 1 | internal | secure_boot → core_rst_n gate | Boot validation passed |
| `boot_fail` | 1 | internal | secure_boot → (unused) | Boot validation failed |
| `plic_irq[31:0]` | 32 | internal | peripherals → PLIC | Interrupt source vector |
| `timer_irq[4:0]` | 5 | internal | RTC → cores | Per-hart timer interrupts |
| `sw_irq[4:0]` | 5 | internal | CLINT → cores | Per-hart software interrupts |
| `axm_awvalid[14:0]` | 15 | internal | masters → crossbar | AXI master write addr valid |
| `axm_awready[14:0]` | 15 | internal | crossbar → masters | AXI master write addr ready |
| `axm_awaddr[599:0]` | 15×40 | internal | masters → crossbar | AXI master write addresses |
| `axm_awid[59:0]` | 15×4 | internal | masters → crossbar | AXI master write IDs |
| `axm_wvalid[14:0]` | 15 | internal | masters → crossbar | AXI master write data valid |
| `axm_wready[14:0]` | 15 | internal | crossbar → masters | AXI master write data ready |
| `axm_wdata[959:0]` | 15×64 | internal | masters → crossbar | AXI master write data |
| `axm_wstrb[119:0]` | 15×8 | internal | masters → crossbar | AXI master write strobes |
| `axm_wlast[14:0]` | 15 | internal | masters → crossbar | AXI master write last beat |
| `axm_bvalid[14:0]` | 15 | internal | crossbar → masters | AXI master write resp valid |
| `axm_bready[14:0]` | 15 | internal | masters → crossbar | AXI master write resp ready |
| `axm_bresp[29:0]` | 15×2 | internal | crossbar → masters | AXI master write responses |
| `axm_arvalid[14:0]` | 15 | internal | masters → crossbar | AXI master read addr valid |
| `axm_arready[14:0]` | 15 | internal | crossbar → masters | AXI master read addr ready |
| `axm_araddr[599:0]` | 15×40 | internal | masters → crossbar | AXI master read addresses |
| `axm_rvalid[14:0]` | 15 | internal | crossbar → masters | AXI master read data valid |
| `axm_rready[14:0]` | 15 | internal | masters → crossbar | AXI master read data ready |
| `axm_rdata[959:0]` | 15×64 | internal | crossbar → masters | AXI master read data |
| `axm_rresp[29:0]` | 15×2 | internal | crossbar → masters | AXI master read responses |
| `axm_rlast[14:0]` | 15 | internal | crossbar → masters | AXI master read last beat |
| `axs_awvalid[8:0]` | 9 | internal | crossbar → slaves | AXI slave write addr valid |
| `axs_awready[8:0]` | 9 | internal | slaves → crossbar | AXI slave write addr ready |
| `axs_awaddr[359:0]` | 9×40 | internal | crossbar → slaves | AXI slave write addresses |
| `axs_wvalid[8:0]` | 9 | internal | crossbar → slaves | AXI slave write data valid |
| `axs_wdata[575:0]` | 9×64 | internal | crossbar → slaves | AXI slave write data |
| `axs_arvalid[8:0]` | 9 | internal | crossbar → slaves | AXI slave read addr valid |
| `axs_rvalid[8:0]` | 9 | internal | slaves → crossbar | AXI slave read data valid |
| `axs_rdata[575:0]` | 9×64 | internal | slaves → crossbar | AXI slave read data |
| `haddr[31:0]` | 32 | internal | axi4_to_ahb → APB decoder | AHB bus address |
| `hwdata[31:0]` | 32 | internal | axi4_to_ahb → APB decoder | AHB write data |
| `hrdata[31:0]` | 32 | internal | prdata_mux → axi4_to_ahb | AHB read data |
| `hwrite` | 1 | internal | axi4_to_ahb → APB | AHB write enable |
| `htrans[1:0]` | 2 | internal | axi4_to_ahb → APB | AHB transfer type |
| `paddr[31:0]` | 32 | internal | = haddr → all APB peripherals | APB address (passthrough) |
| `pwdata[31:0]` | 32 | internal | = hwdata[31:0] → all APB periphs | APB write data |
| `psel` | 1 | internal | = htrans[1] → address decoder | APB peripheral select |
| `penable` | 1 | internal | = htrans[1] → all APB periphs | APB transfer enable |
| `pwrite` | 1 | internal | = hwrite → all APB peripherals | APB write enable |
| `prdata_mux[63:0]` | 64 | internal | 17-input mux → hrdata | APB read data multiplexer |
| `psel_uart0..4` | 5 | internal | decoder → uart_16550 instances | UART select signals |
| `psel_rtc` | 1 | internal | decoder → rtc | RTC select |
| `psel_gem` | 1 | internal | decoder → gem_ethernet | GbE config select |
| `psel_usb` | 1 | internal | decoder → usb_otg | USB config select |
| `psel_mipi` | 1 | internal | decoder → mipi_csi2_rx | MIPI config select |
| `psel_isp` | 1 | internal | decoder → isp_pipeline | ISP config select |
| `psel_hdmi` | 1 | internal | decoder → hdmi_ctrl | HDMI config select |
| `psel_drbg` | 1 | internal | decoder → drbg | DRBG select |
| `psel_aes` | 1 | internal | decoder → aes_engine | AES select |
| `psel_envm` | 1 | internal | decoder → envm_ctrl | eNVM select |
| `psel_boot` | 1 | internal | decoder → secure_boot | Secure boot select |
| `psel_can0/1` | 2 | internal | decoder → can_controller | CAN select |
| `isp_tdata[31:0]` | 32 | internal | mipi_csi2_rx → isp_pipeline | AXI-Stream video data |
| `isp_tvalid` | 1 | internal | mipi_csi2_rx → isp_pipeline | AXI-Stream valid |
| `isp_tlast` | 1 | internal | mipi_csi2_rx → isp_pipeline | AXI-Stream last |
| `isp_tuser` | 1 | internal | mipi_csi2_rx → isp_pipeline | AXI-Stream user (SOF) |
| `isp_tready` | 1 | internal | isp_pipeline → mipi_csi2_rx | AXI-Stream ready |
| `trng_seed[127:0]` | 128 | internal | TRNG → DRBG | Random entropy seed |
| `trng_seed_valid` | 1 | internal | TRNG → DRBG | Entropy valid |
| `envm_addr[31:0]` | 32 | internal | secure_boot → envm_ctrl | eNVM read address |
| `envm_req` | 1 | internal | secure_boot → envm_ctrl | eNVM read request |
| `envm_rdata[31:0]` | 32 | internal | envm_ctrl → secure_boot | eNVM read data |
| `envm_valid` | 1 | internal | envm_ctrl → secure_boot | eNVM data valid |

---

*Generated from exhaustive RTL source analysis — SMVDU TITAN-X SoC, September 2026*
