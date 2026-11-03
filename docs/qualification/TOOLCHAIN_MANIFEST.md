# SMVDU TITAN-X Toolchain & Environment Manifest

**Execution Date:** 2026-11-03  
**Qualification Branch:** `remediation/titan-x-2026-11-03`  
**Host System:** Linux `anupam-sarashwat-VirtualBox` (Ubuntu 24.04.4 LTS, Kernel 7.0.0-38-generic, x86_64)  
**Host Memory / Architecture:** 64-bit SMP PREEMPT_DYNAMIC  

---

## 1. Electronic Design Automation (EDA) Toolchain

| Tool Category | Tool / Utility | Version String | Absolute Path | License / Status | Purpose in Qualification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Logic Simulation** | Icarus Verilog (`iverilog`) | `13.0 (devel) (0_8-6897-g58dcf39db-dirty)` | `/home/anupam-sarashwat/miniforge3/bin/iverilog` | GPLv2 / Open Source | Dynamic IEEE 1364-2001 / IEEE 1800-2012 simulation compiler |
| **Simulation Runtime** | VVP (`vvp`) | `13.0 (devel)` | `/home/anupam-sarashwat/miniforge3/bin/vvp` | GPLv2 / Open Source | Simulation virtual machine & VCD waveform generator |
| **Static Lint & Analysis** | Verilator (`verilator`) | `5.020 2024-01-01 rev (Debian 5.020-1)` | `/usr/bin/verilator` | LGPLv3 / Open Source | Multi-module whole-SoC lint (`-Wall`), syntax, width, latch, circular logic audit |
| **Formal Model Checking** | Z3 SMT Solver (`z3`) | `5.0.0 - 64 bit` | `/home/anupam-sarashwat/miniforge3/bin/z3` | MIT License | SMT-LIB2 bounded model checking engine for SVA properties |
| **RTL Synthesis** | Yosys Open SYnthesis Suite (`yosys`) | `0.33 (git sha1 2584903a060)` | `/usr/bin/yosys` | ISC License | Technology mapping, SMT2 formal model generation, gate-level netlist generation |
| **Waveform Viewer** | GTKWave (`gtkwave`) | `v3.3.116` | `/usr/bin/gtkwave` | GPLv2 / Open Source | Digital waveform inspection and telemetry capture |

---

## 2. Automation, Scripting & Release Environment

| Tool / Runtime | Version | Absolute Path | Role |
| :--- | :--- | :--- | :--- |
| **Python** | `3.13.13` | `/home/anupam-sarashwat/miniforge3/bin/python3` | Test orchestration, regression scoring, trace analysis |
| **Git** | `2.43.0` | `/usr/bin/git` | Version control, immutable commit tracking, branching |
| **GitHub CLI (`gh`)** | `2.45.0 (2025-07-18)` | `/usr/bin/gh` | Authenticated repository provisioning and release upload (`anupamsarashwat1-cloud`) |
| **Bash Shell** | `5.2.21(1)-release` | `/bin/bash` | Build scripts, regression runners, and automated harnesses |

---

## 3. Environment Dependencies & Variables

- **DISPLAY**: `:0` (Used for headless/X11 GTKWave screenshot capture)
- **PYTHONPATH**: Preserved default miniforge3 environment
- **CWD**: `/home/anupam-sarashwat/SMVDU_TITAN_X_RTL_to_GDS`
- **Compiler Flags**:
  - `iverilog`: `-g2012 -Wall -Wno-timescale -Wno-implicit-dimensions -I includes/`
  - `verilator`: `--lint-only -Wall --timing`
  - `yosys`: `synth -top rv_core_top`
