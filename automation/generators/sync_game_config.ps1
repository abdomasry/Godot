param(
    [string]$GameId = "prototype"
)

$source = Join-Path $PSScriptRoot "../../configs/games/$GameId.json"
$destinationDirectory = Join-Path $PSScriptRoot "../../godot/masterGame/configs"
$destination = Join-Path $destinationDirectory "active_game.json"

if (-not (Test-Path $source)) {
    throw "Source game config was not found: $source"
}

New-Item -ItemType Directory -Force $destinationDirectory | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Force
Write-Host "Synced legacy-compatible $source to $destination"
