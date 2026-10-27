# uart_16550

## Description

The `uart_16550` module is a Multi-Mode UART designed for the SMVDU-TITAN-X SoC, building upon the industry-standard 16550 architecture. In addition to conventional asynchronous serial communication, this iteration introduces support for advanced protocols including IrDA (Infrared Data Association), LIN (Local Interconnect Network) bus, and 9-bit data frames. The core provides a standard APB slave interface that implements traditional 16550 memory-mapped registers alongside custom extension registers (`mode_cr`, `nbit_cr`) for configuring the advanced modes. While the complex physical layer processing logic is currently stubbed, the module establishes the structural and memory framework necessary for multiplexing standard TX/RX paths to specialized protocol endpoints.

## Interface

### Inputs

| Signal | Width | Description |
|--------|-------|-------------|
| clk    | 1     | System clock |
| rst_n  | 1     | Active-low asynchronous reset |
| paddr  | 32    | APB address bus |
| psel   | 1     | APB select signal |
| penable| 1     | APB enable signal |
| pwrite | 1     | APB write enable signal |
| pwdata | 32    | APB write data bus |
| rxd    | 1     | Standard UART receive line |
| irda_rx| 1     | IrDA receive line |
| lin_rx | 1     | LIN bus receive line |

### Outputs

| Signal | Width | Description |
|--------|-------|-------------|
| prdata | 32    | APB read data bus |
| pready | 1     | APB ready signal, hardwired to 1 |
| pslverr| 1     | APB slave error signal, hardwired to 0 |
| uart_irq | 1   | UART interrupt request line |
| txd    | 1     | Standard UART transmit line |
| irda_tx| 1     | IrDA transmit line |
| lin_tx | 1     | LIN bus transmit line |

## Functionality

The `uart_16550` core functions as an APB-slave device, decoding register accesses based on the APB address bus. The module implements the conventional 16550 register map, utilizing the Divisor Latch Access Bit (`dlab` from the LCR) to multiplex accesses to the transmit/receive buffers and the baud rate divisor latches (`dll`, `dlm`). It expands upon the standard by introducing `mode_cr` to switch between UART, IrDA, and LIN modes, and `nbit_cr` to toggle 9-bit operation. The actual physical data transmission and reception (baud generation, framing, and serialization) are placeholders in this version, represented by static idle assignments (e.g., driving `txd` high and `irda_tx` low). Software drivers interact with this module identically to a legacy 16550 UART, with the addition of the extended protocol toggles.

## Hierarchical Block Diagram

```mermaid
graph TD
    subgraph uart_16550
        APB["APB Register Decoder"]
        REGS["16550 + Extension Registers"]
        CORE["Multi-Mode UART Core (Stub)"]
    end
    APB --> REGS
    REGS --> CORE
    CORE -.->|TX/RX Routing| CORE
```

## Signal-Level Diagram

```mermaid
graph LR
    subgraph Inputs
        clk["clk"]
        rst_n["rst_n"]
        paddr["paddr[31:0]"]
        psel["psel"]
        penable["penable"]
        pwrite["pwrite"]
        pwdata["pwdata[31:0]"]
        rxd["rxd"]
        irda_rx["irda_rx"]
        lin_rx["lin_rx"]
    end

    subgraph uart_16550
        LOGIC["Registers & Multiplexing Logic"]
    end

    subgraph Outputs
        prdata["prdata[31:0]"]
        pready["pready"]
        pslverr["pslverr"]
        uart_irq["uart_irq"]
        txd["txd"]
        irda_tx["irda_tx"]
        lin_tx["lin_tx"]
    end

    clk --> LOGIC
    rst_n --> LOGIC
    paddr --> LOGIC
    psel --> LOGIC
    penable --> LOGIC
    pwrite --> LOGIC
    pwdata --> LOGIC
    rxd --> LOGIC
    irda_rx --> LOGIC
    lin_rx --> LOGIC

    LOGIC --> prdata
    LOGIC --> pready
    LOGIC --> pslverr
    LOGIC --> uart_irq
    LOGIC --> txd
    LOGIC --> irda_tx
    LOGIC --> lin_tx
```
