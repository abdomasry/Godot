"""Run real-engine balance diagnostics with four fixed seeds in isolated saves."""
from pathlib import Path
import json
import subprocess
import sys
import argparse

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preset")
    args = parser.parse_args()
    command = [sys.executable, str(ROOT / "automation/qa/run_engine.py"), "--suite", "engine_balance", "--timeout", "600"]
    if args.preset:
        from automation.build.isolated_build import stage
        directory, manifest = stage(args.preset, 42, include_tests=True)
        command.extend(["--project", str(directory / "project")])
    result = subprocess.run(command, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode: return result.returncode
    evidence = Path(json.loads(result.stdout)["evidence"])
    lines = (evidence / "1.log").read_text(encoding="utf-8").splitlines()
    report = json.loads(next(line.removeprefix("BALANCE_JSON ") for line in lines if line.startswith("BALANCE_JSON ")))
    if args.preset: report["build_manifest"] = manifest
    (evidence / "engine_balance_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0

if __name__ == "__main__": raise SystemExit(main())
