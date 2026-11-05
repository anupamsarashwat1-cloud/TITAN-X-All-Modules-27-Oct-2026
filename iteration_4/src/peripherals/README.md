# Peripherals

## Description
The peripherals subsystem contains all I/O and external communication interfaces.

## Working
Includes UART, SPI, I2C, CAN, Ethernet (GEM), PCIe, GPIO, and Timers. They communicate with the CPU via the APB/AHB interconnect and generate interrupts.

## Need
Required for external communication, debugging, and interfacing with the physical world.

## Steps to Use / Integrate
1. Instantiate required peripherals.
2. Connect them to the APB/AHB bridges.
3. Connect their interrupt lines to the PLIC.
