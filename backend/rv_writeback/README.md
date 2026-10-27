
# rv_writeback

## Description
The `rv_writeback` module is the final stage of the pipeline. It simply registers the incoming result from the memory stage and drives the write port of the register file (located in the decode stage). It also provides a forwarding path back to the execute stage to resolve distance-2 data hazards.

## Interface

### Inputs
| Signal | Width | Description |
|--------|-------|-------------|
| clk | 1 | System clock |
| rst_n | 1 | Active-low asynchronous reset |
| result | 64 | Result data from memory stage |
| rd_in | 5 | Destination register address |
| reg_write | 1 | Register write enable |
| valid_in | 1 | Input valid signal |

### Outputs
| Signal | Width | Description |
|--------|-------|-------------|
| wb_data | 64 | Data to be written to the register file |
| wb_rd | 5 | Destination register address for the register file |
| wb_we | 1 | Write enable for the register file (forces 0 for x0) |
| fwd_wb_data | 64 | Forwarded data for earlier pipeline stages |
| fwd_wb_rd | 5 | Forwarded destination register |
| fwd_wb_valid | 1 | Forwarding valid signal |

## Functionality
This module captures the execution result and destination information into pipeline registers on the clock edge. It outputs these registered values as write signals to the integer register file. A check is included to disable writes to register `x0`. The same outputs are exposed combinationally as forwarding paths (`fwd_wb_*`) to provide the freshest data to dependent instructions in the execute stage before they are formally written to the register file.

## Hierarchical Block Diagram
```mermaid
graph TD
    subgraph Inputs
        clk["clk"]
        rst_n["rst_n"]
        result["result"]
    end
    subgraph WB["rv_writeback"]
        REG["Pipeline Register"]
    end
    subgraph Outputs
        wb_data["wb_data"]
        fwd_wb_data["fwd_wb_data"]
    end
    clk --> REG
    rst_n --> REG
    result --> REG
    REG --> wb_data
    REG --> fwd_wb_data
```

## Signal-Level Diagram
```mermaid
graph LR
    subgraph Inputs
        result["result"]
        rd["rd_in"]
        we["reg_write"]
        val["valid_in"]
    end
    subgraph WB["rv_writeback"]
        reg["Flip-Flops"]
    end
    subgraph Outputs
        wb_data["wb_data"]
        wb_rd["wb_rd"]
        wb_we["wb_we"]
    end
    result --> reg
    rd --> reg
    we --> reg
    val --> reg
    reg --> wb_data
    reg --> wb_rd
    reg --> wb_we
```
