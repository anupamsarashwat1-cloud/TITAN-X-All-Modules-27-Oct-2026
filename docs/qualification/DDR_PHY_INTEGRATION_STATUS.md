# SMVDU TITAN X — DDR4 PHY Integration Status & Simulation Boundary Report

**Document ID:** TITANX-QUAL-DDR-001  
**Classification:** Post-Review Technical Remediation Deliverable  
**Remediated Finding:** FINDING-04 (DDR4 PHY Behavioral Boundary vs Silicon Hard PHY)  
**Target Module:** `Design Files of TITAN X/memory/ddr_phy_if/ddr_phy_if.v`  
**Controller:** `Design Files of TITAN X/memory/ddr4_ctrl/ddr4_ctrl.v`  
**Status:** ✅ AUDITED & FORMALLY DISCLOSED  

---

## 1. Executive Summary

During the Independent Adversarial Engineering Review of the SMVDU TITAN X SoC, the DDR memory subsystem was audited:

> **FINDING-04 (Medium):** Documentation described `ddr_phy_if.v` as a "DDR4 Physical Interface (PHY)". RTL inspection confirms that `ddr_phy_if.v` contains an internal behavioral memory array that directly satisfies read and write transactions rather than sampling physical bidirectional DQ/DQS I/O pins across high-speed analog SSTL/POD transceivers. While physical DDR pins toggle for waveform realism, the module is a behavioral simulation model, not a silicon-proven hardened PHY.

This report documents the architectural structure of the DDR4 memory subsystem, defines the simulation boundary versus silicon realization requirements, and outlines the integration path for a foundry-hardened DFI PHY macro.

---

## 2. DDR4 Memory Subsystem Architecture

The TITAN X memory subsystem comprises three architectural tiers:

```
+-------------------------------------------------------------------------+
|                  TITAN X AXI4 CROSSBAR (Slave Port 0)                   |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|              L2 Cache Controller (l2_cache_top.v)                       |
|           Shared Coherent Cache (64 KB Synth / 2 MB Target)             |
+-------------------------------------------------------------------------+
                                    | AXI4 Burst Master
                                    v
+-------------------------------------------------------------------------+
|              DDR4 Memory Controller (ddr4_ctrl.v)                       |
|  - Address Mapping (Row / Column / Bank / Bank Group)                   |
|  - Refresh Scheduling (tREFI, tRFC) & Command Queuing                   |
|  - Timings (tRP, tRCD, tCL, tWR, tWTR)                                  |
+-------------------------------------------------------------------------+
                                    | DFI-Style Protocol
                                    v
+-------------------------------------------------------------------------+
|              DDR4 PHY Interface (ddr_phy_if.v)                          |
|  [Simulation Mode]                        [Silicon Target Mode]         |
|  - 32 MB Internal Behavioral Storage      - DFI 3.1 / 4.0 Interface    |
|  - Deterministic Zero-Latency Readback    - Hard Macro Replacement     |
|  - Synthetic Pin Toggling (Waveforms)     - Analog Mixed-Signal I/O    |
+-------------------------------------------------------------------------+
                                    |
                                    v
                         Physical DDR4 SDRAM Pins
           (ddr_ck_p/n, ddr_cke, ddr_cs_n, ddr_dq, ddr_dqs_p/n)
```

---

## 3. Analysis of `ddr_phy_if.v` Implementation

### 3.1 Digital DFI Interface
`ddr_phy_if.v` accepts standard DFI-style control signals from `ddr4_ctrl.v`:
- `dfi_ck_en`: Clock enable.
- `dfi_cs_n`, `dfi_ras_n`, `dfi_cas_n`, `dfi_we_n`: Standard DRAM command strobes.
- `dfi_bg[1:0]`: Bank group selection (4 bank groups in DDR4).
- `dfi_bank[2:0]`: Bank address within bank group (4 banks per group).
- `dfi_addr[15:0]`: Multiplexed Row/Column address.
- `dfi_wrdata[63:0]`, `dfi_wrdata_mask[7:0]`: Write data and byte enables.
- `dfi_rddata[63:0]`, `dfi_rddata_valid`: Read data response channel.

### 3.2 In-Model Behavioral Storage
To ensure deterministic, cycle-accurate simulation across diverse open-source simulators (Icarus Verilog, Verilator) without relying on fragile multi-phase bidirectional `inout wire [63:0] ddr_dq` sampling:
- Storage is maintained in an internal behavioral array:
  `reg [63:0] mem_array [0:(1 << (ROW_BITS + COL_BITS + 5)) - 1];`
- Default simulated capacity: 2 bank groups × 8 banks × 512 rows × 256 columns × 64-bit = **32 MB window**.
- Addresses beyond the modeled 32 MB window fold into this space.

### 3.3 Physical Pin Activity
The physical output pins (`ddr_ck_p`, `ddr_ck_n`, `ddr_cke`, `ddr_cs_n`, `ddr_ras_n`, `ddr_cas_n`, `ddr_we_n`, `ddr_ba`, `ddr_bg`, `ddr_addr`, `ddr_dm`, `ddr_dq`, `ddr_dqs_p/n`) are driven synchronously with DFI commands. This provides realistic signal transitions for waveform viewers (GTKWave) and allows external BFMs (`ddr4_sdram_bfm.v`) to monitor bus traffic.

---

## 4. Silicon Realization Requirements (Foundry PHY Boundary)

For fabrication, `ddr_phy_if.v` cannot be synthesized into digital standard cells. A physical DDR4 interface requires dedicated analog mixed-signal circuitry:

1. **High-Speed I/O Pads:**
   - JEDEC JESD79-4 compliant POD12 (Pseudo Open Drain 1.2V) or SSTL12 drivers.
   - On-Die Termination (ODT) with dynamically calibrated resistance (40Ω, 60Ω, 120Ω).
   - ZQ Calibration engine (`ZQCal`) referencing an external high-precision 240Ω precision resistor.
2. **Clock and Delay Calibration:**
   - Multi-phase PLL/DLL generating quadrature clocks up to 1600 Mbps (800 MHz DDR).
   - Read/Write DQS-to-DQ delay line adjustment with sub-picosecond delay verniers.
   - Gate training, write leveling, and read eye centering logic.
3. **Integration Boundary:**
   - The boundary between `ddr4_ctrl.v` and the physical PHY is strictly defined by the **DFI (DRAM Controller to PHY Interface)** specification.
   - For silicon implementation, `ddr_phy_if.v` is dropped, and `ddr4_ctrl.v` connects directly to a commercial or foundry-supplied DFI-compliant Hard PHY IP (e.g., OpenFASOC, TrueCircuits, or Synopsys DesignWare DDR4 PHY).

---

## 5. Summary Conclusion

| Characteristic | Simulation Environment (`ddr_phy_if.v`) | Silicon Production Target |
|:---|:---:|:---:|
| Interface Protocol | DFI-like Command/Data | Standard DFI 3.1 / 4.0 |
| Read/Write Mechanism | Internal Synchronous RAM Array | SSTL/POD12 Transceivers on Physical Pins |
| Timing Calibration | Ideal / Zero-Skew Digital | Dynamic Delay Line Vernier / ZQ Calibration |
| Max Supported Frequency | Unconstrained RTL Simulation | Up to 1600 Mbps (DDR4-1600) |
| Silicon Portability | Portable Verilog-2001 | Foundry-Specific Hard Analog Macro |

**Audit Status:** FINDING-04 is formally **CLOSED WITH DISCLOSED BOUNDARY**.
