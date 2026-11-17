import os

base_dir = '/home/anupam-sarashwat/SMVDU_TITAN_X_RTL_to_GDS/rtl_iteration3_fixed'

readmes = {
    'backend/rv_core_top': '# RV Core Top\n\n## Overview\nThe `rv_core_top` module is the top-level wrapper for a single RISC-V hart in the TITAN-X SoC. It instantiates the execution pipeline (fetch, decode, execute, memory, writeback), MMU/TLB interfaces, caches, and physical memory protection (PMP).\n\n## Working\nCoordinates instruction fetching, decoding, execution, and exception handling. It acts as the orchestrator for all backend components, routing data between caches and execution units.\n\n## Need\nEssential to encapsulate the complex inner workings of the RISC-V core, providing a clean interface (AXI/AHB) to the rest of the SoC.\n\n## Steps to Use\n1. Instantiate in `titan_x_top`.\n2. Tie `HART_ID` and `RESET_PC` parameters.\n3. Connect to the AXI Interconnect for memory and peripheral access.',
    'interconnect/axi4_crossbar': '# AXI4 Crossbar\n\n## Overview\nA high-performance N-master, M-slave AXI4 interconnect matrix.\n\n## Working\nRoutes requests from multiple bus masters (e.g., 5 cores) to multiple slaves (RAM, APB bridge, Peripherals) using priority or round-robin arbitration. Handles address decoding to select the correct slave.\n\n## Need\nAllows multiple processors to share memory and peripherals concurrently without data collision.\n\n## Steps to Use\n1. Define `NM` (Masters) and `NS` (Slaves).\n2. Configure address decoding ranges inside the module.\n3. Connect master and slave AXI ports.',
    'interconnect/axi4_to_ahb': '# AXI4 to AHB Bridge\n\n## Overview\nA protocol converter bridging the 64-bit AXI4 interconnect to the 32-bit AHB-Lite peripheral bus.\n\n## Working\nTranslates AXI4 transactions (AW/W/B for writes, AR/R for reads) into AHB-Lite phases (Address and Data). Handles byte lane shifting for 64-bit to 32-bit width conversions.\n\n## Need\nRequired because high-speed memory uses AXI4, while lower-speed peripherals use AHB/APB.\n\n## Steps to Use\n1. Connect the AXI slave interface to the crossbar.\n2. Connect the AHB master interface to the APB bridge.',
    'interconnect/ahb_to_apb': '# AHB to APB Bridge\n\n## Overview\nA bridge connecting the AHB-Lite bus to the APB (Advanced Peripheral Bus).\n\n## Working\nConverts pipelined AHB transactions into two-cycle APB transfers (Setup and Access phases). Drives `psel`, `penable`, and `pwrite` for APB peripherals.\n\n## Need\nPeripherals like UART, GPIO, and I2C operate on the simpler APB protocol. This bridge integrates them into the AHB hierarchy.\n\n## Steps to Use\n1. Connect AHB inputs from the AXI-AHB bridge.\n2. Fan out APB signals to all instantiated peripherals.',
    'peripherals/uart_16550': '# UART 16550\n\n## Overview\nAn APB-compatible 16550 UART module with support for standard serial communication, LIN, and IrDA.\n\n## Working\nProvides configurable baud rate generation (via DLL/DLM) and transmit/receive FIFOs. Accessed via APB. The latest iteration fixes APB byte-lane alignment bugs and uses a 4-byte register shift (`reg-shift = <2>`).\n\n## Need\nProvides serial console access for OpenSBI and Linux boot logs.\n\n## Steps to Use\n1. Map to an APB address range (e.g., `0x40010000`).\n2. Connect `rxd` and `txd` pins to SoC top-level pads.\n3. Configure via software using 16550-compatible drivers.',
    'top/titan_x_top': '# TITAN-X Top Level\n\n## Overview\nThe top-level SoC wrapper for the TITAN-X multi-core processor.\n\n## Working\nInstantiates 4 primary RISC-V cores and 1 monitor core. Connects them via an AXI4 Crossbar to main memory (AXI RAM) and peripherals (UART, SPI, I2C, PLIC, CLINT) via an AXI-AHB-APB bridge hierarchy.\n\n## Need\nServes as the root module for Verilator simulation and synthesis.\n\n## Steps to Use\n1. Provide `clk` and `rst_n`.\n2. Connect external I/O pins (UART TX/RX, GPIOs).\n3. Load firmware into the RAM model and simulate.'
}

# Create a generic README for any missing modules
generic_readme = """# {name}

## Overview
A hardware module part of the TITAN-X SoC.

## Working
Handles specific RTL logic for the {name} component. Check the Verilog source code for detailed port definitions and logic flow.

## Need
Essential for the complete operation of the SoC's pipeline or peripheral subsystem.

## Steps to Use
1. Instantiate within the parent wrapper.
2. Connect required clocks, resets, and data buses.
"""

for root, dirs, files in os.walk(base_dir):
    if any(f.endswith('.v') or f.endswith('.sv') for f in files):
        # Determine relative path from base_dir
        rel_path = os.path.relpath(root, base_dir)
        readme_path = os.path.join(root, 'README.md')
        
        # Check if we have a specific README
        content = readmes.get(rel_path)
        if not content:
            # Fallback to generic
            name = os.path.basename(root).replace('_', ' ').title()
            content = generic_readme.format(name=name)
            
        with open(readme_path, 'w') as f:
            f.write(content)

print("Generated READMEs successfully.")
