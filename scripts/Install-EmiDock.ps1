#Requires -Version 5.1
<#
.SYNOPSIS
  Installs Windhawk (if needed) and applies the Emi Liquid Glass dock preset.
#>
[CmdletBinding()]
param(
    [switch]$SkipWindowsTweaks,
    [switch]$NoExplorerRestart
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ArchivePath = Join-Path $ProjectRoot "dist\emi-windows-dock.whdata"
$RegPath = Join-Path $ProjectRoot "registry\dock-windows-settings.reg"

$WindhawkRelease = "2.0.0-alpha.3"
$WindhawkUrl = "https://github.com/ramensoftware/windhawk/releases/download/2.0.0-alpha.3/windhawk_setup.exe"
$WindhawkSha256 = "DF1DDF24B5AE8F57E961C0DBC5E934A3820EACCC732794C0E7CCE5D37CD56AFC"
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\Windhawk"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Windows11 {
    $v = [System.Environment]::OSVersion.Version
    if ($v.Major -lt 10 -or $v.Build -lt 22000) {
        throw "This dock is for Windows 11 (build 22000+). Detected build $($v.Build)."
    }
}

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

function Install-Windhawk {
    Write-Step "Downloading Windhawk $WindhawkRelease"
    $setup = Join-Path $env:TEMP "windhawk_setup_emi_dock.exe"
    Invoke-WebRequest -Uri $WindhawkUrl -OutFile $setup -UseBasicParsing

    $hash = (Get-FileHash -Path $setup -Algorithm SHA256).Hash
    if ($hash -ne $WindhawkSha256) {
        throw "Windhawk installer hash mismatch.`nExpected $WindhawkSha256`nGot      $hash"
    }

    Write-Step "Installing Windhawk (portable, no admin)"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $proc = Start-Process -FilePath $setup -ArgumentList @("/S", "/PORTABLE", "/D=$InstallDir") -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Windhawk installer exited with code $($proc.ExitCode)"
    }

    $cli = Join-Path $InstallDir "windhawk-cli.exe"
    if (-not (Test-Path $cli)) {
        throw "Windhawk installed but windhawk-cli.exe was not found at $cli"
    }
    return $cli
}

function Ensure-WindhawkRunning {
    param([string]$CliPath)
    $appRoot = Split-Path -Parent $CliPath
    $exe = Join-Path $appRoot "windhawk.exe"
    $running = Get-Process -Name "windhawk" -ErrorAction SilentlyContinue
    if (-not $running -and (Test-Path $exe)) {
        Write-Step "Starting Windhawk"
        Start-Process -FilePath $exe -ArgumentList "-tray-only" | Out-Null
        Start-Sleep -Seconds 3
    }
}

function Enable-TaskbarAutoHide {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    if (-not (Test-Path $key)) { return }
    $settings = (Get-ItemProperty -Path $key).Settings
    if ($null -eq $settings -or $settings.Length -lt 9) { return }
    # Byte 8: 0x02 = autohide, 0x01 = always on top
    $settings[8] = [byte]($settings[8] -bor 0x03)
    Set-ItemProperty -Path $key -Name Settings -Value $settings
}

function Apply-WindowsTweaks {
    Write-Step "Applying Windows 11 dock tweaks"
    if (Test-Path $RegPath) {
        & reg.exe import $RegPath | Out-Null
    }
    Enable-TaskbarAutoHide
}

function Restart-ExplorerShell {
    Write-Step "Restarting Explorer so the dock applies"
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe | Out-Null
    }
}

if (-not (Test-Path $ArchivePath)) {
    throw "Missing preset archive: $ArchivePath"
}

Write-Host "Emi Liquid Glass Dock installer" -ForegroundColor Green
Assert-Windows11

$cli = Find-WindhawkCli
if (-not $cli) {
    $cli = Install-Windhawk
} else {
    Write-Step "Using existing Windhawk: $cli"
}

Ensure-WindhawkRunning -CliPath $cli

Write-Step "Importing dock mods and settings"
& $cli data import $ArchivePath --offline --yes --confirm-app-restart --on-conflict overwrite
if ($LASTEXITCODE -ne 0) {
    throw "windhawk-cli data import failed with exit code $LASTEXITCODE"
}

if (-not $SkipWindowsTweaks) {
    Apply-WindowsTweaks
}

if (-not $NoExplorerRestart) {
    Restart-ExplorerShell
}

Write-Host ""
Write-Host "Done. Hover the bottom of the screen to reveal the dock." -ForegroundColor Green
Write-Host "To undo: run scripts\Uninstall-EmiDock.ps1" -ForegroundColor DarkGray
