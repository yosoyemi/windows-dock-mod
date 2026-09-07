#Requires -Version 5.1
<#
.SYNOPSIS
  Arma el zip para enviar y el instalador EXE del portafolio.
#>
[CmdletBinding()]
param(
    [switch]$SkipExe
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$version = "1.0.1"
$folderName = "Emi-Windows-Dock"
$zipName = "Emi-Windows-Dock-v$version.zip"
$exeName = "Emi-Windows-Dock-Setup-v$version.exe"
$zipPath = Join-Path $dist $zipName
$exePath = Join-Path $dist $exeName

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-CleanDir([string]$Path) {
    if (Test-Path $Path) { Remove-Item $Path -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Copy-IntoPack([string]$Stage) {
    $include = @(
        "LEEME.txt",
        "README.md",
        "LICENSE",
        "CREDITS.md",
        "INSTALAR.bat",
        "DESINSTALAR.bat",
        "presets",
        "registry",
        "screenshots",
        "docs\INSTALACION.md",
        "dist\emi-windows-dock.whdata"
    )

    foreach ($item in $include) {
        $src = Join-Path $root $item
        if (-not (Test-Path $src)) { throw "Falta $item" }
        $dest = Join-Path $Stage $item
        $destDir = Split-Path -Parent $dest
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        Copy-Item $src $dest -Recurse -Force
    }

    $scripts = Join-Path $Stage "scripts"
    New-Item -ItemType Directory -Force -Path $scripts | Out-Null
    Copy-Item (Join-Path $root "scripts\Install-EmiDock.ps1") $scripts -Force
    Copy-Item (Join-Path $root "scripts\Uninstall-EmiDock.ps1") $scripts -Force
    Copy-Item (Join-Path $root "scripts\EmiDockGlass.cs") $scripts -Force
}

function Write-ZipFromFolder([string]$SourceFolder, [string]$DestinationZip) {
    if (Test-Path $DestinationZip) { Remove-Item $DestinationZip -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $SourceFolder,
        $DestinationZip,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )
}

$whdata = Join-Path $root "dist\emi-windows-dock.whdata"
if (-not (Test-Path $whdata)) {
    throw "Falta dist\emi-windows-dock.whdata. Exportalo antes con scripts\Export-EmiDock.ps1"
}

$stage = Join-Path $env:TEMP "emi-windows-dock-pack"
New-CleanDir $stage
$inner = Join-Path $stage $folderName
New-CleanDir $inner
Copy-IntoPack $inner

Write-ZipFromFolder $inner $zipPath

$sha = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
$shaPath = Join-Path $dist "Emi-Windows-Dock-v$version.sha256.txt"
@"
$sha  $zipName
"@ | Set-Content -Path $shaPath -Encoding ASCII

$sizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "ZIP: $zipPath ($sizeMb MB)" -ForegroundColor Green
Write-Host "SHA256: $sha"

$payload = Join-Path $root "setup\EmiDockSetup\payload.zip"
New-Item -ItemType Directory -Force -Path (Split-Path $payload) | Out-Null
if (Test-Path $payload) { Remove-Item $payload -Force }
Copy-Item $zipPath $payload -Force

if ($SkipExe) {
    Remove-Item $stage -Recurse -Force
    Write-Host "SkipExe: no se compiló el instalador."
    return
}

$csproj = Join-Path $root "setup\EmiDockSetup\EmiDockSetup.csproj"
if (-not (Test-Path $csproj)) { throw "Falta $csproj" }

Write-Host "Compilando instalador EXE (Native AOT)..." -ForegroundColor Cyan
$binRoot = Join-Path $root "setup\EmiDockSetup\bin"
if (Test-Path $binRoot) { Remove-Item $binRoot -Recurse -Force }
dotnet publish $csproj -c Release -r win-x64 --self-contained true -p:PublishAot=true
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish fallo. El ZIP ya esta listo en $zipPath"
}

$built = Get-ChildItem -Path $binRoot -Recurse -Filter "Emi-Windows-Dock-Setup.exe" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $built) {
    throw "No aparecio Emi-Windows-Dock-Setup.exe despues de publicar"
}
$built = $built.FullName

Copy-Item $built $exePath -Force
$exeMb = [math]::Round((Get-Item $exePath).Length / 1MB, 2)
$exeSha = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash
Add-Content -Path $shaPath -Value "$exeSha  $exeName" -Encoding ASCII

Remove-Item $stage -Recurse -Force

Write-Host "EXE: $exePath ($exeMb MB)" -ForegroundColor Green
Write-Host ""
Write-Host "Para amigos: manda el ZIP."
Write-Host "Para el portafolio: sube ZIP + EXE."
