#Requires -Version 5.1
<#
.SYNOPSIS
  Instala el dock Emi Liquid Glass.
  Windows 11: Windhawk + preset Liquid Glass.
  Windows 10: vidrio esmerilado nativo + iconos centrados visibles (TaskbarX).
#>
[CmdletBinding()]
param(
    [switch]$SkipWindowsTweaks,
    [switch]$NoExplorerRestart
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [Console]::OutputEncoding
} catch { }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ArchivePath = Join-Path $ProjectRoot "dist\emi-windows-dock.whdata"
$RegPath = Join-Path $ProjectRoot "registry\dock-windows-settings.reg"
$LogPath = Join-Path $env:TEMP "emi-dock-install.log"
$StateDir = Join-Path $env:LOCALAPPDATA "EmiWindowsDock"
$StatePath = Join-Path $StateDir "state.json"
$DownloadDir = Join-Path $StateDir "downloads"

$WindhawkRelease = "2.0.0-alpha.3"
$WindhawkUrl = "https://github.com/ramensoftware/windhawk/releases/download/2.0.0-alpha.3/windhawk_setup.exe"
$WindhawkSha256 = "DF1DDF24B5AE8F57E961C0DBC5E934A3820EACCC732794C0E7CCE5D37CD56AFC"
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\Windhawk"

$TaskbarXVersion = "1.7.8.0"
$EmiDockRoot = Join-Path $env:LOCALAPPDATA "Programs\EmiDock"
$TaskbarXDir = Join-Path $EmiDockRoot "TaskbarX"
$TaskbarXSha256X64 = "AB192D20ED1FF6A88FEF856B1A0DCF997E5022437C09A686C28356B43DC5A3E2"
$GlassCsPath = Join-Path $PSScriptRoot "EmiDockGlass.cs"
$GlassExePath = Join-Path $EmiDockRoot "EmiDockGlass.exe"
$StartupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$StartupLnk = Join-Path $StartupDir "Emi Liquid Glass Dock.lnk"
$GlassStartupLnk = Join-Path $StartupDir "Emi Dock Glass.lnk"

$RequiredMods = @(
    "windows-11-taskbar-styler",
    "taskbar-icon-size",
    "taskbar-dock-animation-plus",
    "taskbar-auto-hide-speed",
    "taskbar-auto-hide-when-maximized",
    "taskbar-auto-hide-custom-activation-area",
    "taskbar-tray-show-on-hover",
    "taskbar-z-order-override"
)

# Center icons only. Glass (blur + rounded float) is applied by EmiDockGlass.exe
# so TaskbarX does not paint a dark overlay on top of the icons.
$TaskbarXArgs = @(
    "-tbs=0",
    "-tbsg=0",
    "-as=quinticeaseout",
    "-asp=350",
    "-cib=1",
    "-cfsa=1",
    "-rzbt=1",
    "-tpop=100",
    "-tsop=100"
)

# Used only if the native glass helper cannot be compiled.
$TaskbarXFallbackArgs = @(
    "-tbs=2",
    "-tbr=16",
    "-tbsg=0",
    "-as=quinticeaseout",
    "-asp=350",
    "-cib=1",
    "-cfsa=1",
    "-rzbt=1",
    "-color=236;244;255;72",
    "-tpop=100",
    "-tsop=100"
)

function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch { }
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Log "==> $Message" Cyan
}

function Format-ProcessArgs {
    param([string[]]$Parts)
    ($Parts | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '""') + '"' } else { $_ }
    }) -join ' '
}

function Save-InstallState {
    param(
        [string]$Kind,
        [int]$Build
    )
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    $payload = @{
        kind = $Kind
        build = $Build
        installedAt = (Get-Date -Format o)
    } | ConvertTo-Json
    Set-Content -Path $StatePath -Value $payload -Encoding UTF8
}

function Get-RegistryText {
    param($Object, [string]$Name)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return "" }
    return [string]$prop.Value
}

function Get-OsInfo {
    $cv = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $build = 0
    $buildText = Get-RegistryText $cv "CurrentBuildNumber"
    if ([string]::IsNullOrWhiteSpace($buildText)) { $buildText = Get-RegistryText $cv "CurrentBuild" }
    [void][int]::TryParse($buildText, [ref]$build)
    if ($build -le 0) { $build = [System.Environment]::OSVersion.Version.Build }

    $product = Get-RegistryText $cv "ProductName"
    if ([string]::IsNullOrWhiteSpace($product)) { $product = "Windows" }
    $isWin11 = $build -ge 22000
    if ($isWin11) { $product = $product -replace "Windows 10", "Windows 11" }
    $display = Get-RegistryText $cv "DisplayVersion"
    $name = $product
    if (-not [string]::IsNullOrWhiteSpace($display)) { $name = "$product $display" }

    [pscustomobject]@{
        Build        = $build
        IsWindows11  = $isWin11
        Name         = $name
        ProductName  = $product
    }
}

function Assert-SupportedWindows {
    param($Os)
    if ($Os.Build -lt 19041) {
        throw "Este dock necesita Windows 10 (2004+, build 19041) o Windows 11.`nEsta PC es $($Os.Name), build $($Os.Build)."
    }
}

function Invoke-WindhawkCli {
    param(
        [Parameter(Mandatory = $true)][string]$CliPath,
        [Parameter(Mandatory = $true)][string[]]$CliArgs,
        [switch]$CaptureOutput,
        [switch]$Silent
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $CliPath
    $psi.Arguments = Format-ProcessArgs $CliArgs
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $ProjectRoot

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    if (-not $Silent) {
        if ($stdout) { Write-Log $stdout.TrimEnd() DarkGray }
        if ($stderr) { Write-Log $stderr.TrimEnd() DarkGray }
    }
    if ($CaptureOutput) {
        return @{ ExitCode = $proc.ExitCode; Stdout = $stdout }
    }
    return $proc.ExitCode
}

function Assert-ExtractedPack {
    $bat = Join-Path $ProjectRoot "INSTALAR.bat"
    $fromExplorerZipView = $ProjectRoot -match '\\Temp\d+_.*\.zip' -or $ProjectRoot -match '\\7z[OES]'
    $missingCore = -not (Test-Path $bat) -or -not (Test-Path (Join-Path $PSScriptRoot "Install-EmiDock.ps1"))
    if ($fromExplorerZipView -or $missingCore) {
        throw @"
Parece que estas ejecutando el instalador desde dentro del ZIP.
Extrae la carpeta completa (clic derecho en el zip -> Extraer todo) y despues abre INSTALAR.bat.
"@
    }
}

function Unblock-PackFiles {
    Get-ChildItem -Path $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
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

function Get-FileDownload {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$ExpectedSha256 = "",
        [int]$MinBytes = 100000
    )
    $OutFile = [IO.Path]::GetFullPath($OutFile)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    # Only a matching pinned hash allows reuse, including when offline.
    if ($ExpectedSha256 -and (Test-Path -LiteralPath $OutFile -PathType Leaf)) {
        if ((Get-Item -LiteralPath $OutFile).Length -ge $MinBytes -and
            (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash -eq $ExpectedSha256) {
            Write-Log "Usando descarga verificada: $([IO.Path]::GetFileName($OutFile))" DarkGray
            return
        }
    }
    $partial = "$OutFile.$([guid]::NewGuid().ToString('N')).partial"
    $attempts = 3
    $lastError = ""
    for ($i = 1; $i -le $attempts; $i++) {
        try {
            Write-Log "Descarga intento $i de $attempts..." DarkGray
            Invoke-WebRequest -Uri $Url -OutFile $partial -UseBasicParsing -TimeoutSec 600 -UserAgent "EmiWindowsDock/1.0.1" -ErrorAction Stop
            if ((Get-Item -LiteralPath $partial).Length -lt $MinBytes) {
                throw "El archivo descargado esta incompleto o vacio."
            }
            if ($ExpectedSha256) {
                $hash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
                if ($hash -ne $ExpectedSha256) {
                    throw "SHA256 incorrecto. Esperado: $ExpectedSha256. Obtenido: $hash."
                }
            }
            Move-Item -LiteralPath $partial -Destination $OutFile -Force
            Write-Log "Descarga completa y verificada." Green
            return
        } catch {
            $lastError = $_.Exception.Message
            Write-Log "Fallo la descarga: $lastError" Yellow
            if ($i -lt $attempts) {
                Write-Log "Reintentando en $(2 * $i) segundos..." DarkGray
                Start-Sleep -Seconds (2 * $i)
            }
        } finally {
            if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
        }
    }
    throw "No se pudo descargar el archivo despues de $attempts intentos. Revisa internet, proxy o firewall y vuelve a intentar.`nDetalle: $lastError`n$Url"
}

function Install-Windhawk {
    Write-Step "Descargando Windhawk $WindhawkRelease"
    $setup = Join-Path $DownloadDir "windhawk-$WindhawkRelease.exe"
    Get-FileDownload -Url $WindhawkUrl -OutFile $setup -ExpectedSha256 $WindhawkSha256
    Unblock-File -Path $setup -ErrorAction SilentlyContinue

    Write-Step "Instalando Windhawk (portable, sin administrador)"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $setup
    $psi.Arguments = "/S /PORTABLE /D=$InstallDir"
    $psi.UseShellExecute = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
        throw "El instalador de Windhawk salio con codigo $($proc.ExitCode)"
    }

    $cli = Join-Path $InstallDir "windhawk-cli.exe"
    $deadline = (Get-Date).AddSeconds(45)
    while (-not (Test-Path $cli)) {
        if ((Get-Date) -gt $deadline) {
            throw "Windhawk se instalo pero no aparece windhawk-cli.exe en $InstallDir"
        }
        Start-Sleep -Milliseconds 400
    }
    return $cli
}

function Ensure-WindhawkRunning {
    param([string]$CliPath)
    $appRoot = Split-Path -Parent $CliPath
    $exe = Join-Path $appRoot "windhawk.exe"
    $running = Get-Process -Name "windhawk" -ErrorAction SilentlyContinue
    if (-not $running -and (Test-Path $exe)) {
        Write-Step "Iniciando Windhawk"
        Start-Process -FilePath $exe -ArgumentList "-tray-only" -WindowStyle Hidden | Out-Null
    }

    $deadline = (Get-Date).AddSeconds(40)
    do {
        $code = Invoke-WindhawkCli -CliPath $CliPath -CliArgs @("--json", "mod", "list") -Silent
        if ($code -eq 0) { return }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)

    throw "Windhawk esta instalado pero no responde. Abri Windhawk y volve a ejecutar INSTALAR.bat."
}

function Import-DockArchive {
    param([string]$CliPath)

    Write-Step "Importando mods y ajustes del dock"
    $importArgs = @(
        "--yes", "data", "import", $ArchivePath,
        "--yes", "--confirm-app-restart", "--on-conflict", "overwrite", "--no-app-settings"
    )
    $code = Invoke-WindhawkCli -CliPath $CliPath -CliArgs $importArgs
    if ($code -ne 0) {
        Write-Log "Importacion online fallo (codigo $code). Reintentando offline..." Yellow
        $offlineArgs = $importArgs + @("--offline")
        $code = Invoke-WindhawkCli -CliPath $CliPath -CliArgs $offlineArgs
        if ($code -ne 0) {
            throw "No se pudo importar el preset (codigo $code). Mira el log: $LogPath"
        }
    }
}

function Enable-DockMods {
    param([string]$CliPath)

    Write-Step "Activando mods del dock"
    foreach ($id in $RequiredMods) {
        $code = Invoke-WindhawkCli -CliPath $CliPath -CliArgs @("--yes", "mod", "enable", $id)
        if ($code -ne 0) { throw "No se pudo activar $id (codigo $code)." }
    }
}

function Assert-ModsEnabled {
    param([string]$CliPath)

    $listed = Invoke-WindhawkCli -CliPath $CliPath -CliArgs @("--json", "mod", "list") -CaptureOutput -Silent
    $jsonText = $listed.Stdout
    if ($listed.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($jsonText)) {
        throw "No se pudo leer la lista de mods de Windhawk."
    }
    $parsed = $jsonText | ConvertFrom-Json
    $mods = @($parsed.data.mods)
    $missing = @()
    $disabled = @()
    foreach ($id in $RequiredMods) {
        $found = $mods | Where-Object { $_.id -eq $id } | Select-Object -First 1
        if (-not $found) { $missing += $id }
        elseif (-not $found.enabled) { $disabled += $id }
    }
    if ($missing.Count -gt 0 -or $disabled.Count -gt 0) {
        throw "El dock no quedo completo.`nFaltan: $($missing -join ', ')`nDesactivados: $($disabled -join ', ')"
    }
    Write-Log "8/8 mods activos." Green
}

function Enable-TaskbarAutoHide {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    if (-not (Test-Path $key)) { return }
    $settings = (Get-ItemProperty -Path $key).Settings
    if ($null -eq $settings -or $settings.Length -lt 9) { return }
    $settings[8] = [byte]($settings[8] -bor 0x03)
    Set-ItemProperty -Path $key -Name Settings -Value $settings
}

function Disable-TaskbarAutoHide {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    if (-not (Test-Path $key)) { return }
    $props = Get-ItemProperty -Path $key
    if (-not $props.PSObject.Properties["Settings"]) { return }
    $settings = $props.Settings
    if ($null -eq $settings -or $settings.Length -lt 9) { return }
    $settings[8] = [byte](($settings[8] -band (-bnot 0x02)) -bor 0x01)
    Set-ItemProperty -Path $key -Name Settings -Value $settings
}

function Set-HkcuDword {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord
}

function Apply-WindowsTweaks {
    Write-Step "Aplicando ajustes de Windows 11"
    if (Test-Path $RegPath) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "reg.exe"
        $psi.Arguments = Format-ProcessArgs @("import", $RegPath)
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $reg = New-Object System.Diagnostics.Process
        $reg.StartInfo = $psi
        [void]$reg.Start()
        $null = $reg.StandardOutput.ReadToEnd()
        $null = $reg.StandardError.ReadToEnd()
        $reg.WaitForExit()
        if ($reg.ExitCode -ne 0) {
            Write-Log "Aviso: algunos ajustes de registro ya estaban en uso. El dock igual se aplica." Yellow
        }
    }
    Enable-TaskbarAutoHide
}

function Apply-Windows10Tweaks {
    Write-Step "Aplicando ajustes de Windows 10 (iconos grandes, barra visible, transparencia)"
    Set-HkcuDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarSmallIcons" 0
    Set-HkcuDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    Set-HkcuDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 0
    Set-HkcuDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 1
    Set-HkcuDword "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0
    Set-HkcuDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" "PeopleBand" 0
    Set-HkcuDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 1
    Disable-TaskbarAutoHide
}

function Restart-ExplorerShell {
    Write-Step "Reiniciando Explorer para aplicar el dock"
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 1000
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe | Out-Null
    }
}

function Get-OsArch {
    if ($env:PROCESSOR_ARCHITEW6432) { return $env:PROCESSOR_ARCHITEW6432 }
    return $env:PROCESSOR_ARCHITECTURE
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

function Stop-EmiDockGlass {
    Get-Process -Name "EmiDockGlass" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
}

function New-StartupShortcut {
    param(
        [string]$LinkPath,
        [string]$TargetPath,
        [string]$Arguments = "",
        [string]$WorkDir = ""
    )
    $ws = New-Object -ComObject WScript.Shell
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LinkPath) | Out-Null
    $sc = $ws.CreateShortcut($LinkPath)
    $sc.TargetPath = $TargetPath
    $sc.Arguments = $Arguments
    if ($WorkDir) { $sc.WorkingDirectory = $WorkDir }
    $sc.WindowStyle = 7
    $sc.Save()
}

function Compile-EmiDockGlass {
    if (-not (Test-Path $GlassCsPath)) {
        throw "Falta scripts\EmiDockGlass.cs"
    }
    New-Item -ItemType Directory -Force -Path $EmiDockRoot | Out-Null
    Stop-EmiDockGlass
    if (Test-Path $GlassExePath) { Remove-Item $GlassExePath -Force }

    $source = Get-Content -Path $GlassCsPath -Raw -Encoding UTF8
    try {
        Add-Type -TypeDefinition $source -OutputAssembly $GlassExePath -OutputType WindowsApplication -ErrorAction Stop
    } catch {
        Write-Log "Add-Type fallo, compilando con csc.exe..." DarkGray
        $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
        if (-not (Test-Path $csc)) {
            $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
        }
        if (-not (Test-Path $csc)) {
            throw "No hay compilador C# en esta PC. $($_.Exception.Message)"
        }
        $tmp = Join-Path $env:TEMP "EmiDockGlass.cs"
        Set-Content -Path $tmp -Value $source -Encoding UTF8
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $csc
        $psi.Arguments = Format-ProcessArgs @("/nologo", "/target:winexe", "/optimize+", "/out:$GlassExePath", $tmp)
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        [void]$proc.Start()
        $out = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        if ($proc.ExitCode -ne 0 -or -not (Test-Path $GlassExePath)) {
            throw "No se pudo compilar el efecto glass.`n$out"
        }
    }
    if (-not (Test-Path $GlassExePath)) {
        throw "No se genero EmiDockGlass.exe"
    }
    Unblock-File -Path $GlassExePath -ErrorAction SilentlyContinue
    Write-Log "Efecto liquid glass listo: $GlassExePath" DarkGray
}

function Start-EmiDockGlass {
    Stop-EmiDockGlass
    Start-Process -FilePath $GlassExePath -WindowStyle Hidden | Out-Null
    New-StartupShortcut -LinkPath $GlassStartupLnk -TargetPath $GlassExePath -WorkDir $EmiDockRoot
}

function Install-TaskbarX {
    $arch = Get-OsArch
    $asset = switch ($arch) {
        "ARM64" { "TaskbarX_$TaskbarXVersion`_arm64.zip" }
        "x86"   { "TaskbarX_$TaskbarXVersion`_x86.zip" }
        "AMD64" { "TaskbarX_$TaskbarXVersion`_x64.zip" }
        default { throw "Arquitectura no compatible con TaskbarX: $arch" }
    }
    $url = "https://github.com/ChrisAnd1998/TaskbarX/releases/download/$TaskbarXVersion/$asset"
    $expected = switch ($arch) {
        "AMD64" { $TaskbarXSha256X64 }
        "x86" { "5B7BFCBEF460C6842F7A75DBDC977AE3C3504EB9B95F1F6FA934974BEC806E78" }
        "ARM64" { "14D4FE288A26CBD6EC02560D7CF5E9EB72DD5790F5E4F9FA4A1A712B98FF8EB9" }
    }

    Write-Step "Descargando TaskbarX $TaskbarXVersion ($arch)"
    $zip = Join-Path $DownloadDir $asset
    Get-FileDownload -Url $url -OutFile $zip -ExpectedSha256 $expected -MinBytes 500000
    Unblock-File -Path $zip -ErrorAction SilentlyContinue

    Write-Step "Instalando TaskbarX (portable, sin administrador)"
    $staging = Join-Path $EmiDockRoot ("TaskbarX-stage-" + [guid]::NewGuid().ToString('N'))
    $backup = "$staging-previous"
    $promoted = $false
    try {
        Expand-Archive -LiteralPath $zip -DestinationPath $staging
        $found = Get-ChildItem -LiteralPath $staging -Recurse -Filter "TaskbarX.exe" | Select-Object -First 1
        if (-not $found) { throw "El ZIP de TaskbarX no contiene TaskbarX.exe." }
        $relativeExe = $found.FullName.Substring($staging.Length + 1)
        Stop-TaskbarX
        if (Test-Path -LiteralPath $TaskbarXDir) { Move-Item -LiteralPath $TaskbarXDir -Destination $backup }
        try {
            Move-Item -LiteralPath $staging -Destination $TaskbarXDir
            $promoted = $true
        } catch {
            if (Test-Path -LiteralPath $backup) { Move-Item -LiteralPath $backup -Destination $TaskbarXDir }
            throw
        }
        $exe = Join-Path $TaskbarXDir $relativeExe
    } finally {
        $cleanup = @($staging)
        if ($promoted) { $cleanup += $backup }
        foreach ($candidate in $cleanup) {
            $resolved = [IO.Path]::GetFullPath($candidate)
            $allowedRoot = [IO.Path]::GetFullPath($EmiDockRoot).TrimEnd('\') + '\'
            if (-not $resolved.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Ruta temporal fuera del directorio de EmiDock."
            }
            if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    Unblock-File -Path $exe -ErrorAction SilentlyContinue
    return $exe
}

function Start-TaskbarXDock {
    param(
        [string]$ExePath,
        [string[]]$Args
    )

    Write-Step "Centrando iconos (TaskbarX)"
    Stop-TaskbarX
    Start-Sleep -Milliseconds 400
    Start-Process -FilePath $ExePath -ArgumentList (Format-ProcessArgs $Args) -WindowStyle Hidden | Out-Null
    New-StartupShortcut -LinkPath $StartupLnk -TargetPath $ExePath -Arguments ($Args -join " ") -WorkDir (Split-Path -Parent $ExePath)
    Write-Log "Inicio automatico: $StartupLnk" DarkGray
}

function Install-Win11Dock {
    if (-not (Test-Path $ArchivePath)) {
        throw "Falta el preset: $ArchivePath"
    }

    $cli = Find-WindhawkCli
    if (-not $cli) {
        $cli = Install-Windhawk
    } else {
        Write-Step "Windhawk encontrado: $cli"
    }

    Ensure-WindhawkRunning -CliPath $cli
    Import-DockArchive -CliPath $cli
    Enable-DockMods -CliPath $cli
    Assert-ModsEnabled -CliPath $cli
}

function Install-Win10Dock {
    Write-Log "Windows 10 usa su propia barra. Se aplica vidrio esmerilado + iconos centrados y visibles." Cyan
    $tbx = Install-TaskbarX
    if (-not $SkipWindowsTweaks) { Apply-Windows10Tweaks }
    $glassOk = $false
    $tbxArgs = $TaskbarXFallbackArgs
    try {
        Write-Step "Creando efecto liquid glass (acrylic + dock flotante)"
        Compile-EmiDockGlass
        $glassOk = $true
        $tbxArgs = $TaskbarXArgs
    } catch {
        Write-Log "No se pudo crear el helper glass: $($_.Exception.Message)" Yellow
        Write-Log "Se usa blur de TaskbarX como respaldo (iconos visibles, sin barra negra)." Yellow
    }

    if (-not $NoExplorerRestart) {
        Restart-ExplorerShell
        Start-Sleep -Milliseconds 1500
    }

    Start-TaskbarXDock -ExePath $tbx -Args $tbxArgs
    if ($glassOk) {
        Start-Sleep -Milliseconds 600
        Start-EmiDockGlass
    }
}

if (Test-Path $LogPath) { Remove-Item $LogPath -Force -ErrorAction SilentlyContinue }
"Emi Liquid Glass Dock install log $(Get-Date -Format o)" | Set-Content -Path $LogPath -Encoding UTF8

$exitCode = 0
try {
    Write-Host ""
    Write-Host "  Emi Liquid Glass Dock" -ForegroundColor Green
    Write-Host "  Instalador para Windows 10 y 11" -ForegroundColor DarkGray
    Write-Host ""

    Assert-ExtractedPack
    $os = Get-OsInfo
    Write-Log "Sistema: $($os.Name)  build $($os.Build)" DarkGray
    Assert-SupportedWindows -Os $os
    Unblock-PackFiles

    if ($os.IsWindows11) {
        Install-Win11Dock
        if (-not $SkipWindowsTweaks) { Apply-WindowsTweaks }
        if (-not $NoExplorerRestart) { Restart-ExplorerShell }
        Save-InstallState -Kind "win11-windhawk" -Build $os.Build
        Write-Host ""
        Write-Log "Listo. Pasa el mouse por el centro inferior de la pantalla." Green
    } else {
        Install-Win10Dock
        Save-InstallState -Kind "win10-glass" -Build $os.Build
        Write-Host ""
        Write-Log "Listo. Dock de Windows 10: vidrio esmerilado, iconos centrados y visibles." Green
        Write-Log "La barra queda flotante abajo. No se oculta sola." DarkGray
    }

    Write-Log "Para quitarlo: DESINSTALAR.bat" DarkGray
    Write-Log "Log: $LogPath" DarkGray
    Write-Host ""
} catch {
    $exitCode = 1
    Write-Host ""
    Write-Log $_.Exception.Message Red
    Write-Log "Log: $LogPath" DarkGray
    Write-Host ""
}

exit $exitCode
