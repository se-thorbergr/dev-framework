#!/usr/bin/env pwsh
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$formatScript = Join-Path $PSScriptRoot 'format.ps1'
if (-not (Test-Path $formatScript)) {
    Write-Error "format.ps1 helper not found at $formatScript"
    exit 1
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Error 'git executable not found; unable to discover staged files.'
    exit 1
}

$staged = (& $git.Source diff --name-only --cached) | Where-Object { $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Error 'git diff --name-only --cached failed.'
    exit 1
}

$targets = @()
foreach ($path in $staged) {
    if ($path -match '\.(cs|ps1|psm1|psd1|sh|md)$') {
        $targets += $path
    }
}

if ($targets.Count -eq 0) {
    Write-Output 'No staged files matched formatting targets.'
    exit 0
}

$invokeArgs = @()
foreach ($path in $targets) {
    $invokeArgs += '--files'
    $invokeArgs += $path
}

$invokeArgs += $Args

& pwsh -NoLogo -NoProfile -File $formatScript @invokeArgs
exit $LASTEXITCODE
