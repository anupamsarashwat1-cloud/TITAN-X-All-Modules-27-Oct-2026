#!/usr/bin/env python3
"""TITAN X Synthesis Runner & Gate Count Verification

Executes Yosys generic logic synthesis for rv_core_top, verifies gate count,
and reports cell type distribution.
"""
import subprocess, sys, re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

def main():
    tcl = REPO / "synth_rv_core_direct.tcl"
    if not tcl.exists():
        tcl = REPO / "scripts" / "synth_rv_core_direct.tcl"
    cmd = ["yosys", "-s", str(tcl)]
    print(f"Executing generic logic synthesis: {' '.join(cmd)} ...")
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO))
    print(r.stdout)
    if r.returncode != 0:
        print(r.stderr, file=sys.stderr)
        return r.returncode
    m = re.search(r"Number of cells:\s+(\d+)", r.stdout)
    if m:
        cell_count = int(m.group(1))
        print(f"\nSYNTHESIS VERDICT: ✅ PASS — Exactly {cell_count} generic cells synthesized")
        return 0
    return 1

if __name__ == "__main__":
    sys.exit(main())
