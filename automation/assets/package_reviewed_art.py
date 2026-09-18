"""Package only explicitly reviewed local generations; never approve arbitrary jobs."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
REVIEWED = {
    "zombie": ("zombie_arena_clean_7f502dda1f8c", "zombie_arena_clean_00001_.png"),
    "space": ("space_arena_2a26fd97f1b8", "space_arena_00001_.png"),
    "ninja": ("ninja_arena_3eb7ceca7d1f", "ninja_arena_00001_.png"),
}
SOURCES = {
    "qwen_3_4b.safetensors": "https://huggingface.co/Comfy-Org/z_image/blob/main/split_files/text_encoders/qwen_3_4b.safetensors",
    "flux-2-klein-base-4b-fp8.safetensors": "https://huggingface.co/black-forest-labs/FLUX.2-klein-base-4b-fp8/blob/main/flux-2-klein-base-4b-fp8.safetensors",
    "full_encoder_small_decoder.safetensors": "https://huggingface.co/black-forest-labs/FLUX.2-small-decoder/blob/main/full_encoder_small_decoder.safetensors",
}

def main():
    inventory_path = ROOT / "automation/assets/model_inventory.json"
    inventory = json.loads(inventory_path.read_text())
    for model in inventory["models"]:
        model.update(source=SOURCES[model["file"]], source_status="SHA256 matches official repository LFS metadata, checked 2026-09-18", model_family_license="Apache-2.0")
    inventory.update(checked_utc="2026-09-18", note="Official SHA256 provenance matched for all three weights. Model licensing does not certify visual quality or store acceptance.")
    inventory_path.write_text(json.dumps(inventory, indent=2), encoding="utf-8")
    target = ROOT / "godot/masterGame/assets/arenas"
    target.mkdir(parents=True, exist_ok=True)
    manifest = {"models": inventory["models"], "assets": {}, "release_approved": False,
                "review": "Agent visual inspection: clear empty arena centers, restrained backgrounds, no baked-in actors. Device readability still requires QA.",
                "rejected": ["zombie_walk_sheet_00001_.png: inconsistent poses; replaced with original layered rig animation", "zombie_arena_00001_.png: baked-in character-like objects"]}
    for style, (job, filename) in REVIEWED.items():
        source = ROOT / "generated/comfy" / filename
        state = json.loads((ROOT / "generated/assets" / job / "job.json").read_text())
        assert state["history"]["status"]["status_str"] == "success"
        shutil.copy2(source, target / (style + ".png"))
        manifest["assets"][style] = {"source": filename, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "workflow_sha256": state["workflow_sha256"], "job": job}
    (target / "provenance.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Packaged three visually reviewed arenas with provenance.")

if __name__ == "__main__": main()
