#Requires -Version 5.1
<#
.SYNOPSIS
  Quita el dock. En Windows 11 desactiva los mods de Windhawk (no borra Windhawk).
  En Windows 10 detiene TaskbarX y borra el acceso de inicio.
#>
[CmdletBinding()]
param(
    [switch]$RemoveMods
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\Windhawk"
$EmiDockRoot = Join-Path $env:LOCALAPPDATA "Programs\EmiDock"
$TaskbarXDir = Join-Path $EmiDockRoot "TaskbarX"
$StartupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$StartupLnk = Join-Path $StartupDir "Emi Liquid Glass Dock.lnk"
$GlassStartupLnk = Join-Path $StartupDir "Emi Dock Glass.lnk"
$StateDir = Join-Path $env:LOCALAPPDATA "EmiWindowsDock"

function Find-WindhawkCli {
    $candidates = @(
        (Join-Path $InstallDir "windhawk-cli.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\WindhawkDock\windhawk-cli.exe"),
        (Join-Path ${env:ProgramFiles} "Windhawk\windhawk-cli.exe")
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} "Windhawk\windhawk-cli.exe"
    }
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command windhawk-cli.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Stop-TaskbarX {
    $exe = Join-Path $TaskbarXDir "TaskbarX.exe"
    if (Test-Path $exe) {
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $exe
            $psi.Arguments = "-stop"
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $proc = [System.Diagnostics.Process]::Start($psi)
            if ($proc) { $proc.WaitForExit(8000) | Out-Null }
        } catch { }
    }
    Get-Process -Name "TaskbarX" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
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

$didSomething = $false

Get-Process -Name "EmiDockGlass" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Stop-TaskbarX
foreach ($lnk in @($StartupLnk, $GlassStartupLnk)) {
    if (Test-Path $lnk) {
        Remove-Item $lnk -Force
        $didSomething = $true
    }
}
if (Test-Path $EmiDockRoot) {
    Remove-Item $EmiDockRoot -Recurse -Force
    Write-Host "Dock de Windows 10 (glass + TaskbarX) desinstalado." -ForegroundColor DarkGray
    $didSomething = $true
}

$cli = Find-WindhawkCli
if ($cli) {
    foreach ($id in $mods) {
        if ($RemoveMods) {
            & $cli --yes mod remove $id 2>$null
        } else {
            & $cli --yes mod disable $id 2>$null
        }
    }
    Write-Host "Mods de Windhawk desactivados. Windhawk sigue instalado." -ForegroundColor DarkGray
    $didSomething = $true
}

$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
if (Test-Path $key) {
    $props = Get-ItemProperty -Path $key
    if ($props.PSObject.Properties["Settings"] -and $props.Settings -and $props.Settings.Length -ge 9) {
        $settings = $props.Settings
        $settings[8] = $settings[8] -band (-bnot 0x02)
        Set-ItemProperty -Path $key -Name Settings -Value $settings
    }
}

if (Test-Path $StateDir) {
    Remove-Item $StateDir -Recurse -Force -ErrorAction SilentlyContinue
}

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe | Out-Null
}

if ($didSomething) {
    Write-Host "Dock desactivado." -ForegroundColor Green
} else {
    Write-Host "No se encontro una instalacion del dock." -ForegroundColor Yellow
}
if ($cli -and -not $RemoveMods) {
    Write-Host "Para borrar los mods: .\scripts\Uninstall-EmiDock.ps1 -RemoveMods" -ForegroundColor DarkGray
}
