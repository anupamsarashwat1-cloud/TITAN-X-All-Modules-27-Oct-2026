# Cross-Repository Baseline Report

**Date:** 2026-11-17T18:30:00+05:30  
**Engineer:** Automated Reconciliation (Prompt 5A)

---

## 1. Repository Identification

### Main Repository (Original)
| Field | Value |
|-------|-------|
| URL | https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-03 |
| Local Path | `/home/anupam-sarashwat/SMVDU_TITAN_X_RTL_to_GDS` |
| Remote | `pub` |
| Branch | `remediation/final-engineering-qualification` |
| HEAD | `b2056254ef4638603b5535a9effdb7b208e6931a` |
| Working Tree | Clean |
| Tracking | Up to date with `pub/remediation/final-engineering-qualification` |
| Tracked Files | 1510 |

### Canonical Repository (New)
| Field | Value |
|-------|-------|
| URL | https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04 |
| Local Path | `/home/anupam-sarashwat/TITAN-X-2026-11-04` |
| Remote | `origin` |
| Branch | `reconciliation/canonical-repository-2026-11-05` (created from `repository/migration-2026-11-04`) |
| Base HEAD | `bf50b16205fbb943d95c660a3120c85671a5e9dc` |
| Working Tree | Clean (after reconciliation commits) |
| Tracked Files | 930 (pre-reconciliation), 974 (post-reconciliation) |

---

## 2. Prompt 5 Completion Commit

The preceding remediation (Prompt 5) produced work across Phases 1–10:

| Repo | Phase 10 Commit | Message |
|------|----------------|---------|
| Main | `19a8592` | feat(phase-10): complete final synthesis accounting and tapeout sign-off |
| Canonical | `bf50b16` | feat(phase-10): complete final synthesis accounting and tapeout sign-off |

**Note:** Main repo has an additional accidental commit `b205625` ("gg") on top of Phase 10 that bulk-added 641 files. This is documented in `RECONCILIATION_EXCEPTIONS.md`.

---

## 3. Commit History (Main Repo — Latest 20)

| SHA | Message |
|-----|---------|
| `b205625` | gg (accidental bulk add) |
| `19a8592` | feat(phase-10): complete final synthesis accounting and tapeout sign-off |
| `33bad9f` | feat(phase-09): overhaul verification testbenches, de-mock APB decoders |
| `c121b50` | feat(phase-08): validate peripheral DMA concurrency and crossbar grant fairness |
| `7a2a554` | feat(phase-07): baseline RV64IM_Zicsr M-mode core and reconcile top-level SoC |
| `ebdf8b2` | feat(phase-06): validate multicore MESI coherence directory and snoop invalidation |
| `82b316d` | feat(phase-05): integrate compiled foundry SRAM macros into L2 cache arrays |
| `3072d54` | feat(phase-04): couple secure boot RoT to axi_rom and integrate watchdog timer |
| `aa4d64a` | feat(crypto): implement multicycle Montgomery ECDSA P-256 engine |
| `25320ac` | feat(crypto): implement automated FIPS 180-4 message padding in SHA-256 |
| `72c2317` | fix(security): implement monotonic security counter and anti-rollback |
| `d41afb0` | feat(security): implement OTP eFuse controller model and multi-key trust anchor |
| `392c30b` | fix(interconnect): map on-chip scratchpad SRAM to AXI Crossbar Slave 3 |
| `4df5744` | fix(interconnect): eliminate APB decoder address collision on UART0 |
| `84f559c` | soc: achieve full system integration, Verilator clean lint, 100% regression |
| `1ea27a1` | memory: implement 16-way L2 cache, 8-beat burst engine, MESI dirty intervention |
| `895fd81` | cache: correct L1 cache integration, snoop handling |
| `30049eb` | security: implement genuine NIST P-256 ECDSA and SHA-256 secure boot gating |
| `ffbda95` | inventory: complete hardware architecture module inventory |
| `187a40f` | audit: establish final remediation baseline |

---

## 4. File Inventory Summary

| Classification | Count |
|---------------|-------|
| IDENTICAL | 701 |
| CHANGED | 124 |
| MISSING_FROM_CANONICAL | 685 |
| NEW_IN_CANONICAL | 105 |
| **Total Entries** | **1615** |

Of the 685 missing files:
- ~400 are `iteration_4/` and `rtl_iteration3_fixed/` duplicates (not ported)
- ~130 are GTKWave screenshots and sim binaries (not ported)
- 44 critical files (formal, integration, UVM, security, scripts) were ported
- Remaining are generated logs and READMEs for duplicate directories

Full inventory: `migration/CROSS_REPOSITORY_FILE_MATRIX.csv` and `.json`

---

## 5. Remotes Configuration

### Main Repo
| Remote | URL |
|--------|-----|
| `origin` | https://github.com/anupamsarashwat1-cloud/TITAN-X-All-Modules-27-Oct-2026.git |
| `pub` | https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-03.git |

### Canonical Repo
| Remote | URL |
|--------|-----|
| `origin` | https://github.com/anupamsarashwat1-cloud/TITAN-X-2026-11-04.git |
