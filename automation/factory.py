"""Factory CLI: generate, validate, simulate, or prepare a shared Godot variant."""
from __future__ import annotations

import argparse
import json
import sys
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from automation.generators.generate_game import generate_variant, print_summary
from automation.models.game_config import validate_config
from automation.simulation.simulate_balance import simulate


def generated_config_path(preset: str) -> Path:
    return ROOT / "generated" / preset / "game_config.json"


def load_generated(preset: str) -> dict:
    path = generated_config_path(preset)
    if not path.is_file():
        raise FileNotFoundError("Generate this preset first: %s" % preset)
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["generate", "validate", "simulate", "prepare", "doctor", "qa", "build", "batch", "simulate-engine"])
    parser.add_argument("preset", nargs="?")
    parser.add_argument("--activate", action="store_true")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--runs", type=int, default=1000)
    args = parser.parse_args()
    try:
        scripts = {"doctor":"automation/qa/doctor.py", "qa":"automation/qa/run_engine.py", "simulate-engine":"automation/simulation/engine_balance.py"}
        if args.command in scripts:
            command = [sys.executable, str(ROOT / scripts[args.command])]
            if args.command == "simulate-engine" and args.preset: command.extend(["--preset", args.preset])
            return subprocess.call(command)
        if args.command in {"build", "batch"}:
            from automation.build.isolated_build import stage, build_debug
            presets = [args.preset] if args.preset else [path.stem for path in sorted((ROOT / "configs/presets").glob("*.json"))]
            for preset in presets:
                directory, _ = stage(preset, args.seed)
                print(build_debug(directory, ROOT.parent / "Godot_v4.7.2-stable_win64_console.exe"))
            return 0
        if not args.preset:
            raise ValueError("This command requires a preset")
        if args.command in {"generate", "prepare"}:
            variant_dir, config, manifest = generate_variant(args.preset, args.seed, activate=args.activate)
            print_summary(variant_dir, config, manifest)
        else:
            variant_dir, config = generated_config_path(args.preset).parent, load_generated(args.preset)
        validate_config(config)
        if args.command == "validate":
            print("Validation: PASS")
        if args.command in {"simulate", "prepare"}:
            report = simulate(config, args.runs, args.seed)
            report_path = variant_dir / "balance_report.json"
            report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print("Balance: %s" % report["balance_status"])
            print("Warnings: %d" % len(report["warnings"]))
            print("Report: %s" % report_path.relative_to(ROOT))
        if args.command in {"simulate", "prepare"} and (report["balance_status"] in {"FAIL", "UNSUPPORTED"} or report.get("release_gate") == "UNSUPPORTED"):
            return 2
        return 0
    except (OSError, ValueError) as error:
        print("Factory failed: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
