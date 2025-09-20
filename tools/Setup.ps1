#!/usr/bin/env pwsh
# dev-framework setup tooling (MIT License)
# Implements environment bootstrap per docs/spec/tooling/SetupTooling.md
# Relies on shared CLI contract from docs/spec/tooling/ToolingGeneral.md

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForwardArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$toolsRoot = $scriptDir
$repoRoot = Split-Path -Parent $scriptDir
$modulePath = Join-Path $toolsRoot 'lib/DevFramework.Tooling.psm1'

if (-not (Test-Path -LiteralPath $modulePath)) {
    Write-Error "Shared tooling module not found at $modulePath"
    exit 1
}

Import-Module $modulePath -Force

function Show-Usage {
    @'
Usage: Setup.ps1 [shared options] [setup options]

Shared options:
  -DryRun              Show actions without executing changes
  -Verbose <level>     Set verbosity (quiet|info|debug)
  -Summary             Print run summary at exit
  -Ci                  Enable CI-friendly output
  -Help                Show this help

Setup-specific options:
  -Config <path>       Config file to manage (default se-config.local.ini if present)
  -AutoInstall         Attempt package installs without prompting
  -NotesOnly           Emit diagnostics only (implies dry-run, disables installs)
  -BinaryPath <path>   Override Space Engineers Bin64 path
  -SteamPath <path>    Helper Steam root to locate Space Engineers
  -GamePath <path>     Helper Space Engineers game directory
  -Sln <path>          Override solution path (default dev-framework.sln)
  -SetupCodex          Force Codex bootstrap
  -SkipCodex           Skip Codex bootstrap
  -Name <value>        Project name context used for defaults
'@ | Write-Host
}

$descriptors = @{
    '--config'      = 'value:ConfigPath'
    '-c'            = 'alias:--config'
    '--auto-install' = 'bool:AutoInstall'
    '--notes-only'   = 'bool:NotesOnly'
    '--binary-path'  = 'value:BinaryPath'
    '--steam-path'   = 'value:SteamPath'
    '--game-path'    = 'value:GamePath'
    '--sln'          = 'value:SlnPath'
    '--setup-codex'  = 'bool:SetupCodex'
    '--skip-codex'   = 'bool:SkipCodex'
    '--name'         = 'value:ProjectName'
    '-n'             = 'alias:--name'
}

$rawArgs = $ForwardArguments
if (-not $rawArgs) { $rawArgs = @() }
$result = Parse-CommonArgs -Args $rawArgs -ExtraDescriptors $descriptors -CaptureExtraValues
if (-not $result.Success) {
    Write-Log -Level 'error' -Message 'Failed to parse arguments'
    if ($result.Errors) {
        foreach ($err in $result.Errors) {
            Write-Log -Level 'error' -Message $err
        }
    }
    exit 2
}

if ($result.Options.Help) {
    Show-Usage
    exit 0
}

if ($result.ExtraValues['NotesOnly']) {
    $result.Options['DryRun'] = $true
}

Initialize-Logging -Options $result.Options

$dryRun = [bool]$result.Options['DryRun']
$notesOnly  = [bool]($result.ExtraValues['NotesOnly'])
$autoInstall = [bool]($result.ExtraValues['AutoInstall'])
$setupCodex  = [bool]($result.ExtraValues['SetupCodex'])
$skipCodex   = [bool]($result.ExtraValues['SkipCodex'])

if ($setupCodex -and $skipCodex) {
    Write-Log -Level 'error' -Message 'Cannot set both -SetupCodex and -SkipCodex'
    Emit-Summary -ExitCode 2
    exit 2
}

function Resolve-PathSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $repoRoot $Path) -ErrorAction SilentlyContinue)?.Path ?? (Join-Path $repoRoot $Path)
}

function Read-IniValue {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    $current = $null
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trim = $line.Trim()
        if ($trim -match '^\[(.+)\]$') {
            $current = $matches[1]
            continue
        }
        if ($current -and ($current -ieq $Section) -and $trim -match '^([^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            if ($name -ieq $Key) {
                return $matches[2].Trim()
            }
        }
    }
    return $null
}

function Test-CommandVersion {
    param(
        [string]$Title,
        [string]$Command,
        [string[]]$Arguments
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        $version = $null
        try {
            $version = (& $Command @Arguments | Select-Object -First 1)
        } catch {
            $version = $null
        }
        $message = if ($version) { "{0} detected ({1})" -f $Title, $version } else { "{0} detected" -f $Title }
        Write-Log -Level 'info' -Message $message
        Register-Action -Description ("{0} available" -f $Title)
        return $true
    }

    Write-Log -Level 'warn' -Message ("{0} not found on PATH" -f $Title)
    Register-Action -Description ("{0} missing" -f $Title)
    return $false
}

function Set-IniValue {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )
    $lines = @()
    if (Test-Path -LiteralPath $Path) {
        $lines = [System.Collections.Generic.List[string]]::new((Get-Content -LiteralPath $Path))
    } else {
        $lines = [System.Collections.Generic.List[string]]::new()
    }

    $output = [System.Collections.Generic.List[string]]::new()
    $current = $null
    $sectionFound = $false
    $keyWritten = $false

    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim -match '^\[(.+)\]$') {
            if ($sectionFound -and -not $keyWritten) {
                $output.Add("$Key=$Value")
                $keyWritten = $true
            }
            $current = $matches[1]
            $sectionFound = ($current -ieq $Section)
            $output.Add($line)
            continue
        }
        if ($sectionFound -and $trim -match '^([^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            if ($name -ieq $Key) {
                $output.Add("$Key=$Value")
                $keyWritten = $true
                continue
            }
        }
        $output.Add($line)
    }

    if (-not $sectionFound) {
        if ($output.Count -gt 0 -and $output[$output.Count - 1].Trim()) {
            $output.Add('')
        }
        $output.Add("[$Section]")
        $output.Add("$Key=$Value")
    } elseif (-not $keyWritten) {
        $output.Add("$Key=$Value")
    }

    [System.IO.File]::WriteAllLines($Path, $output, [System.Text.UTF8Encoding]::new($false))
}

function Ensure-Directory {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { return }
    if ($dryRun) {
        Write-Log -Level 'info' -Message ("Would create directory {0}" -f $Path)
        Register-Action -Description "ensure dir (dry-run) $Path"
        return
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Register-Action -Description "created directory $Path"
}

function Write-DefaultConfig {
    param([string]$Path)
    Ensure-Directory -Path (Split-Path -Parent $Path)
    if ($dryRun) {
        Write-Log -Level 'info' -Message ("Would create config template at {0}" -f $Path)
        Register-Action -Description "ensure config (dry-run) $Path"
        return
    }
    @'
[Paths]
steam_path =
game_path =

[mdk]
type=programmableblock
trace=off
minify=none
ignores=obj/**/*,MDK/**/*,**/*.debug.cs
binarypath=auto
'@ | Set-Content -LiteralPath $Path -Encoding UTF8
    Register-Action -Description "created config $Path"
}

$configPath = if ($result.ExtraValues['ConfigPath']) {
    Resolve-PathSafe $result.ExtraValues['ConfigPath']
} elseif (Test-Path -LiteralPath (Join-Path $repoRoot 'se-config.local.ini')) {
    Join-Path $repoRoot 'se-config.local.ini'
} else {
    Join-Path $repoRoot 'se-config.ini'
}

Write-Log -Level 'info' -Message ("Using config file: {0}" -f $configPath)

if (-not (Test-Path -LiteralPath $configPath)) {
    Write-DefaultConfig -Path $configPath
}

$validationExit = Validate-MdkConfig -Arguments @('-Config', $configPath)
if ($validationExit -ne 0) {
    Write-Log -Level 'error' -Message ("Configuration validation failed for {0}" -f $configPath)
    Emit-Summary -ExitCode 1
    exit 1
}
Register-Action -Description 'validated config'

$binaryPath = $null
if ($result.ExtraValues['BinaryPath']) {
    $binaryPath = $result.ExtraValues['BinaryPath']
    Write-Log -Level 'info' -Message ("Binary path overridden via CLI: {0}" -f $binaryPath)
} else {
    $existing = Read-IniValue -Path $configPath -Section 'mdk' -Key 'binarypath'
    if ($existing -and $existing -ne 'auto') {
        $binaryPath = $existing
        Write-Log -Level 'debug' -Message ("Binary path from config: {0}" -f $binaryPath)
    }
}

if (-not $binaryPath) {
    $gamePath = $result.ExtraValues['GamePath']
    $steamPath = $result.ExtraValues['SteamPath']
    if ($gamePath) {
        if (Test-Path -LiteralPath (Join-Path $gamePath 'Bin64')) {
            $binaryPath = Join-Path $gamePath 'Bin64'
        } elseif (Test-Path -LiteralPath $gamePath) {
            $binaryPath = $gamePath
        }
    }
    if (-not $binaryPath -and $steamPath) {
        $candidate = Join-Path $steamPath 'steamapps/common/SpaceEngineers/Bin64'
        if (Test-Path -LiteralPath $candidate) {
            $binaryPath = $candidate
        }
    }
    if ($binaryPath) {
        Write-Log -Level 'info' -Message ("Derived binary path: {0}" -f $binaryPath)
    }
}

if ($binaryPath) {
    if (Test-Path -LiteralPath $binaryPath) {
        Write-Log -Level 'info' -Message ("Resolved Space Engineers binary path: {0}" -f $binaryPath)
        if ($dryRun) {
            Write-Log -Level 'info' -Message ("Dry-run: would record binary path in {0}" -f $configPath)
            Register-Action -Description 'binary path (dry-run)'
        } else {
            $globalConfig = Join-Path $repoRoot 'se-config.ini'
            if ((Resolve-Path $configPath) -eq (Resolve-Path $globalConfig)) {
                Write-Log -Level 'info' -Message 'Config is global template; skipping binary path write'
            } else {
                Set-IniValue -Path $configPath -Section 'mdk' -Key 'binarypath' -Value $binaryPath
                Register-Action -Description 'updated binary path'
            }
        }
    } else {
        Write-Log -Level 'warn' -Message ("Binary path does not exist: {0}" -f $binaryPath)
    }
} else {
    Write-Log -Level 'warn' -Message 'Unable to determine Space Engineers binary path'
}

if ($result.ExtraValues['SteamPath']) {
    if ($dryRun) {
        Write-Log -Level 'info' -Message ("Dry-run: would set steam_path to {0}" -f $result.ExtraValues['SteamPath'])
    } else {
        Set-IniValue -Path $configPath -Section 'Paths' -Key 'steam_path' -Value $result.ExtraValues['SteamPath']
    }
    Register-Action -Description 'recorded steam path'
}

if ($result.ExtraValues['GamePath']) {
    if ($dryRun) {
        Write-Log -Level 'info' -Message ("Dry-run: would set game_path to {0}" -f $result.ExtraValues['GamePath'])
    } else {
        Set-IniValue -Path $configPath -Section 'Paths' -Key 'game_path' -Value $result.ExtraValues['GamePath']
    }
    Register-Action -Description 'recorded game path'
}

$slnPath = if ($result.ExtraValues['SlnPath']) {
    Resolve-PathSafe $result.ExtraValues['SlnPath']
} else {
    Join-Path $repoRoot 'dev-framework.sln'
}

if ($slnPath -and (Test-Path -LiteralPath $slnPath)) {
    Write-Log -Level 'info' -Message ("Solution file present at {0}" -f $slnPath)
} else {
    if ($dryRun) {
        Write-Log -Level 'info' -Message ("Dry-run: would create solution at {0}" -f $slnPath)
    } else {
        Write-Log -Level 'warn' -Message ("Solution file missing at {0} (manual creation required)" -f $slnPath)
    }
    Register-Action -Description 'solution check'
}

Test-CommandVersion 'dotnet' 'dotnet' '--version' | Out-Null
Test-CommandVersion 'PowerShell 7' 'pwsh' '--version' | Out-Null
Test-CommandVersion 'Node.js' 'node' '--version' | Out-Null
Test-CommandVersion 'npm' 'npm' '--version' | Out-Null

if ($autoInstall) {
    Write-Log -Level 'warn' -Message 'Auto-install requested but not implemented; please install dependencies manually'
}

if ($skipCodex) {
    Write-Log -Level 'info' -Message 'Codex setup skipped per flag'
    Register-Action -Description 'codex skipped'
} elseif ($setupCodex) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        if ($dryRun -or $notesOnly) {
            Write-Log -Level 'info' -Message 'Dry-run: would run npm install for Codex CLI'
        } else {
            Write-Log -Level 'info' -Message "Codex bootstrap not automated yet; run 'npm install' manually"
        }
    } else {
        Write-Log -Level 'warn' -Message 'npm not available; cannot bootstrap Codex'
    }
    Register-Action -Description 'codex setup'
} else {
    Write-Log -Level 'info' -Message 'Codex setup skipped (default behavior)'
    Register-Action -Description 'codex default skip'
}

Emit-Summary -ExitCode 0
