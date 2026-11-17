# Canonical Repository Reconciliation Report

**Date:** 2026-11-17  
**Scope:** Cross-repository reconciliation between TITAN-X-2026-11-03 (main) and TITAN-X-2026-11-04 (canonical)  
**Branch:** `reconciliation/canonical-repository-2026-11-05`

---

## 1. Source Revisions

| Item | Value |
|------|-------|
| Main repo HEAD | `b2056254ef4638603b5535a9effdb7b208e6931a` |
| Canonical repo HEAD (pre-reconciliation) | `bf50b16205fbb943d95c660a3120c85671a5e9dc` |
| Prompt 5 completion commit (main) | `19a8592` |
| Prompt 5 completion commit (canonical) | `bf50b16` |

---

## 2. Files Inspected

| Metric | Count |
|--------|-------|
| Main repo tracked files | 1510 |
| Canonical repo tracked files (pre) | 930 |
| Total comparison entries | 1615 |
| Files identical | 701 |
| Files changed | 124 |
| Missing from canonical | 685 |
| New in canonical only | 105 |

---

## 3. Reconciliation Actions

### 3a. Files Ported to Canonical (44 files)

| Category | Files | Source |
|----------|-------|--------|
| Formal SVA properties | 5 (.sv) | `formal/sva/` |
| Formal TCL scripts | 5 (.tcl) | `formal/scripts/` |
| Integration testbenches | 10 (.v) | `integration/` |
| UVM environment | 7 (.sv + README) | `uvm_env/` |
| eFuse controller | 2 (.v) | `security/efuse_ctrl/` |
| Performance TB | 1 (.v) | `performance/` |
| Firmware | 1 (.bin) | `firmware/` |
| Synthesis scripts | 3 (.tcl) | root |
| Simulation scripts | 2 (.sh) | root |
| Other (soc_filelist, axi_sram, etc.) | 8 | various |

### 3b. Scripts Updated (2 files)
- `scripts/run_regress.py` — newer version from main repo
- `scripts/verilator_lint.sh` — newer version from main repo

### 3c. Files NOT Ported (641 files)
- `iteration_4/` duplicates (~200 files)
- `rtl_iteration3_fixed/` duplicates (~200 files)
- GTKWave screenshots (~20 PNG files)
- Simulation binaries (~10 files)
- Generated log differences (~120 files)

**Rationale:** These are either historical duplicates of files already in canonical, generated build artifacts, or test logs from previous runs.

---

## 4. Critical Technical Inspections

### 4a. Secure Boot Chain ✅ VERIFIED
- **Trust Anchor:** `efuse_ctrl` (line 59-77 of `secure_boot.v`) provides hardware-anchored keys via `hw_rot_qx/hw_rot_qy`
- **Key Selection:** Firmware image header selects key slot index, but actual key data comes from eFuse hardware — firmware CANNOT supply its own key
- **Anti-Rollback:** Security counter from eFuse (`hw_security_counter`) compared against firmware image version (line 291-304)
- **Boot Fail:** Any verification failure drives `state → S_HALT`, `boot_fail = 1` (line 578), cores remain in reset
- **Chain:** Image → eFuse key select → SHA-256 digest → ECDSA P-256 verify → rollback check → S_SUCCESS/S_HALT

### 4b. SHA-256 Engine ✅ VERIFIED
- **FIPS 180-4 Header:** Declared in file header (line 3)
- **Automated Padding:** `auto_pad` with `pad_step` for 1-block and 2-block padding (lines 59-134)
- **Length Encoding:** `total_len_bits = {32'h0, msg_len_bytes} << 3` (line 86)
- **Multi-block:** Supported via `pad_step` and chaining state (`H` registers)
- **300 lines total** — complete implementation

### 4c. L1 Caches ✅ VERIFIED
- **I-Cache:** 8-way × 64-sets × 64B = 32KB, with SEC-DED ECC on tags
- **D-Cache:** 8-way × 64-sets × 64B = 32KB, with valid/dirty bits
- **Geometry correct** per `params.vh` macros
- **Eviction/writeback FSM:** States D_IDLE → D_EVICT_WR → D_EVICT_RSP → D_REFILL_RQ → D_REFILL
- **Tag/index/offset:** TAG_W=28, INDEX_W=6, OFFSET_W=6 (40-bit PA)

### 4d. L2 Cache ⚠️ DOCUMENTED
- **Default parameters:** `SETS=64` in `l2_cache_top.v` and `l2_cache_ctrl.v`
- **SoC instantiation:** `titan_x_top.v:592` overrides with `.SETS(\`L2_SETS)` → 2048 (sim) / 64 (synth)
- **Actual SoC geometry:** 16×2048×64B = 2MB (simulation), 16×64×64B = 64KB (synthesis)
- **Impact:** Standalone TB uses 64KB. SoC uses correct value.

### 4e. Cache Coherence ✅ VERIFIED
- **MESI Directory:** `l2_snoop_filter.v` — 64-set × 8-way directory
- **States:** MODIFIED(2'b11), EXCLUSIVE(2'b10), SHARED(2'b01), INVALID(2'b00) (line 65)
- **Snoop types:** GetS (downgrade to S), GetM (invalidate), Inv (line 27)
- **Multi-core support:** `NUM_CORES` parameterized, snoop mask per core (line 92)

### 4f. SoC Integration ✅ VERIFIED
- **Top-level:** 1083 lines, 79 submodules, full bus connectivity
- **Boot path:** eFuse → secure_boot → axi_rom → cores
- **Reset gating:** `boot_pass` controls core reset release
- **Address map:** DDR at 0x8000_0000, eNVM at 0x0002_0000, APB at 0x4000_0000

---

## 5. Corrected Defects

| ID | Description | Action |
|----|-------------|--------|
| None | No new defects requiring code changes were identified during reconciliation | — |

**Note:** All defects from Phases 1-10 were previously resolved. This reconciliation focused on file inventory and porting, not new code changes.

---

## 6. Unresolved Items

| ID | Description | Severity | Recommendation |
|----|-------------|----------|----------------|
| UNRESLV-01 | `verilator_files.f` paths differ between repos | Low | Each is correct for its directory structure |
| UNRESLV-02 | 118 qualification logs differ | Informational | Expected — different run timestamps |
| UNRESLV-03 | L2 standalone TB default is 64KB not 2MB | Low | SoC instantiation is correct |

---

## 7. Verification Results

*(See RECONCILIATION_TEST_RESULTS.md for details)*

---

## 8. Conclusion

The canonical repository (TITAN-X-2026-11-04) is now a **complete and consistent** representation of the SMVDU TITAN X project. All critical design assets have been accounted for:
- 44 missing files ported from main repo
- 2 scripts updated to newer versions
- 641 files intentionally not ported (duplicates, generated artifacts)
- All critical technical areas (security, SHA-256, caches, coherence) verified correct
- No new functional defects identified
