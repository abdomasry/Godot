"""Generate a validated, reproducible game variant from a template and preset."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import random
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from automation.models.game_config import CanonicalGameConfig, validate_config

GENERATOR_VERSION = "0.1.0"
SCHEMA_VERSION = "1.0"


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Recursively merge dictionaries; arrays and scalar values replace wholesale."""
    result = copy.deepcopy(base)
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def canonical_json(data: dict[str, Any]) -> str:
    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def config_hash(data: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_json(data).encode("utf-8")).hexdigest()


def set_path(data: dict[str, Any], dotted_path: str, value: Any) -> None:
    target = data
    pieces = dotted_path.split(".")
    for piece in pieces[:-1]:
        if piece not in target or not isinstance(target[piece], dict):
            raise ValueError("randomization path does not exist: %s" % dotted_path)
        target = target[piece]
    if pieces[-1] not in target:
        raise ValueError("randomization path does not exist: %s" % dotted_path)
    target[pieces[-1]] = value


def resolve_randomization(data: dict[str, Any], seed: int) -> dict[str, Any]:
    result = copy.deepcopy(data)
    rules = result.pop("randomization", {})
    if not rules:
        return result
    rng = random.Random(seed)
    for path in sorted(rules):
        rule = rules[path]
        if not isinstance(rule, dict) or "min" not in rule or "max" not in rule:
            raise ValueError("randomization '%s' needs min and max" % path)
        lower, upper = rule["min"], rule["max"]
        if not isinstance(lower, (int, float)) or not isinstance(upper, (int, float)) or lower > upper:
            raise ValueError("randomization '%s' has an invalid range" % path)
        value: int | float
        value = rng.randint(lower, upper) if isinstance(lower, int) and isinstance(upper, int) else round(rng.uniform(lower, upper), 4)
        set_path(result, path, value)
    return result


def runtime_config(config: CanonicalGameConfig) -> dict[str, Any]:
    """Flatten canonical factory config into Phase 2's stable Godot runtime keys."""
    data = config.model_dump(mode="json")
    style = data["gameplay"]["combat_style"]
    if style != "zombie":
        for upgrade in data["upgrades"]["definitions"]:
            if upgrade["id"] == "unlock_nova":
                upgrade["display_name"] = "Shadow Dash" if style == "ninja" else "Shield EMP"
                upgrade["description"] = "Dash through enemies; brief protection" if style == "ninja" else "Blast nearby enemies and refill your shield"
            elif upgrade["id"] == "nova_radius":
                upgrade["display_name"] = "Wider Dash" if style == "ninja" else "EMP Radius"
                upgrade["description"] = "Increase special ability reach"
            elif upgrade["id"] == "unlock_companion" and style == "ninja":
                upgrade["display_name"] = "Guardian Spirit"
                upgrade["description"] = "A spirit strikes nearby foes"
            elif style == "ninja" and upgrade["id"] == "projectile_speed":
                upgrade["display_name"] = "Blade Reach"
                upgrade["description"] = "Increase melee reach by 28 units"
    runtime = {
        "schema_version": data["schema_version"],
        "generator_version": data["generator_version"],
        "metadata": data["metadata"],
        "id": data["metadata"]["id"],
        "name": data["metadata"]["display_name"],
        "version": data["metadata"]["version"],
        "theme": data["theme"],
        "terminology": data["terminology"],
        "player": data["player"],
        "weapons": data["weapons"],
        "enemy": data["enemies"]["base"],
        "enemy_archetypes": data["enemies"]["archetypes"],
        "waves": {**data["waves"], "boss_every": data["bosses"]["every"], "boss_archetype": data["bosses"]["archetype"], "boss_additional_enemies": data["bosses"]["additional_enemies"]},
        "bosses": data["bosses"],
        "economy": data["economy"],
        "upgrades": data["upgrades"],
        "gameplay": data["gameplay"],
    }
    return runtime


def generate_variant(preset_name: str, seed: int, output_root: Path = ROOT / "generated", activate: bool = False) -> tuple[Path, dict[str, Any], dict[str, Any]]:
    if not re.fullmatch(r"[a-z][A-Za-z0-9_]*", preset_name):
        raise ValueError("preset must be an identifier, not a path")
    template_path = ROOT / "configs" / "templates" / "baseSurvivor.json"
    preset_path = ROOT / "configs" / "presets" / (preset_name + ".json")
    if not preset_path.is_file():
        raise FileNotFoundError("Preset not found: %s" % preset_path)
    merged = resolve_randomization(deep_merge(read_json(template_path), read_json(preset_path)), seed)
    merged["schema_version"] = SCHEMA_VERSION
    merged["generator_version"] = GENERATOR_VERSION
    config = validate_config(merged)
    canonical = config.model_dump(mode="json")
    variant_dir = output_root / config.metadata.id
    variant_dir.mkdir(parents=True, exist_ok=True)
    config_path = variant_dir / "game_config.json"
    config_path.write_text(json.dumps(canonical, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    digest = config_hash(canonical)
    manifest = {
        "variant_id": config.metadata.id,
        "display_name": config.metadata.display_name,
        "preset": preset_name,
        "template": "configs/templates/baseSurvivor.json",
        "seed": seed,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "generator_version": GENERATOR_VERSION,
        "schema_version": SCHEMA_VERSION,
        "config_hash": digest,
    }
    (variant_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if activate:
        runtime_path = ROOT / "godot" / "masterGame" / "configs" / "active_game.json"
        runtime_path.write_text(json.dumps(runtime_config(config), indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return variant_dir, canonical, manifest


def print_summary(variant_dir: Path, config: dict[str, Any], manifest: dict[str, Any]) -> None:
    print("Variant: %s" % config["metadata"]["display_name"])
    print("Preset: %s" % manifest["preset"])
    print("Seed: %s" % manifest["seed"])
    print("Weapons: %s" % ", ".join(config["weapons"]["definitions"].keys()))
    print("Enemies: %s" % ", ".join(config["enemies"]["archetypes"].keys()))
    print("Boss interval: %d waves" % config["bosses"]["every"])
    print("Config: %s" % (variant_dir.relative_to(ROOT) / "game_config.json"))
    print("Master runtime activation is opt-in (--activate). Builds use isolated projects.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preset", required=True)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--output-root", type=Path, default=ROOT / "generated")
    parser.add_argument("--no-activate", action="store_true")
    parser.add_argument("--activate", action="store_true", help="Explicitly replace the master project's active configuration")
    args = parser.parse_args()
    try:
        variant_dir, config, manifest = generate_variant(args.preset, args.seed, args.output_root, args.activate and not args.no_activate)
        print_summary(variant_dir, config, manifest)
        return 0
    except (ValueError, FileNotFoundError) as error:
        print("Generation failed: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
