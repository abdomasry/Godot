<# Local debug export from an isolated project; no store upload or release signing. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [string]$Preset = "zombieSurvivor",
    [int]$Seed = 12345,
    [int]$Runs = 10000,
    [ValidateSet("debug", "release")][string]$Configuration = "debug",
    [string]$PythonPath = "python"
)
$ErrorActionPreference = "Stop"
if ($Configuration -ne "debug") {
    throw "Release is blocked until visual, simulator, device and signing gates are approved."
}
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$builder = Join-Path $repoRoot "automation/build/isolated_build.py"
& $PythonPath $builder $Preset --seed $Seed --godot $GodotPath --export-debug
if ($LASTEXITCODE -ne 0) { throw "Isolated debug export failed. Inspect the per-build log." }
