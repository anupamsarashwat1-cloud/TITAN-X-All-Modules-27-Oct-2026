#!/usr/bin/env python3
"""Titan-X regression runner — truthful PASS/FAIL across all testbenches.

Compiles every canonical tb_*.v against the verified SoC RTL tree, runs it,
and judges the result. A test PASSES only when the sim reports success through
standard markers AND exits cleanly (code 0) without genuine unknown values.

Usage: python3 scripts/run_regress.py [--only NAME_FILTER] [--timeout 60] [-j N] [--self-test]
"""
import argparse, concurrent.futures as cf, json, re, subprocess, sys, tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEVLOG = Path.home() / "titanx_devlog"
EXCLUDE_DIRS = {".git", "iteration_4", "rtl_iteration3_fixed", "annotated"}
RESULT_RE = re.compile(r"REGRESS_RESULT:\s*(PASS|FAIL)", re.I)
VERDICT_RE = re.compile(r"VERDICT:[^\n]*?(PASS|FAIL)", re.I)
# Match genuine Verilog uninitialized X states, avoiding false positives on 0x hex numbers or file extensions (.hex)
XPAT_RE = re.compile(r"(?:[0-9]+)?'[hHbB][0-9a-fA-F_]*[xXzZ]+|\b[xX]{2,}\b|\bgot=\s*x+\b")


def rtl_files():
    """Read synthesizable canonical RTL modules from soc_filelist.f + canonical BFMs."""
    rtl = []
    filelist = REPO / "soc_filelist.f"
    if filelist.exists():
        with open(filelist) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("//") and not line.endswith("tb_titan_x_top.v"):
                    p = REPO / line
                    if p.exists() and str(p) not in rtl:
                        rtl.append(str(p))
    # Append canonical BFMs if present
    bfms = sorted(
        str(p) for p in REPO.rglob("bfm/*.v")
        if not any(x in p.parts for x in EXCLUDE_DIRS)
    )
    for b in bfms:
        if b not in rtl:
            rtl.append(b)
    return rtl


def tb_files():
    """Discover all canonical unique testbenches, preferring deepest module path for duplicates."""
    raw_tbs = sorted(
        p for p in REPO.rglob("tb_*.v")
        if not any(x in p.parts for x in EXCLUDE_DIRS)
    )
    tb_by_stem = {}
    for p in raw_tbs:
        stem = p.stem
        if stem not in tb_by_stem:
            tb_by_stem[stem] = p
        else:
            if len(p.parts) > len(tb_by_stem[stem].parts):
                tb_by_stem[stem] = p
    return sorted(tb_by_stem.values())


def judge_verdict(returncode: int, log: str) -> str:
    """Strictly evaluate testbench verdict: non-zero returncode ALWAYS overrides PASS."""
    if returncode != 0:
        return "CRASHED"
    if "[TESTBENCH FAILED]" in log or "SIGN-OFF: FAILED" in log or "FATAL" in log:
        return "FAIL"

    m = RESULT_RE.search(log)
    if m:
        verdict = m.group(1).upper()
    elif (vm := VERDICT_RE.search(log)):
        verdict = vm.group(1).upper()
    elif (
        "[ALL TESTS PASSED]" in log
        or "ALL TESTS PASSED" in log
        or "POWER-AWARE VERIFICATION PASSED" in log
        or "SIGN-OFF: SUCCESS" in log
        or ("Total Failed: 0" in log and "[TESTBENCH FAILED]" not in log)
        or ("Total Errors: 0" in log and "ERROR" not in log)
    ):
        verdict = "PASS"
    else:
        verdict = "NO_VERDICT"

    if verdict == "PASS":
        # Check for genuine unknown states
        clean_log = re.sub(r"0x[0-9a-fA-F_]+", "", log)
        if XPAT_RE.search(clean_log):
            verdict = "SUSPECT_PASS_XDATA"
    return verdict


def run_one(tb_path: Path, rtl, timeout: int):
    name = tb_path.stem
    tb_dir = str(tb_path.parent)
    log_dir = REPO / "artifacts" / "qualification" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"{name}.log"
    compile_cmd = [
        "iverilog", "-g2012",
        "-s", name,
        "-I", str(REPO / "includes"),
        "-I", str(REPO / "common"),
        "-I", tb_dir,
        "-o"
    ]
    try:
        with tempfile.TemporaryDirectory() as td:
            vvp = Path(td) / f"{name}.vvp"
            compile_cmd.extend([str(vvp), *rtl, str(tb_path)])
            c_to = 600 if any(k in name for k in ("titan_x", "integ_periph")) else 180
            c = subprocess.run(
                compile_cmd,
                capture_output=True, text=True, errors="replace",
                timeout=c_to, cwd=str(REPO)
            )
            if c.returncode != 0:
                tail = (c.stderr or c.stdout).strip().splitlines()[-4:]
                log_content = (
                    f"================================================================================\n"
                    f"Testbench: {name}\n"
                    f"Path: {tb_path}\n"
                    f"Verdict: COMPILE_FAIL\n"
                    f"Compile Return Code: {c.returncode}\n"
                    f"Compile Command: {' '.join(compile_cmd)}\n"
                    f"================================================================================\n"
                    f"--- Compilation Stderr/Stdout ---\n"
                    f"{c.stdout}\n{c.stderr}\n"
                    f"================================================================================\n"
                )
                log_file.write_text(log_content)
                return dict(name=name, path=str(tb_path), verdict="COMPILE_FAIL", tail=tail)

            s_to = 600 if any(k in name for k in ("titan_x", "integ_periph", "ecdsa", "secure_boot")) else timeout
            r = subprocess.run(
                ["vvp", str(vvp)],
                capture_output=True, text=True, errors="replace",
                timeout=s_to, cwd=str(REPO)
            )
            log = r.stdout + r.stderr
            verdict = judge_verdict(r.returncode, log)
            tail = [l for l in log.strip().splitlines() if l.strip()][-4:]
            log_content = (
                f"================================================================================\n"
                f"Testbench: {name}\n"
                f"Path: {tb_path}\n"
                f"Verdict: {verdict}\n"
                f"Compile Return Code: {c.returncode}\n"
                f"Simulation Return Code: {r.returncode}\n"
                f"Compile Command: {' '.join(compile_cmd)}\n"
                f"Sim Command: vvp {vvp}\n"
                f"================================================================================\n"
                f"--- Simulation Output ---\n"
                f"{log}\n"
                f"================================================================================\n"
            )
            log_file.write_text(log_content)
            return dict(name=name, path=str(tb_path), verdict=verdict, tail=tail)
    except subprocess.TimeoutExpired:
        log_file.write_text(f"Verdict: TIMEOUT\nPath: {tb_path}\nTimeout={timeout}s\n")
        return dict(name=name, path=str(tb_path), verdict="TIMEOUT", tail=[])
    except Exception as e:
        log_file.write_text(f"Verdict: RUNNER_ERROR\nError: {e}\n")
        return dict(name=name, path=str(tb_path), verdict=f"RUNNER_ERROR:{type(e).__name__}",
                    tail=[str(e)[:120]])


def run_self_tests() -> int:
    print("=" * 70)
    print("REGRESSION RUNNER INTEGRITY SELF-TESTS (FIND-REG-01)")
    print("=" * 70)
    cases = [
        (1, "REGRESS_RESULT: PASS\nALL TESTS PASSED\nSegmentation fault (core dumped)", "CRASHED", "PASS overridden by abnormal nonzero exit"),
        (139, "REGRESS_RESULT: PASS\nALL TESTS PASSED", "CRASHED", "SIGSEGV (139) exit overrides PASS"),
        (0, "REGRESS_RESULT: PASS", "PASS", "Standard REGRESS_RESULT marker"),
        (0, "VERDICT: ✅ PASS — All tests passed", "PASS", "Standard VERDICT PASS marker"),
        (0, "ALL TESTS PASSED\nTotal Errors: 0", "PASS", "Scorecard ALL TESTS PASSED"),
        (0, "REGRESS_RESULT: FAIL\n[TESTBENCH FAILED]", "FAIL", "Explicit FAIL marker"),
        (0, "REGRESS_RESULT: PASS\n[TESTBENCH FAILED]", "FAIL", "FAIL string overrides PASS marker"),
        (0, "REGRESS_RESULT: PASS\nFATAL: Memory timeout", "FAIL", "FATAL string overrides PASS marker"),
        (0, "REGRESS_RESULT: PASS\nwire value: 4'b01x0", "SUSPECT_PASS_XDATA", "Genuine Verilog X-state detection"),
        (0, "REGRESS_RESULT: PASS\ngot= xxxx", "SUSPECT_PASS_XDATA", "Uninitialized got=x detection"),
        (0, "REGRESS_RESULT: PASS\nLoading 0x8000_0000 from imem.hex", "PASS", "Hex formatting & .hex extension safe from X match"),
        (0, "Random simulation completed with no markers", "NO_VERDICT", "Absence of pass criteria yields NO_VERDICT")
    ]
    all_ok = True
    for rc, log, exp, desc in cases:
        got = judge_verdict(rc, log)
        ok = (got == exp)
        mark = "✓" if ok else "✗"
        print(f" {mark} [{desc}]: got={got}, exp={exp}")
        if not ok:
            all_ok = False
    print("=" * 70)
    verdict_str = "ALL SELF-TESTS PASSED" if all_ok else "SELF-TESTS FAILED"
    print(f"Result: {verdict_str}")
    return 0 if all_ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("-j", "--jobs", type=int, default=8)
    ap.add_argument("--json", default="")
    ap.add_argument("--self-test", "--adversarial", dest="self_test", action="store_true", help="Execute runner verification self-tests")
    args = ap.parse_args()

    if args.self_test:
        return run_self_tests()

    rtl = rtl_files()
    all_tbs = tb_files()
    tbs = [t for t in all_tbs if args.only.lower() in t.stem.lower()]
    print(f"Executing regression across {len(tbs)} canonical testbenches (with {len(rtl)} RTL modules)...\n")

    results = []
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        futs = {ex.submit(run_one, t, rtl, args.timeout): t for t in tbs}
        for f in cf.as_completed(futs):
            res = f.result()
            results.append(res)
            mark = {"PASS": "✓", "FAIL": "✗"}.get(res["verdict"], "?")
            print(f" {mark} {res['verdict']:<20} {res['name']}")

    order = {"FAIL": 0, "CRASHED": 1, "TIMEOUT": 2, "COMPILE_FAIL": 3,
             "SUSPECT_PASS_XDATA": 4, "NO_VERDICT": 5, "PASS": 6}
    results.sort(key=lambda d: (order.get(d["verdict"], 9), d["name"]))

    counts = {}
    for r in results:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1

    print("\n" + "=" * 60)
    for v, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"  {n:>3}  {v}")
    total = len(results)
    true_pass = counts.get("PASS", 0)
    print(f"\nTRUE PASS RATE: {true_pass}/{total}"
          f" ({100*true_pass/max(total,1):.1f}%)")

    # Save to artifacts directory
    art_dir = REPO / "artifacts" / "qualification"
    art_dir.mkdir(parents=True, exist_ok=True)
    out_json = Path(args.json) if args.json else (art_dir / "regression_results.json")
    out_json.write_text(json.dumps(results, indent=2))
    print(f"Results written to: {out_json}")

    if DEVLOG.exists():
        devlog_out = DEVLOG / f"regress_{args.only or 'full'}.json"
        devlog_out.write_text(json.dumps(results, indent=1))

    return 0 if counts.get("FAIL", 0) == 0 and counts.get("COMPILE_FAIL", 0) == 0 and true_pass == total else 1


if __name__ == "__main__":
    sys.exit(main())
