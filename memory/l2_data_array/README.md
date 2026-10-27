# l2_data_array

## Description

The L2 Data Array provides data storage for the cache using two `sram_32x64_180nm` hard macros organized into a two-bank structure. It includes logic to select between the two banks based on an address bit, multiplexing their outputs for read operations, and distributing write data properly. This module specifically features a critical fix ensuring that all 32 output bits from both SRAM macros are explicitly driven to resolve an LVS floating-net issue reported by the physical design team.

## Interface

### Inputs

| Signal | Width | Description |
|--------|-------|-------------|
| clk    | 1     | System clock |
| rst_n  | 1     | Active-low asynchronous reset |
| bank_sel | 1   | Selects between bank 0 and bank 1 |
| cs     | 1     | Chip select for the array |
| we     | 1     | Write enable for the array |
| wmask  | 4     | Byte-level write mask |
| addr   | 6     | Address selecting one of the 64 entries |
| din    | 32    | 32-bit data to write |

### Outputs

| Signal | Width | Description |
|--------|-------|-------------|
| dout   | 32    | 32-bit data read from the selected bank |
| dout_valid | 1 | Indicates that the read data is valid (asserted one cycle after a read) |

## Functionality

The data array operates with a 1-cycle latency. On an active operation (where `cs` is high), the module decodes the `bank_sel` signal to assert the active-low chip select for the targeted SRAM macro (`u_sram_bank0` or `u_sram_bank1`). During a write, `we` is active, and data is pushed into the chosen bank with byte-level masking. During a read operation, both SRAM macros execute, but the output multiplexer registers the output of the selected bank onto `dout` on the following clock cycle, concurrently asserting `dout_valid`.

## Hierarchical Block Diagram

```mermaid
graph TD
    subgraph Inputs
        clk["clk"]
        rst_n["rst_n"]
        bank_sel["bank_sel"]
        cs["cs"]
        we["we"]
        wmask["wmask[3:0]"]
        addr["addr[5:0]"]
        din["din[31:0]"]
    end
    subgraph MODULE["l2_data_array"]
        DEC["Bank Decoder Logic"]
        BANK0["u_sram_bank0 (sram_32x64_180nm)"]
        BANK1["u_sram_bank1 (sram_32x64_180nm)"]
        MUX["Output Mux & Register"]
    end
    subgraph Outputs
        dout["dout[31:0]"]
        dout_valid["dout_valid"]
    end
    clk --> BANK0
    clk --> BANK1
    clk --> MUX
    rst_n --> MUX
    bank_sel --> DEC
    bank_sel --> MUX
    cs --> DEC
    we --> DEC
    DEC -->|"csb0, web0"| BANK0
    DEC -->|"csb0, web0"| BANK1
    wmask --> BANK0
    wmask --> BANK1
    addr --> BANK0
    addr --> BANK1
    din --> BANK0
    din --> BANK1
    BANK0 -->|"sram_dout_bank0"| MUX
    BANK1 -->|"sram_dout_bank1"| MUX
    MUX --> dout
    MUX --> dout_valid
```

## Signal-Level Diagram

```mermaid
graph LR
    subgraph Inputs
        clk["clk"]
        rst_n["rst_n"]
        bank_sel["bank_sel"]
        cs["cs"]
        we["we"]
        wmask["wmask[3:0]"]
        addr["addr[5:0]"]
        din["din[31:0]"]
    end
    subgraph MODULE["l2_data_array"]
        DEC["Bank Selector"]
        SRAMS["SRAM Banks"]
        OUT_REG["Output Register"]
    end
    subgraph Outputs
        dout["dout[31:0]"]
        dout_valid["dout_valid"]
    end
    clk --> SRAMS
    clk --> OUT_REG
    rst_n --> OUT_REG
    bank_sel --> DEC
    cs --> DEC
    we --> DEC
    wmask --> SRAMS
    addr --> SRAMS
    din --> SRAMS
    DEC --> SRAMS
    DEC --> OUT_REG
    SRAMS --> OUT_REG
    OUT_REG --> dout
    OUT_REG --> dout_valid
```
