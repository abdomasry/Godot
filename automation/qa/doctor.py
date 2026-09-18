"""Report actual local tool availability without installing or modifying anything."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
def probe(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=20)
        return {"found":True, "exit_code":result.returncode, "output":(result.stdout + result.stderr).strip()[:2000]}
    except (OSError, subprocess.TimeoutExpired) as exc: return {"found":False, "error":str(exc)}

def main():
    sdk = Path(os.environ.get("LOCALAPPDATA", "")) / "Android/Sdk"
    report = {"checked_at":datetime.now(timezone.utc).isoformat(), "python":probe([sys.executable, "--version"]),
        "godot":probe([str(ROOT.parent / "Godot_v4.7.2-stable_win64_console.exe"), "--version"]),
        "java17":probe(["C:/Program Files/Java/jdk-17/bin/java.exe", "-version"]),
        "android_devices":probe([str(sdk / "platform-tools/adb.exe"), "devices"]),
        "android_avds":probe([str(sdk / "emulator/emulator.exe"), "-list-avds"]),
        "comfy_existing":Path("A:/Programs/ai_generating/ComfyUI_windows_portable/ComfyUI/main.py").exists(),
        "comfy_separate_ready":(ROOT / ".tools/comfy/setup_result.json").exists()}
    try:
        with urllib.request.urlopen("http://127.0.0.1:8188/system_stats", timeout=3) as response:
            report["comfy_api"] = {"online":True, "data":json.load(response)}
    except OSError: report["comfy_api"] = {"online":False}
    destination = ROOT / "generated/qa" / ("doctor_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + ".json")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print("Evidence: " + str(destination))
    return 0

if __name__ == "__main__": raise SystemExit(main())
