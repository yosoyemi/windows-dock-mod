#Requires -Version 5.1
<#
.SYNOPSIS
  Disables the dock mods. Does not uninstall Windhawk.
#>
[CmdletBinding()]
param(
    [switch]$RemoveMods
)

$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\Windhawk"

function Find-WindhawkCli {
    $candidates = @(
        (Join-Path $InstallDir "windhawk-cli.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\WindhawkDock\windhawk-cli.exe"),
        (Join-Path ${env:ProgramFiles} "Windhawk\windhawk-cli.exe")
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

$mods = @(
    "windows-11-taskbar-styler",
    "taskbar-icon-size",
    "taskbar-dock-animation-plus",
    "taskbar-auto-hide-speed",
    "taskbar-auto-hide-when-maximized",
    "taskbar-auto-hide-custom-activation-area",
    "taskbar-tray-show-on-hover",
    "taskbar-z-order-override"
)

$cli = Find-WindhawkCli
if (-not $cli) {
    Write-Host "Windhawk CLI not found. Nothing to undo." -ForegroundColor Yellow
    exit 0
}

foreach ($id in $mods) {
    if ($RemoveMods) {
        & $cli --yes mod remove $id 2>$null
    } else {
        & $cli --yes mod disable $id 2>$null
    }
}

$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
if (Test-Path $key) {
    $settings = (Get-ItemProperty -Path $key).Settings
    if ($settings -and $settings.Length -ge 9) {
        $settings[8] = $settings[8] -band (-bnot 0x02)
        Set-ItemProperty -Path $key -Name Settings -Value $settings
    }
}

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe | Out-Null
}

Write-Host "Dock mods disabled. Windhawk itself is still installed." -ForegroundColor Green
if (-not $RemoveMods) {
    Write-Host "To also uninstall the mods: .\Uninstall-EmiDock.ps1 -RemoveMods" -ForegroundColor DarkGray
}
