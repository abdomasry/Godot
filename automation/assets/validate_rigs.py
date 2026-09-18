"""Validate frame bounds, alpha, counts and pose variation. Does not replace visual QA."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
COUNTS = {"idle":4, "run":8, "attack":4, "hit":2, "death":6, "telegraph":6}

def validate(folder: Path):
    manifest = json.loads((folder / "manifest.json").read_text())
    issues, checked, hashes = [], 0, {}
    for role, animations in manifest["roles"].items():
        for name, definition in animations.items():
            path = folder / definition["file"]
            with Image.open(path) as source:
                if source.mode != "RGBA" or max(source.size) > 2048: issues.append(f"{path.name}: requires RGBA atlas <=2048")
                hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
                poses = set()
                for x, y, width, height in definition["rects"]:
                    if x < 0 or y < 0 or x+width > source.width or y+height > source.height: issues.append(f"{role}/{name}: out of bounds")
                    frame = source.crop((x,y,x+width,y+height)).convert("RGBA")
                    bbox = frame.getchannel("A").getbbox()
                    if bbox is None: issues.append(f"{role}/{name}: empty frame")
                    elif bbox[0] == 0 or bbox[1] == 0 or bbox[2] == width or bbox[3] == height:
                        issues.append(f"{role}/{name}: frame touches cell border")
                    poses.add(hashlib.sha256(frame.tobytes()).hexdigest())
                    checked += 1
                state = name.split("_")[0]
                if len(definition["rects"]) != COUNTS[state]: issues.append(f"{role}/{name}: wrong count")
                if len(poses) < 2: issues.append(f"{role}/{name}: static animation")
    return {"variant":manifest["variant"], "checked_frames":checked, "issues":issues, "atlas_sha256":hashes, "visual_review_required":True}

def main():
    reports = [validate(folder) for folder in (ROOT / "godot/masterGame/assets/rigs").iterdir() if folder.is_dir()]
    destination = ROOT / "generated/qa/rig_validation.json"
    destination.write_text(json.dumps(reports, indent=2), encoding="utf-8")
    print(json.dumps([{k:v for k,v in report.items() if k != "atlas_sha256"} for report in reports], indent=2))
    return int(any(report["issues"] for report in reports))

if __name__ == "__main__": raise SystemExit(main())
