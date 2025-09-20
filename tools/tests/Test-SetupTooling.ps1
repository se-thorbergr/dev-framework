#!/usr/bin/env pwsh
# dev-framework setup tests (MIT License)
# Validates setup tooling per docs/spec/tooling/SetupTooling.md

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$setupScript = Join-Path $repoRoot 'tools/Setup.ps1'

if (-not (Test-Path -LiteralPath $setupScript)) {
    Write-Error "Setup script missing at $setupScript"
    exit 1
}

$global:Failures = 0
$global:Runs = 0

function Assert-Contains {
    param(
        [string]$Expected,
        [string]$Actual,
        [string]$Message
    )
    if (-not $Actual.Contains($Expected)) {
        throw ("Assert-Contains failed. Missing: {0}. {1}" -f $Expected, $Message)
    }
}

function Invoke-Test {
    param(
        [string]$Name,
        [ScriptBlock]$Body
    )
    $script:Runs++
    try {
        & $Body
        Write-Host ("PASS {0}" -f $Name)
    }
    catch {
        Write-Error ("FAIL {0}: {1}" -f $Name, ($_ | Out-String).Trim())
        $script:Failures++
    }
}

function New-ValidConfig {
    param([string]$Path)
    @'
[mdk]
type=programmableblock
trace=off
minify=none
ignores=obj/**/*,MDK/**/*,**/*.debug.cs
binarypath=auto
'@ | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-InvalidConfig {
    param([string]$Path)
    @'
[mdk]
type=programmableblock
'@ | Set-Content -LiteralPath $Path -Encoding UTF8
}

Invoke-Test -Name 'setup notes-only success' -Body {
    $cfg = [System.IO.Path]::GetTempFileName()
    New-ValidConfig -Path $cfg
    $game = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
    $bin = Join-Path $game 'Bin64'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null

    $output = (& $setupScript --notes-only --config $cfg --game-path $game 2>&1 | Out-String)
    Assert-Contains 'Using config file' $output 'config message'
    Assert-Contains 'Resolved Space Engineers binary path' $output 'binary path message'

    Remove-Item -LiteralPath $cfg -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $game -Recurse -Force -ErrorAction SilentlyContinue
}

Invoke-Test -Name 'setup invalid config fails' -Body {
    $cfg = [System.IO.Path]::GetTempFileName()
    New-InvalidConfig -Path $cfg
    $output = $null
    $exitCode = 0
    try {
        $output = (& $setupScript --notes-only --config $cfg 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    catch {
        $exitCode = $LASTEXITCODE
        $output = ($_ | Out-String)
    }
    finally {
        Remove-Item -LiteralPath $cfg -ErrorAction SilentlyContinue
    }
    if (-not $exitCode) { $exitCode = 1 }
    if ($exitCode -eq 0) {
        throw 'expected non-zero exit'
    }
}

Invoke-Test -Name 'setup conflicting codex flags' -Body {
    $cfg = [System.IO.Path]::GetTempFileName()
    New-ValidConfig -Path $cfg
    $exitCode = 0
    try {
        & $setupScript --notes-only --config $cfg --setup-codex --skip-codex *> $null
        $exitCode = $LASTEXITCODE
    }
    catch {
        $exitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item -LiteralPath $cfg -ErrorAction SilentlyContinue
    }
    if (-not $exitCode) { $exitCode = 1 }
    if ($exitCode -eq 0) {
        throw 'expected non-zero exit for conflicting flags'
    }
}

if ($Failures -gt 0) {
    Write-Error ("Setup.ps1 tests: {0}/{1} failed" -f $Failures, $Runs)
    exit 1
}

Write-Host ("Setup.ps1 tests: {0} passed" -f $Runs)
