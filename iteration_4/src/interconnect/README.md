# Interconnect

## Description
The interconnect subsystem handles data routing between masters (CPU, DMA) and slaves (Memory, Peripherals).

## Working
It uses an AXI4 Crossbar (axi4_crossbar) with WRR arbitration to route requests. It includes bridges (axi4_to_ahb, ahb_to_apb) for connecting lower-speed peripherals.

## Need
Essential for system-wide communication. It must handle high-bandwidth traffic without deadlocks.

## Steps to Use / Integrate
1. Instantiate the AXI4 Crossbar.
2. Configure master and slave memory map routing.
3. Connect bridges for APB/AHB peripherals.
