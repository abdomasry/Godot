"""Isolated Godot regression runner. Never trusts an exit code alone."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT = ROOT.parent / "Godot_v4.7.2-stable_win64_console.exe"

def errors(output: str) -> list[str]:
    # Host certificate discovery is unrelated to offline gameplay. No script errors allowed.
    return [line for line in output.splitlines()
            if re.search(r"SCRIPT ERROR:|Parse Error:|ERROR:|ASSERT_FAIL|ObjectDB instances were leaked", line)
            and "Error parsing some certificates" not in line
            and "Failed to read the root certificate store." not in line]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    parser.add_argument("--suite", default="regression")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--project", type=Path, default=ROOT / "godot/masterGame")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--resolution", default="360x640")
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    evidence = ROOT / "generated" / "qa" / stamp
    evidence.mkdir(parents=True)
    snapshot = {}
    for directory in ("godot/masterGame/scripts", "automation", "configs"):
        for path in (ROOT / directory).rglob("*"):
            if path.is_file() and "__pycache__" not in path.parts:
                snapshot[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    (evidence / "source_hashes.json").write_text(json.dumps(snapshot, indent=2), encoding="utf-8")
    assert errors("SCRIPT ERROR: synthetic") and errors("ASSERT_FAIL intentional")
    assert not errors("all fine")
    with tempfile.TemporaryDirectory(prefix="gamefactory-qa-") as isolated:
        env = dict(os.environ, APPDATA=isolated, LOCALAPPDATA=isolated, QA_EVIDENCE_DIR=str(evidence))
        commands = [
            [str(args.godot), "--headless", "--path", str(args.project), "--editor", "--import", "--quit"],
            [str(args.godot), *([] if args.render else ["--headless"]), "--fixed-fps", "60", "--resolution", args.resolution, "--path", str(args.project), "--script", "res://tests/%s.gd" % args.suite],
        ]
        results = []
        for index, command in enumerate(commands):
            if args.verbose: command.append("--verbose")
            try:
                run = subprocess.run(command, capture_output=True, text=True, env=env, timeout=args.timeout)
                output = run.stdout + run.stderr
                failures = errors(output)
                if index == 1 and '"suite_complete":true' not in output.replace(" ", ""):
                    failures.append("Missing suite completion marker")
                result = {"command": command, "exit_code": run.returncode, "errors": failures}
            except subprocess.TimeoutExpired as exc:
                output = str(exc)
                result = {"command": command, "exit_code": -1, "errors": ["timeout"]}
            (evidence / ("%d.log" % index)).write_text(output, encoding="utf-8")
            results.append(result)
        passed = all(r["exit_code"] == 0 and not r["errors"] for r in results)
        (evidence / "result.json").write_text(json.dumps({"passed": passed, "runs": results}, indent=2), encoding="utf-8")
        print(json.dumps({"passed": passed, "evidence": str(evidence), "runs": results}, indent=2))
        return 0 if passed else 1

if __name__ == "__main__":
    raise SystemExit(main())
