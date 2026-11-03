# SMVDU TITAN-X Baseline Qualification & Architecture Inventory

**Execution Date:** 2026-11-03  
**Baseline Git Commit SHA:** `633037f16d4540a3d41e87fbe9e58b360de5f9f1`  
**Baseline Git Branch:** `main` (Audited on isolation branch `remediation/titan-x-2026-11-03`)  
**Repository Remote URL:** `https://github.com/anupamsarashwat1-cloud/TITAN-X-All-Modules-27-Oct-2026.git`  
**Host Environment:** Ubuntu 24.04.4 LTS (x86_64), Linux Kernel 7.0.0-38-generic  

---

## 1. Baseline Repository Structure & Working Tree State

The repository baseline was inspected prior to any modification. The tree contains 72 canonical synthesizable and foundational source files listed in `soc_filelist.f`, plus testbenches, verification harnesses, and documentation.

### 1.1 Uncommitted / Untracked Working Tree Artifacts
A dirty-tree audit of the workspace revealed several categories of untracked files:
1. **Legacy Flat RTL Files (May 2026):** Files such as `backend/rv_execute.v`, `video/vdma.v`, etc., created before the codebase was restructured into domain-specific subdirectories (`backend/rv_execute/rv_execute.v`, `video/vdma/vdma.v`).
2. **Prior Iteration Directories:** `iteration_4/` and `rtl_iteration3_fixed/` containing older versions of modules.
3. **Local Telemetry & Run Artifacts:** `.vcd` trace files, GTKWave screenshots, and test scripts (`run_sim.sh`, `run_sim_new.sh`).

**Preservation Policy:** In accordance with Rule 3, no untracked user files have been discarded or deleted. All remediation and qualification is isolated to the branch `remediation/titan-x-2026-11-03` referencing the authoritative modular filepaths defined in `soc_filelist.f`.

---

## 2. Top-Level Module Hierarchy & Subsystems

The primary system top module is `top/titan_x_top/titan_x_top.v`.

```
titan_x_top
├── u_plic (Platform-Level Interrupt Controller, 186 sources, 10 targets)
├── u_crossbar (15-Master x 9-Slave AXI4 Interconnect)
├── u_boot_rom (Boot ROM on Slave 2, firmware.hex)
├── gen_cores[0..3].u_core (4x RV64IM in-order 5-stage CPU Cores)
│   ├── u_fetch (rv_fetch: AXI-Lite read channel)
│   ├── u_decode (rv_decode: 32-bit instruction decode, regfile bypass)
│   ├── u_execute (rv_execute: ALU, Radix-4 MUL, 64-cycle DIV, CSR)
│   │   └── u_csr (rv_csr: Machine-mode CSRs, mcycle, minstret)
│   ├── u_mem (rv_mem: AXI-Lite data read/write)
│   └── u_wb (rv_writeback: register retirement to x1..x31)
├── u_monitor (rv_monitor_core: Hart 4 RV64IM monitor core)
├── u_l2_cache (l2_cache_top: 2MB coherent cache, instantiated without bus connection in baseline)
├── u_ddr_ctrl (ddr_ctrl_top: AXI4 DDR4 memory controller on Slave 0)
│   ├── u_scheduler (ddr_scheduler)
│   └── u_phy_if (ddr_phy_if)
├── u_axi2ahb (axi4_to_ahb on Slave 1)
├── u_apb_bridge (APB Address Decoder & Multiplexer)
│   ├── u_uart0..4 (uart_16550)
│   ├── u_rtc (rtc: 64-bit real-time counter & CDC)
│   ├── u_can0..1 (can_controller)
│   ├── u_secure_boot (secure_boot: Root-of-Trust FSM)
│   ├── u_envm (envm_ctrl: embedded non-volatile memory controller)
│   ├── u_drbg (drbg: NIST SP 800-90A CTR-DRBG)
│   ├── u_aes (aes_engine: 256-bit AES cryptographic engine)
│   ├── u_mipi (mipi_csi2_rx: D-PHY receiver)
│   ├── u_isp (isp_pipeline: video processing engine)
│   └── u_hdmi (hdmi_ctrl: TMDS video output generator)
└── DMA Masters:
    ├── u_gem (gem_ethernet: Gigabit Ethernet MAC on Master 10)
    ├── u_pcie (pcie_top: PCI Express Gen2 controller on Master 11)
    └── u_usb (usb_otg: USB 2.0 OTG controller on Master 12)
```

---

## 3. Discrepancy & Known Failure Analysis

### 3.1 Architectural Classification Discrepancies
- **Advertised:** "Quad-Core RV64GC + RV64IMAC Monitor, 8-stage dual-issue superscalar, Sv39 active MMU, 2MB active L2 cache, 79,755 standard cells, tape-out signed off."
- **Actual Baseline RTL:**
  - **Pipeline:** 5-stage in-order single-issue pipeline (`rv_fetch` -> `rv_decode` -> `rv_execute` -> `rv_mem` -> `rv_writeback`).
  - **ISA:** RV64IM (Base 64-bit Integer + Multiplication/Division). Decode is 32-bit only (no compressed 'C' decode). Floating point (`fpu_*`) and atomic (`is_amo`) signals are tied off in `rv_core_top`.
  - **Privilege Mode:** Machine-mode only. `mstatus.MPP` remains `2'b11` on MRET.
  - **Memory Subsystem:** `u_l2_cache` only has `clk` and `rst_n` connected; `u_ddr_ctrl` is wired directly to Crossbar Slave 0.
  - **MMU/PMP:** Standalone leaf modules pass directed tests, but CPU cores issue physical addresses directly to AXI without dynamic translation.
  - **Sign-Off State:** Synthesis evidence in baseline is generic Yosys mapping (1,096 cells for `rv_core_top`), not full-chip ASIC physical sign-off.

### 3.2 Regression Script Limitations
The existing baseline `scripts/run_regress.py` uses an unconstrained recursive glob (`REPO.rglob("*.v")`), causing it to pull in untracked legacy workspaces and fail with duplicate module declarations (`COMPILE_FAIL`). In prior isolated runs, 12 testbenches were flagged as `SUSPECT_PASS_XDATA` due to uninitialized signals or broad regex matching across $t=0$ reset phases.
