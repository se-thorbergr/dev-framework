#!/usr/bin/env pwsh
# dev-framework MDK config verifier (MIT License)
# Implements config validation per docs/spec/tooling/SharedLibrary.md


[CmdletBinding()]
param(
    [string[]]$Config,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
    @'
Usage: Verify-Mdk2Config.ps1 [--config <path>] [config ...]

Validate that the provided MDK2 configuration files contain the required
[mdk] section and keys (type, trace, minify, ignores).
When no configuration is specified, the repository se-config.ini is used.
'@ | Write-Host
}

if ($Help) {
    Show-Usage
    exit 0
}

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptDir
$defaultConfig = Join-Path $repoRoot 'se-config.ini'

$configs = @()
if ($PSBoundParameters.ContainsKey('Config')) {
    $configs += $Config
}

if ($args.Count -gt 0) {
    for ($i = 0; $i -lt $args.Count; $i++) {
        $token = $args[$i]
        switch ($token) {
            '--config' {
                if ($i + 1 -ge $args.Count) {
                    Write-Error 'missing value for --config'
                    exit 2
                }
                $i++
                $configs += $args[$i]
                continue
            }
            '-h' {
                Show-Usage
                exit 0
            }
            '--help' {
                Show-Usage
                exit 0
            }
            default {
                $configs += $token
            }
        }
    }
}

if (-not $configs -or $configs.Count -eq 0) {
    $configs = @($defaultConfig)
}

function Resolve-ConfigPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }

    $fallback = Join-Path $scriptDir $Path
    if (Test-Path -LiteralPath $fallback) {
        return (Resolve-Path -LiteralPath $fallback).Path
    }

    return $null
}

$requiredKeys = 'type','trace','minify','ignores'
$exitCode = 0

foreach ($cfg in $configs) {
    $resolved = Resolve-ConfigPath -Path $cfg
    if (-not $resolved) {
        Write-Error ("config not found: {0}" -f $cfg)
        $exitCode = 2
        continue
    }

    $content = Get-Content -LiteralPath $resolved
    if (-not ($content | Where-Object { $_ -match '^\s*\[mdk\]' })) {
        Write-Error ("missing [mdk] section in {0}" -f $resolved)
        $exitCode = 3
        continue
    }

    $missing = @()
    foreach ($key in $requiredKeys) {
        if (-not ($content | Where-Object { $_ -match ("^\s*{0}\s*=" -f [regex]::Escape($key)) })) {
            $missing += $key
        }
    }

    if ($missing.Count -gt 0) {
        Write-Error ("missing keys ({0}) in {1}" -f ($missing -join ', '), $resolved)
        $exitCode = 3
        continue
    }

    Write-Host ("[info] verified {0}" -f $resolved)
}

exit $exitCode
