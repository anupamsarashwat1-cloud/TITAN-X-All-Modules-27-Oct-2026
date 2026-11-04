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
    # Match the summary in design hierarchy (or last 'Number of cells:')
    m_hier = re.search(r"=== design hierarchy ===.*?(Number of cells:\s+(\d+))", r.stdout, re.DOTALL)
    if m_hier:
        cell_count = int(m_hier.group(2))
    else:
        # Fallback to last occurrence
        all_matches = re.findall(r"Number of cells:\s+(\d+)", r.stdout)
        cell_count = int(all_matches[-1]) if all_matches else 0

    # Calculate sequential flip-flops
    dff_matches = re.findall(r"\$_(?:DFF|DFFE)_[A-Z0-9_]+\s+(\d+)", r.stdout.split("=== design hierarchy ===")[-1] if "=== design hierarchy ===" in r.stdout else r.stdout)
    total_dffs = sum(int(x) for x in dff_matches)
    comb_cells = cell_count - total_dffs

    if cell_count > 0:
        print(f"\n=======================================================")
        print(f"SYNTHESIS VERDICT: ✅ PASS — rv_core_top Synthesized")
        print(f"  Total Generic Cells:  {cell_count:,}")
        print(f"  Sequential DFFs:      {total_dffs:,}")
        print(f"  Combinational Cells:  {comb_cells:,}")
        print(f"=======================================================")
        return 0
    return 1

if __name__ == "__main__":
    sys.exit(main())
