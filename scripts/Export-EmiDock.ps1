#Requires -Version 5.1
<#
.SYNOPSIS
  Re-export the live Windhawk dock settings into dist\emi-windows-dock.whdata
#>
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "dist\emi-windows-dock.whdata"

$candidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\WindhawkDock\windhawk-cli.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Windhawk\windhawk-cli.exe"),
    (Join-Path ${env:ProgramFiles} "Windhawk\windhawk-cli.exe")
)
$cli = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cli) { throw "windhawk-cli.exe not found" }

$mods = "windows-11-taskbar-styler,taskbar-icon-size,taskbar-dock-animation-plus,taskbar-auto-hide-speed,taskbar-auto-hide-when-maximized,taskbar-auto-hide-custom-activation-area,taskbar-tray-show-on-hover,taskbar-z-order-override"
New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
& $cli data export --out $out --force --no-app-settings --offline --mods $mods
Write-Host "Exported $out"
