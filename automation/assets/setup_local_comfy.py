"""Install a project-owned ComfyUI environment; never modifies the existing install."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import venv
import argparse

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / ".tools/comfy"
SOURCE = Path("A:/Programs/ai_generating/ComfyUI_windows_portable/ComfyUI")

def run(name, command):
    print(name, flush=True)
    with (TARGET / (name + ".log")).open("w", encoding="utf-8") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode: raise RuntimeError(name + " failed: " + str(TARGET / (name + ".log")))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repair-source-only", action="store_true")
    args = parser.parse_args()
    TARGET.mkdir(parents=True, exist_ok=True)
    destination = TARGET / "ComfyUI"
    def ignore(directory, names):
        excluded = {".git", "__pycache__"}
        if Path(directory) == SOURCE:
            excluded |= {"models", "output", "input", "temp", "user", "custom_nodes"}
        return [name for name in names if name in excluded]
    if not destination.exists() or args.repair_source_only:
        shutil.copytree(SOURCE, destination, ignore=ignore, dirs_exist_ok=True)
    for name in ("custom_nodes", "models", "input", "output", "temp", "user"):
        (destination / name).mkdir(exist_ok=True)
    if args.repair_source_only: return
    python = TARGET / "venv/Scripts/python.exe"
    if not python.exists(): venv.EnvBuilder(with_pip=True).create(TARGET / "venv")
    pins = TARGET / "constraints.txt"
    pins.write_text("torch==2.10.0\ntorchvision==0.25.0\ntorchaudio==2.10.0\n", encoding="utf-8")
    run("pytorch_install", [str(python), "-m", "pip", "install", "torch==2.10.0", "torchvision==0.25.0", "torchaudio==2.10.0", "--index-url", "https://download.pytorch.org/whl/cu128", "--timeout", "120", "--retries", "10"])
    run("dependencies_install", [str(python), "-m", "pip", "install", "-r", str(destination / "requirements.txt"), "-c", str(pins), "--timeout", "120", "--retries", "10"])
    run("cuda_smoke", [str(python), "-c", "import torch; print(torch.__version__); assert torch.cuda.is_available(); print(torch.cuda.get_device_name()); x=torch.randn(256,256,device='cuda'); print((x@x).mean().item())"])
    freeze = subprocess.check_output([str(python), "-m", "pip", "freeze"], text=True)
    (TARGET / "installed.lock.txt").write_text(freeze, encoding="utf-8")
    (TARGET / "setup_result.json").write_text(json.dumps({"status":"installed_cuda_smoke_passed", "python":str(python), "source":str(SOURCE), "existing_install_modified":False}, indent=2))
    print("Separate environment ready", flush=True)

if __name__ == "__main__": main()
