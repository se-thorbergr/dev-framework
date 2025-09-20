#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$testsRoot = Split-Path -Parent $scriptDir
$toolsRoot = Split-Path -Parent $testsRoot
$modulePath = Join-Path $toolsRoot 'lib/DevFramework.Tooling.psm1'
Import-Module $modulePath -Force

$extra = @{ '--name' = 'value:UserName'; '-n' = 'alias:--name' }
$result = Parse-CommonArgs -Args $args -ExtraDescriptors $extra -CaptureExtraValues
if (-not $result.Success) {
    Write-Log -Level 'error' -Message 'Failed to parse arguments'
    Emit-Summary -ExitCode 2 -Errors $result.Errors
    exit 2
}

Initialize-Logging -Options $result.Options
Write-Log -Level 'info' -Message 'starting sample'

if ($result.Options.DryRun) {
    Write-Log -Level 'info' -Message 'dry-run enabled'
}

if ($result.ExtraValues['UserName']) {
    Write-Log -Level 'info' -Message ("name={0}" -f $result.ExtraValues['UserName'])
}

if ($result.RemainingArgs.Length -gt 0) {
    Register-Action -Description ("parsed {0}" -f $result.RemainingArgs[0])
}

Emit-Summary -ExitCode 0
