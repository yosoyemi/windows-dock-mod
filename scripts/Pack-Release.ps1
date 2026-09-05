#Requires -Version 5.1
<#
.SYNOPSIS
  Builds a zip friends can download and a copy ready for GitHub Releases.
#>
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$zipName = "Emi-Windows-Dock-v1.0.0.zip"
$zipPath = Join-Path $dist $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$stage = Join-Path $env:TEMP "emi-windows-dock-pack"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$include = @(
    "README.md",
    "LICENSE",
    "CREDITS.md",
    "INSTALAR.bat",
    "DESINSTALAR.bat",
    "presets",
    "registry",
    "screenshots",
    "scripts",
    "docs",
    "dist\emi-windows-dock.whdata"
)

foreach ($item in $include) {
    $src = Join-Path $root $item
    if (-not (Test-Path $src)) { continue }
    $dest = Join-Path $stage $item
    $destDir = Split-Path -Parent $dest
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Copy-Item $src $dest -Recurse -Force
}

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -Force
Remove-Item $stage -Recurse -Force

$sizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "Created $zipPath ($sizeMb MB)" -ForegroundColor Green
Write-Host "Share that zip, or upload it as a GitHub Release asset."
