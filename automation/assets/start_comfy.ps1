# Starts only the project-owned environment, bound to localhost.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$app = Join-Path $root '.tools/comfy/ComfyUI'
$python = Join-Path $root '.tools/comfy/venv/Scripts/python.exe'
foreach ($folder in @('custom_nodes','models','input','output','temp','user')) {
    New-Item -ItemType Directory -Path (Join-Path $app $folder) -Force | Out-Null
}
Start-Process -FilePath $python -ArgumentList @('-s', (Join-Path $app 'main.py'), '--listen','127.0.0.1','--port','8188', '--output-directory',(Join-Path $root 'generated/comfy'), '--extra-model-paths-config',(Join-Path $root 'automation/assets/local_model_paths.yaml'), '--disable-auto-launch','--disable-dynamic-vram','--disable-async-offload','--disable-pinned-memory','--disable-mmap','--disable-api-nodes') -WorkingDirectory $app -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root 'generated/qa/comfy_isolated_stdout.log') -RedirectStandardError (Join-Path $root 'generated/qa/comfy_isolated_stderr.log') -PassThru | Select-Object Id
