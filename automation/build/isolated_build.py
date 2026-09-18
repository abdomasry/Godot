"""Stage immutable per-variant Godot projects. Debug builds are not release approval."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from automation.generators.generate_game import generate_variant, runtime_config, canonical_json
from automation.models.game_config import validate_config
from automation.qa.run_engine import errors

def stage(preset: str, seed: int, output_root: Path | None = None, include_tests: bool = False):
    _, config, manifest = generate_variant(preset, seed, activate=False)
    source = ROOT / "godot/masterGame"
    style = config.get("gameplay", {}).get("combat_style", "zombie")
    required = [source / "assets/rigs" / style / "manifest.json", source / "assets/arenas" / (style + ".png"), source / "assets/icons" / (style + ".svg")]
    if not all(path.is_file() for path in required): raise ValueError("Missing reviewed art for " + style)
    excluded = {".godot", "monsterSurvivor"} | (set() if include_tests else {"tests"})
    files = sorted(p for p in source.rglob("*") if p.is_file() and not set(p.relative_to(source).parts) & excluded and p.name != "active_game.json")
    if not include_tests:
        def belongs_to_other_style(path: Path) -> bool:
            relative = str(path.relative_to(source)).replace("\\", "/")
            for folder in ("rigs", "arenas", "icons"):
                if any(relative.startswith("assets/%s/%s" % (folder, other)) for other in ("zombie", "space", "ninja") if other != style): return True
            return relative.startswith(("assets/zombie_arena_background", "assets/zombie_character_sheet", "assets/hunter_run_sheet", "assets/app_icon"))
        files = [p for p in files if not belongs_to_other_style(p)]
    hashes = {str(p.relative_to(source)).replace("\\", "/"):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    fingerprint = hashlib.sha256(canonical_json({"config":config, "source":hashes}).encode()).hexdigest()
    build_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + "_" + fingerprint[:12]
    directory = (output_root or ROOT / "generated") / preset / build_id
    project = directory / "project"
    project.mkdir(parents=True, exist_ok=False)
    for path in files:
        destination = project / path.relative_to(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    (project / "configs/active_game.json").write_text(json.dumps(runtime_config(validate_config(config)), indent=2), encoding="utf-8")
    package = "com.mobilegamefactory." + preset.lower()
    project_text = (project / "project.godot").read_text(encoding="utf-8")
    project_text = re.sub(r'^config/name=.*$', 'config/name=' + json.dumps(config["metadata"]["display_name"]), project_text, flags=re.M)
    project_text = re.sub(r'^config/icon=.*$', 'config/icon="res://assets/icons/' + style + '.svg"', project_text, flags=re.M)
    (project / "project.godot").write_text(project_text, encoding="utf-8")
    preset_file = project / "export_presets.cfg"
    preset_text = preset_file.read_text(encoding="utf-8")
    for key, value in {"package/unique_name":package, "package/name":config["metadata"]["display_name"], "version/name":config["metadata"]["version"]}.items():
        preset_text = re.sub(r'^' + re.escape(key) + r'=.*$', key + '=' + json.dumps(value), preset_text, flags=re.M)
    preset_file.write_text(preset_text, encoding="utf-8")
    manifest.update(build_id=build_id, source_sha256=hashes, fingerprint=fingerprint, package=package, release_approved=False,
                    release_blockers=["physical Android QA", "production signing", "live ad provider and privacy configuration", "store listing review"])
    (directory / "build_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return directory, manifest

def build_debug(directory: Path, godot: Path):
    manifest_path = directory / "build_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    destination = ROOT / "builds/android" / manifest["variant_id"] / manifest["build_id"]
    destination.mkdir(parents=True, exist_ok=False)
    temporary = destination / "pending.apk"
    command_base = [str(godot), "--headless", "--path", str(directory / "project")]
    for name, arguments in [("import", ["--editor", "--import", "--quit"]), ("export", ["--export-debug", "Android", str(temporary)])]:
        result = subprocess.run(command_base + arguments, capture_output=True, text=True, timeout=300)
        output = result.stdout + result.stderr
        (destination / (name + ".log")).write_text(output, encoding="utf-8")
        if result.returncode or errors(output): raise RuntimeError("Build failed; inspect " + str(destination / (name + ".log")))
    if not temporary.is_file() or temporary.stat().st_size < 1000000: raise RuntimeError("Missing or implausible fresh APK")
    artifact = destination / (manifest["variant_id"] + "-debug.apk")
    os.replace(temporary, artifact)
    manifest.update(artifact=str(artifact), artifact_sha256=hashlib.sha256(artifact.read_bytes()).hexdigest(), built_at=datetime.now(timezone.utc).isoformat())
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return artifact

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("preset")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--export-debug", action="store_true")
    parser.add_argument("--godot", type=Path, default=ROOT.parent / "Godot_v4.7.2-stable_win64_console.exe")
    args = parser.parse_args()
    directory, manifest = stage(args.preset, args.seed)
    print("Staged " + str(directory), flush=True)
    if args.export_debug: print("Debug APK: " + str(build_debug(directory, args.godot)))
    return 0

if __name__ == "__main__": raise SystemExit(main())
