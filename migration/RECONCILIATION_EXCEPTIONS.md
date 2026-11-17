# Cross-Repository Reconciliation Exceptions

## Reconciliation Date: 2026-11-17
## Main Repo HEAD: `b205625` (TITAN-X-2026-11-03)
## Canonical Repo HEAD: `bf50b16` (TITAN-X-2026-11-04)

---

## 1. Accidental Commit in Main Repo

**Commit:** `b205625` with message "gg"  
**Impact:** Added 641 files (+366,317 lines) including:
- `iteration_4/` — duplicate of design hierarchy
- `rtl_iteration3_fixed/` — older copy of design files
- GTKWave screenshots (`.png`)
- Simulation binaries (`sim_*`)

**Decision:** These are historical/duplicate artifacts. NOT ported to canonical. The canonical repo contains the authoritative, remediated versions under `Design Files of TITAN X/`.

---

## 2. Files Intentionally NOT Ported

### 2a. Duplicate Directories (iteration_4/, rtl_iteration3_fixed/)
- ~400 files that are older copies of the design hierarchy
- Already present in canonical under `Design Files of TITAN X/`
- **Action:** Not ported. Preserved in main repo as historical reference.

### 2b. GTKWave Screenshots (~20 PNG files)
- Root-level waveform screenshots (rv_*_gtkwave.png, etc.)
- Generated artifacts, not source
- **Action:** Not ported.

### 2c. Simulation Binaries (sim_*)
- Compiled simulation executables (sim_top, sim_sb, sim_fresh_fetch, etc.)
- Build artifacts, should be gitignored
- **Action:** Not ported.

### 2d. VCD Waveform Dumps
- Large waveform dump files
- Generated artifacts
- **Action:** Not ported.

---

## 3. Changed Files (124 total)

### 3a. Qualification Logs (118 files)
- `artifacts/qualification/logs/tb_*.log` — Test output logs
- Different due to re-runs during remediation phases
- **Action:** Main repo versions are newer (from Phase 9/10 remediation). No action needed — these are generated artifacts.

### 3b. README.md
- Root README differs between repos (canonical has enhanced version with diagrams)
- **Action:** Keep canonical version (more comprehensive).

### 3c. Scripts (3 files) — PORTED
- `scripts/run_regress.py` — Main repo has newer version with enhanced test runner
- `scripts/verilator_lint.sh` — Main repo has newer version
- `verilator_files.f` — Path differences (main uses relative, canonical uses prefixed paths). Both valid for their directory structure.
- **Action:** Updated canonical with main repo versions.

---

## 4. L2 Cache Parameter Default

**Finding:** `l2_cache_top.v` and `l2_cache_ctrl.v` have `parameter SETS = 64` as default.  
**Context:** `params.vh` correctly defines `L2_SETS` as 2048 (sim) / 64 (synth) with `ifdef SYNTHESIS` guard.  
**SoC Integration:** `titan_x_top.v` line 592 passes `.SETS(\`L2_SETS)` — correctly overrides default.  
**Impact:** Standalone testbenches of L2 would use 64 sets (64KB) instead of 2048 (2MB).  
**Classification:** Parameter-default inconsistency. No functional impact in full SoC context.  
**Action:** Documented. Not a blocking defect.

---

## 5. Security Chain — Verified Correct

| Component | Status | Evidence |
|-----------|--------|----------|
| eFuse trust anchor | ✅ Correct | `secure_boot.v:59-77` — `efuse_ctrl` provides `hw_rot_qx/qy` |
| Key from firmware rejected | ✅ Correct | Key compared from eFuse hardware, not firmware payload |
| Anti-rollback | ✅ Correct | `secure_boot.v:291-304` — checks `efuse_security_counter` |
| SHA-256 FIPS 180-4 | ✅ Correct | `sha256_engine.v` — automated padding with 2-block support (lines 59-134) |
| ECDSA P-256 | ✅ Correct | Montgomery multiplication with correct curve constants |
| Boot fail → halt | ✅ Correct | `boot_fail = (state == S_HALT)` (line 578) |

---

## 6. Unresolved Items

| ID | Description | Status |
|----|-------------|--------|
| UNRESLV-01 | `verilator_files.f` path format differs between repos | Acceptable — each uses paths relative to its own root |
| UNRESLV-02 | 118 qualification log files differ | Expected — different test run timestamps |
| UNRESLV-03 | L2 standalone TB uses 64KB instead of 2MB | Low priority — SoC instantiation correct |
