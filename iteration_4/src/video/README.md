# Video

## Description
The video subsystem handles image processing and display output.

## Working
Includes MIPI CSI-2 Rx for camera input, an Image Signal Processor (ISP), and an HDMI controller for display.

## Need
Necessary for multimedia applications and graphical user interfaces.

## Steps to Use / Integrate
1. Instantiate MIPI, ISP, and HDMI modules.
2. Connect video data streams using AXI-Stream.
3. Configure via APB control registers.
