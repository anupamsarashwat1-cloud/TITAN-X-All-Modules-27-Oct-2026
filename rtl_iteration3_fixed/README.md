# RTL Verification Handoff Package (Project Penguin Titan-X)

Welcome to the **RTL Verification Handoff Package**. This repository was automatically generated from the final, timing-closed 180nm SCL `Project_penguin3` codebase. 

It is specifically designed for the **RTL Verification Team** to perform manual bottom-up validation of the design using native Verilog testbenches, Icarus Verilog (`iverilog`), and `gtkwave`.

## 📦 What is included?
This repository is split into 10 fundamental functional groups, mimicking the 11-Gate sign-off strategy used during architectural development:
1. `common/`: Core synchronization primitives (FIFOs, CDC, Reset Syncs)
2. `frontend/`: CPU Fetch and Decode
3. `backend/`: CPU Execution, FPU, MMU, CSRs
4. `interconnect/`: AXI4 Crossbar, APB bridges, MPU
5. `memory/`: DDR Controller, L2 Cache, SRAM arrays
6. `security/`: Secure Boot, Cryptographic Co-processors
7. `peripherals/`: SPI, UART, I2C, CAN, Ethernet, PCIe
8. `storage/`: eMMC, QSPI, USB
9. `video/`: MIPI CSI-2 RX, ISP Pipeline, HDMI Controller
10. `top/`: The `titan_x_top` SoC wrapper

## 📂 Module Level Structure & Master Wrappers
Inside each group, there is a dedicated directory for every RTL module containing:
- **`[module_name].v`**: The raw, optimized RTL design file.
- **`tb_[module_name].v`**: A boilerplate Verilog testbench that wires the DUT, generates clocks (138.8 MHz / 7.2ns), manages resets, and handles `$dumpvars()` for GTKWave.
- **`README.md`**: A custom, auto-generated verification guide for that specific module detailing all I/O signals and featuring a Mermaid structural map of its sub-modules.

### 👑 Master Wrappers
This repository doesn't just stop at the bottom-level leaf nodes. It contains perfect testbenches and documentation for every "Master Wrapper" all the way up to the absolute top of the SoC. 
Verification should flow bottom-up. Once you verify the leaf nodes in a subsystem, move up to its Master Wrapper:
- **The Absolute Top**: `top/titan_x_top/` (Contains a massive Mermaid diagram mapping all 24 core IP blocks wired together)
- **The CPU Core Master**: `backend/rv_core_top/`
- **The Memory Subsystem Master**: `memory/l2_cache_top/`
- **Peripheral & Interconnect Masters**: `peripherals/pcie_top/`, `memory/ddr_ctrl_top/`

## 🚀 Verification Team Instructions
You are expected to navigate into each module's directory and implement the actual functional test vectors within the testbench.

**Workflow for a module (e.g., `rv_execute`)**:
1. `cd backend/rv_execute`
2. Open `tb_rv_execute.v` and write stimulus under `// Add manual test stimulus here...`
3. Compile: `iverilog -o sim.vvp rv_execute.v tb_rv_execute.v -I ../../common` (Note: You may need to add dependencies like `../../common/buf_macros.v` to the compile string if the Mermaid diagram shows it instantiating common macros).
4. Run: `vvp sim.vvp`
5. Inspect: `gtkwave tb_rv_execute.vcd`

Happy Verifying!
