"""Local-only ComfyUI generation with resumable prompt IDs and provenance."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import time
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:8188"

def api(path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(BASE + path, data=data, headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

def workflow(prompt, seed, width, height, prefix):
    def node(kind, **inputs): return {"class_type":kind, "inputs":inputs}
    return {
        "1":node("UNETLoader", unet_name="flux-2-klein-base-4b-fp8.safetensors", weight_dtype="fp8_e4m3fn"),
        "2":node("CLIPLoader", clip_name="qwen_3_4b.safetensors", type="flux2", device="default"),
        "3":node("VAELoader", vae_name="full_encoder_small_decoder.safetensors"),
        "4":node("CLIPTextEncode", clip=["2",0], text=prompt),
        "5":node("CLIPTextEncode", clip=["2",0], text=""),
        "6":node("CFGGuider", model=["1",0], positive=["4",0], negative=["5",0], cfg=4.0),
        "7":node("RandomNoise", noise_seed=seed),
        "8":node("KSamplerSelect", sampler_name="euler"),
        "9":node("Flux2Scheduler", steps=28, width=width, height=height),
        "10":node("EmptyFlux2LatentImage", width=width, height=height, batch_size=1),
        "11":node("SamplerCustomAdvanced", noise=["7",0], guider=["6",0], sampler=["8",0], sigmas=["9",0], latent_image=["10",0]),
        "12":node("VAEDecode", samples=["11",0], vae=["3",0]),
        "13":node("SaveImage", images=["12",0], filename_prefix=prefix),
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--retry-failed", action="store_true")
    args = parser.parse_args()
    for attempt in range(60):
        try:
            api("/system_stats")
            break
        except OSError:
            if attempt == 59: raise RuntimeError("Local ComfyUI did not become ready; inspect startup log")
            if attempt % 10 == 0: print("Waiting for local ComfyUI startup...", flush=True)
            time.sleep(2)
    if not args.name.replace("_", "").isalnum(): raise ValueError("safe asset name required")
    graph = workflow(args.prompt, args.seed, args.width, args.height, args.name)
    digest = hashlib.sha256(json.dumps(graph, sort_keys=True).encode()).hexdigest()
    folder = ROOT / "generated/assets" / (args.name + "_" + digest[:12])
    folder.mkdir(parents=True, exist_ok=True)
    state_path = folder / "job.json"
    (folder / "workflow.json").write_text(json.dumps(graph, indent=2), encoding="utf-8")
    state = json.loads(state_path.read_text()) if state_path.exists() else {"workflow_sha256":digest, "license_status":"UNVERIFIED_DO_NOT_RELEASE", "visual_status":"UNREVIEWED"}
    if args.retry_failed and state.get("history", {}).get("status", {}).get("status_str") == "error":
        state.setdefault("previous_attempts", []).append({"prompt_id":state.pop("prompt_id"), "history":state.pop("history")})
    if "prompt_id" not in state:
        state.update(api("/prompt", {"prompt":graph, "client_id":"mobile-game-factory"}))
        state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
    print("Local job " + state["prompt_id"], flush=True)
    for attempt in range(600):
        history = api("/history/" + state["prompt_id"])
        if state["prompt_id"] in history:
            result = history[state["prompt_id"]]
            state["history"] = result
            state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
            if result.get("status", {}).get("status_str") == "error":
                print(json.dumps(result.get("status"), indent=2), flush=True)
                return 1
            if result.get("outputs"):
                print(json.dumps({"manifest":str(state_path), "outputs":result["outputs"]}, indent=2), flush=True)
                return 0
        if attempt % 10 == 0: print("Waiting for local generation...", flush=True)
        time.sleep(2)
    raise TimeoutError("Job still pending; rerun same command to resume tracking, not duplicate it")

if __name__ == "__main__": raise SystemExit(main())
