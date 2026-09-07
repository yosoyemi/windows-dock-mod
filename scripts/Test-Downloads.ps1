#Requires -Version 5.1
# Isolated regression checks: does not install software or change the taskbar.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot 'Install-EmiDock.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$function = $ast.Find({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-FileDownload'
}, $true)
. ([scriptblock]::Create($function.Extent.Text))
function Write-Log { param($Message, $Color) }
function Start-Sleep { param($Seconds) }
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('emi-download-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$fixture = Join-Path $testRoot 'fixture.bin'
$destination = Join-Path $testRoot 'cache\asset.bin'
[IO.File]::WriteAllBytes($fixture, [byte[]](1..200))
$expected = (Get-FileHash -LiteralPath $fixture).Hash
$script:calls = 0
$script:scenario = 'success'
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec, $UserAgent, $ErrorAction)
    $script:calls++
    if ($script:scenario -eq 'network' -or ($script:scenario -eq 'retry' -and $script:calls -eq 1)) {
        [IO.File]::WriteAllText($OutFile, 'partial')
        throw 'Simulated connection reset'
    }
    if ($script:scenario -eq 'corrupt') { [IO.File]::WriteAllBytes($OutFile, [byte[]](2..201)); return }
    if ($script:scenario -eq 'short') { [IO.File]::WriteAllText($OutFile, 'short'); return }
    Copy-Item -LiteralPath $fixture -Destination $OutFile
}
try {
    $arguments = @{ Url = 'https://example.invalid/asset'; OutFile = $destination; ExpectedSha256 = $expected; MinBytes = 200 }
    Get-FileDownload @arguments
    Assert ($script:calls -eq 1) 'Initial download failed'
    $script:scenario = 'network'
    Get-FileDownload @arguments
    Assert ($script:calls -eq 1) 'Verified cache should work offline'

    foreach ($scenario in @('retry', 'corrupt', 'short', 'network')) {
        [IO.File]::WriteAllText($destination, 'previous file')
        $script:scenario = $scenario
        $script:calls = 0
        $caught = $false
        try { Get-FileDownload @arguments } catch { $caught = $true }
        if ($scenario -eq 'retry') {
            Assert (-not $caught -and $script:calls -eq 2) 'Retry did not recover'
            Assert ((Get-FileHash -LiteralPath $destination).Hash -eq $expected) 'Retry produced invalid data'
        } else {
            Assert ($caught -and $script:calls -eq 3) "Expected three failed attempts: $scenario"
            Assert ([IO.File]::ReadAllText($destination) -eq 'previous file') 'Failure replaced previous file'
        }
        Assert (@(Get-ChildItem -LiteralPath (Split-Path $destination) -Filter '*.partial').Count -eq 0) 'Partial file left behind'
    }
    Write-Host 'PASS: download, offline cache, retry, hash mismatch, truncated file, network failure and cleanup.' -ForegroundColor Green
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $allowed = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\emi-download-test-'
    if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
