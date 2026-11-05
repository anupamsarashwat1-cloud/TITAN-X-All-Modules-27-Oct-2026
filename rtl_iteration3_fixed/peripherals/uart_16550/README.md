# UART 16550

## Overview
An APB-compatible 16550 UART module with support for standard serial communication, LIN, and IrDA.

## Working
Provides configurable baud rate generation (via DLL/DLM) and transmit/receive FIFOs. Accessed via APB. The latest iteration fixes APB byte-lane alignment bugs and uses a 4-byte register shift (`reg-shift = <2>`).

## Need
Provides serial console access for OpenSBI and Linux boot logs.

## Steps to Use
1. Map to an APB address range (e.g., `0x40010000`).
2. Connect `rxd` and `txd` pins to SoC top-level pads.
3. Configure via software using 16550-compatible drivers.