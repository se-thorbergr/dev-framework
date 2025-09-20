#!/usr/bin/env pwsh
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$modulePath = Join-Path (Split-Path -Parent $scriptDir) 'lib/DevFramework.Tooling.psm1'
Import-Module $modulePath -Force
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

$global:Failures = 0
$global:Runs = 0

function Assert-Equal {
    param(
        [Parameter(Mandatory)][object]$Expected,
        [Parameter(Mandatory)][object]$Actual,
        [string]$Message
    )

    if (-not ($Expected -eq $Actual)) {
        throw ("Assert-Equal failed. Expected: {0} Actual: {1}. {2}" -f $Expected, $Actual, $Message)
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$ExpectedSubstring,
        [Parameter(Mandatory)][string]$Actual,
        [string]$Message
    )

    if (-not $Actual.Contains($ExpectedSubstring)) {
        throw ("Assert-Contains failed. Missing: {0}. {1}" -f $ExpectedSubstring, $Message)
    }
}

function Invoke-Test {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ScriptBlock]$Body
    )

    $script:Runs++
    try {
        & $Body
        Write-Host ("PASS {0}" -f $Name)
    }
    catch {
        $details = ($_ | Out-String).Trim()
        Write-Error ("FAIL {0}: {1}" -f $Name, $details)
        $script:Failures++
    }
}

# -----------------------------
# Unit tests
# -----------------------------

Invoke-Test -Name 'parse shared options' -Body {
    $result = Parse-CommonArgs -Args @('--dry-run', '--verbose', 'debug', '--summary', '--ci', 'positional') -CaptureExtraValues
    Assert-Equal $true $result.Options['DryRun'] 'dry-run flag'
    Assert-Equal 'debug' $result.Options['Verbose'] 'verbose level'
    Assert-Equal $true $result.Options['Summary'] 'summary flag'
    Assert-Equal $true $result.Options['Ci'] 'ci flag'
    Assert-Equal 'positional' $result.RemainingArgs[0] 'positional arg'
}

Invoke-Test -Name 'parse extra descriptors' -Body {
    $descriptors = @{ '--config' = 'value:ConfigPath'; '-c' = 'alias:--config'; '--flag' = 'bool:FlagToggle'; '--list' = @{ Type = 'multi'; Name = 'ListItems'; AllowMultiple = $true } }
    $result = Parse-CommonArgs -Args @('--config', 'foo', '--flag', '-c', 'bar', '--list', 'item1', '--list=item2', 'pos1', 'pos2') -ExtraDescriptors $descriptors -CaptureExtraValues
    Assert-Equal 'bar' $result.ExtraValues['ConfigPath'] 'config value'
    Assert-Equal $true $result.ExtraValues['FlagToggle'] 'flag captured'
    $list = @($result.ExtraValues['ListItems'])
    Assert-Contains 'item1' ($list -join ',') 'list contains item1'
    Assert-Contains 'item2' ($list -join ',') 'list contains item2'
    Assert-Equal 'pos1' $result.RemainingArgs[0] 'first positional'
    Assert-Equal 'pos2' $result.RemainingArgs[1] 'second positional'
}

Invoke-Test -Name 'validate mdk config success' -Body {
    $config = Join-Path $repoRoot 'se-config.ini'
    $exitCode = Validate-MdkConfig $config
    Assert-Equal 0 $exitCode 'expected validation success'
}

Invoke-Test -Name 'validate mdk config failure' -Body {
    $temp = New-TemporaryFile
    try {
        Set-Content -LiteralPath $temp.FullName -Value '[mdk]'
        $exitCode = $null
        try {
            $exitCode = Validate-MdkConfig $temp.FullName
        }
        catch {
            $exitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
        }
        if (-not $exitCode) { $exitCode = 1 }
        if ($exitCode -eq 0) { throw 'expected non-zero exit' }
    }
    finally {
        Remove-Item -LiteralPath $temp.FullName -ErrorAction SilentlyContinue
    }
}

Invoke-Test -Name 'parse error reporting' -Body {
    $descriptors = @{ '--needs' = 'value:NeedsValue' }
    $result = Parse-CommonArgs -Args @('--needs') -ExtraDescriptors $descriptors -CaptureExtraValues
    if ($result.Success) { throw 'expected parse failure' }
    if (-not $result.Errors) { throw 'expected errors populated' }
}

Invoke-Test -Name 'log prefixes' -Body {
    Initialize-Logging -Options @{ Verbose = 'info'; Ci = $false; Summary = $false; DryRun = $false }
    $output = (& { Write-Log -Level 'info' -Message 'hello world' } 2>&1 | Out-String)
    Assert-Contains '[info] hello world' $output 'info prefix'
}

Invoke-Test -Name 'error routing' -Body {
    Initialize-Logging -Options @{ Verbose = 'info'; Ci = $false; Summary = $false; DryRun = $false }
    $stringWriter = New-Object System.IO.StringWriter
    $original = [Console]::get_Error()
    try {
        [Console]::SetError($stringWriter)
        Write-Log -Level 'error' -Message 'boom'
    }
    finally {
        [Console]::SetError($original)
    }
    $output = $stringWriter.ToString()
    Assert-Contains '[error] boom' $output 'error prefix'
}

Invoke-Test -Name 'summary emission' -Body {
    Initialize-Logging -Options @{ Verbose = 'info'; Ci = $false; Summary = $true; DryRun = $false }
    Register-Action -Description 'first action'
    $output = (& { Emit-Summary -ExitCode 0 } 2>&1 | Out-String)
    Assert-Contains 'Summary (exit code: 0)' $output 'summary header'
    Assert-Contains 'action: first action' $output 'action recorded'
}

Invoke-Test -Name 'ci annotation helper' -Body {
    Initialize-Logging -Options @{ Verbose = 'info'; Ci = $true; Summary = $false; DryRun = $false }
    $output = (Encode-CiAnnotation -Type 'error' -Message "line break" -Metadata 'line=10','col=2')
    Assert-Equal '::error line=10,col=2::line break' $output 'annotation format'
}

Invoke-Test -Name 'warn annotation via log' -Body {
    Initialize-Logging -Options @{ Verbose = 'debug'; Ci = $true; Summary = $false; DryRun = $false }
    $stringWriter = New-Object System.IO.StringWriter
    $original = [Console]::get_Error()
    try {
        [Console]::SetError($stringWriter)
        $output = Write-Log -Level 'warn' -Message 'careful'
    }
    finally {
        [Console]::SetError($original)
    }
    $captured = $stringWriter.ToString()
    $annotation = ($output | Out-String).Trim()
    Assert-Contains '::warning' $annotation 'warning annotation emitted'
    Assert-Contains 'careful' $captured 'warning message included'
}

Invoke-Test -Name 'integration sample tool' -Body {
    $fixture = Join-Path $scriptDir 'fixtures/Sample-Tool.ps1'
    $result = & $fixture --dry-run --verbose debug --summary --name demo positional
    $output = $result | Out-String
    Assert-Contains '[info] starting sample' $output 'start message'
    Assert-Contains 'Summary (exit code: 0)' $output 'summary present'
    Assert-Contains 'action: parsed positional' $output 'action recorded'
    Assert-Contains 'name=demo' $output 'name logged'
}

if ($Failures -gt 0) {
    Write-Error ("PowerShell tooling tests: {0}/{1} failed" -f $Failures, $Runs)
    exit 1
}

Write-Host ("PowerShell tooling tests: {0} passed" -f $Runs)
