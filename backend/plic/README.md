# plic

## Description

The `plic` (Platform Level Interrupt Controller) routes external hardware interrupts to specific hart contexts in the SMVDU-TITAN-X SoC. It scales to handle 186 independent global interrupt sources and routes them to 10 distinct targets (representing Machine and Supervisor privilege modes across 5 hardware threads). The PLIC evaluates incoming interrupts dynamically, considering per-source priorities, per-target enables, and per-target priority thresholds. It exposes an APB slave interface to allow system software to configure these parameters, read interrupt claims, and signal completion of interrupt service routines.

## Interface

### Inputs

| Signal | Width | Description |
|--------|-------|-------------|
| clk | 1 | System clock |
| rst_n | 1 | Active-low asynchronous reset |
| interrupt_sources | 186 | Raw external interrupt signals from peripherals |
| psel | 1 | APB select signal |
| penable | 1 | APB enable signal |
| pwrite | 1 | APB write strobe |
| paddr | 24 | APB 24-bit address for configuration registers |
| pwdata | 32 | APB 32-bit write data |

### Outputs

| Signal | Width | Description |
|--------|-------|-------------|
| prdata | 32 | APB 32-bit read data returning to the master |
| pready | 1 | APB ready signal, always asserted for zero-wait access |
| irq_targets | 10 | Resolved interrupt request lines directed to the 10 core targets |

## Functionality

The `plic` captures the rising edges of 186 `interrupt_sources` into its internal `pending` register array. On every cycle, a combinational priority encoder evaluates all pending interrupts against the configuration matrix. For each of the 10 targets, the PLIC checks if the pending interrupt is enabled (`enable` array), and if its assigned priority (`priority_reg`) strictly exceeds the target's configured `threshold`. It selects the highest-priority valid interrupt for each target and asserts the corresponding bit in `irq_targets`. 

System software interacts with the PLIC via the APB interface. When a target receives an interrupt, it reads the claim register to get the ID of the highest-priority pending interrupt, which automatically acknowledges it. After servicing, the software writes the ID back to the claim register, which clears the corresponding bit in the `pending` register, allowing subsequent interrupts from that source to be processed.

## Hierarchical Block Diagram

```mermaid
graph TD
    subgraph "plic"
        APB["APB Configuration Interface"]
        PENDING["Pending Interrupt Latch"]
        REGS["Config Registers (Priority, Enable, Threshold)"]
        PRIORITY_ENC["Priority Encoder & Arbitrator"]
    end
    
    APB -->|"Writes"| REGS
    APB -->|"Claim Complete"| PENDING
    PENDING -->|"Pending State"| PRIORITY_ENC
    REGS -->|"Config Data"| PRIORITY_ENC
    PRIORITY_ENC -->|"Best IRQ IDs"| APB
    PRIORITY_ENC -->|"irq_targets"| Core
```

## Signal-Level Diagram

```mermaid
graph LR
    subgraph Inputs
        clk["clk"]
        rst_n["rst_n"]
        irq_src["interrupt_sources[185:0]"]
        apb_ctrl["psel, penable, pwrite"]
        apb_addr["paddr[23:0]"]
        apb_wdata["pwdata[31:0]"]
    end
    
    subgraph PLIC_Module["plic"]
        PEND_LOGIC["Pending Latch Logic"]
        CFG_REGS["Configuration Registers"]
        ARBITER["Multi-target Arbiter"]
    end
    
    subgraph Outputs
        apb_rdata["prdata[31:0]"]
        apb_rdy["pready"]
        irq_out["irq_targets[9:0]"]
    end

    clk --> PLIC_Module
    irq_src --> PEND_LOGIC
    apb_ctrl --> CFG_REGS
    apb_addr --> CFG_REGS
    apb_wdata --> CFG_REGS
    
    PEND_LOGIC --> ARBITER
    CFG_REGS --> ARBITER
    ARBITER --> irq_out
    CFG_REGS --> apb_rdata
    CFG_REGS --> apb_rdy
```
