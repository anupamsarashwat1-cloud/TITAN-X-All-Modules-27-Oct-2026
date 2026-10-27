# sram_32x64_180nm

## Description

This module provides a behavioral simulation model for an SCL 180nm SRAM hard macro, featuring a 64-word by 32-bit storage array. It implements a synchronous read/write interface with active-low chip select and write enable signals. The memory supports byte-level write masking, allowing individual bytes within a 32-bit word to be updated independently. It features write-first behavior, meaning read operations during a write cycle will return the newly written data.

## Interface

### Inputs

| Signal | Width | Description |
|--------|-------|-------------|
| clk0   | 1     | System clock |
| csb0   | 1     | Active-low chip select |
| web0   | 1     | Active-low write enable |
| wmask0 | 4     | Active-high byte write mask (1=write byte) |
| addr0  | 6     | 6-bit address selecting one of 64 words |
| din0   | 32    | 32-bit data input for writes |

### Outputs

| Signal | Width | Description |
|--------|-------|-------------|
| dout0  | 32    | 32-bit data output for reads |

## Functionality

The module maintains an internal 64-entry by 32-bit array, initially cleared to zero for simulation purposes. On the rising edge of `clk0`, the memory evaluates the `csb0` chip select. If selected, a write occurs if `web0` is low, conditionally updating up to 4 bytes at `addr0` depending on the `wmask0` bits. Regardless of whether a write occurs, the data at `addr0` is registered into `dout0`. If the module is not selected, `dout0` holds its previous value to prevent floating outputs, mimicking typical SRAM macro retention.

## Hierarchical Block Diagram

```mermaid
graph TD
    subgraph Inputs
        clk0["clk0"]
        csb0["csb0"]
        web0["web0"]
        wmask0["wmask0[3:0]"]
        addr0["addr0[5:0]"]
        din0["din0[31:0]"]
    end
    subgraph MODULE["sram_32x64_180nm"]
        ARRAY["64x32 Memory Array"]
        CTRL["Read/Write Control"]
    end
    subgraph Outputs
        dout0["dout0[31:0]"]
    end
    clk0 --> CTRL
    csb0 --> CTRL
    web0 --> CTRL
    wmask0 --> CTRL
    addr0 --> CTRL
    din0 --> ARRAY
    CTRL --> ARRAY
    ARRAY --> dout0
```

## Signal-Level Diagram

```mermaid
graph LR
    subgraph Inputs
        clk0["clk0"]
        csb0["csb0"]
        web0["web0"]
        wmask0["wmask0[3:0]"]
        addr0["addr0[5:0]"]
        din0["din0[31:0]"]
    end
    subgraph MODULE["sram_32x64_180nm"]
        MEM["Memory Logic"]
    end
    subgraph Outputs
        dout0["dout0[31:0]"]
    end
    clk0 --> MEM
    csb0 --> MEM
    web0 --> MEM
    wmask0 --> MEM
    addr0 --> MEM
    din0 --> MEM
    MEM --> dout0
```
