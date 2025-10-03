#!/usr/bin/env pwsh
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/cli.ps1')

function Show-Help {
    @'
Format Helpers (tools/format.ps1)

Usage:
  pwsh tools/format.ps1 [options] [--files <path...>]

Options:
  --help, -h                 Show this help text.
  --version, -V              Show tool version information.
  --files <path...>          One or more file paths or globs to format.
  --dry-run                  Report planned actions without modifying files (exit 3 when work pending).
  --summary                  Emit an execution summary (text by default).
  --summary-format <mode>    Summary output format: text|json (requires --summary).
  --summary-json <path>      Write JSON summary (schema v1) to the given path.
  --shfmt-flags "..."        Override shfmt flags (defaults: -ln bash -i 2 -ci -bn -sr).
  --dotnet-args "..."        Extra arguments appended to dotnet format.
  --pssa-settings <path>     Override PSScriptAnalyzer settings file.
  --ci                       Indicate CI execution for policy-aware behaviour.
  --                         Treat all following arguments as file paths.
'@ | Write-Output
}

function Split-Arguments {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ,@()
    }

    $errors = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize($Value, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        throw "Unable to parse arguments: $Value"
    }

    $result = @()
    foreach ($token in $tokens) {
        if ($token.Type -eq 'StringLiteral' -or $token.Type -eq 'Generic') {
            $result += $token.Content
        }
    }
    return ,$result
}

function Resolve-FormatTargets {
    param(
        [string[]]$Candidates
    )

    if ($null -eq $Candidates) {
        $Candidates = @()
    }

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ordered = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if ($set.Add($candidate)) { $ordered.Add($candidate) }
    }
    return ,($ordered.ToArray())
}

$context = Initialize-Cli -Args $Args
$flags = $context.Flags
$unknown = $context.UnknownArgs

if ($null -eq $unknown) {
    $unknown = @()
} elseif ($unknown -isnot [System.Array]) {
    $unknown = @($unknown)
}

$files = New-Object System.Collections.Generic.List[string]
$shfmtFlagsRaw = '-ln bash -i 2 -ci -bn -sr'
$dotnetArgsRaw = ''
$prettierArgsRaw = ''
$pssaSettings = Join-Path $PSScriptRoot 'pssa/PSScriptAnalyzerSettings.psd1'

$i = 0
while ($i -lt $unknown.Count) {
    $token = $unknown[$i]
    switch -Regex ($token) {
        '^--$' {
            for ($j = $i + 1; $j -lt $unknown.Count; $j++) {
                $files.Add($unknown[$j])
            }
            break
        }
        '^--files$' {
            $i += 1
            if ($i -ge $unknown.Count) {
                Write-Log -Level 'info' -Message 'ERROR: Missing value after --files.'
                exit 1
            }
            while ($i -lt $unknown.Count -and -not $unknown[$i].StartsWith('--')) {
                $files.Add($unknown[$i])
                $i += 1
            }
            $i -= 1
        }
        '^--files=' {
            $value = $token.Substring(8)
            if ($value) {
                $value.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $files.Add($_.Trim()) }
            }
        }
        '^--shfmt-flags$' {
            $i += 1
            if ($i -ge $unknown.Count) {
                Write-Log -Level 'info' -Message 'ERROR: Missing value after --shfmt-flags.'
                exit 1
            }
            $shfmtFlagsRaw = $unknown[$i]
        }
        '^--shfmt-flags=' {
            $shfmtFlagsRaw = $token.Substring(15)
        }
        '^--dotnet-args$' {
            $i += 1
            if ($i -ge $unknown.Count) {
                Write-Log -Level 'info' -Message 'ERROR: Missing value after --dotnet-args.'
                exit 1
            }
            $dotnetArgsRaw = $unknown[$i]
        }
        '^--dotnet-args=' {
            $dotnetArgsRaw = $token.Substring(14)
        }
        '^--prettier-args$' {
            $i += 1
            if ($i -ge $unknown.Count) {
                Write-Log -Level 'info' -Message 'ERROR: Missing value after --prettier-args.'
                exit 1
            }
            $prettierArgsRaw = $unknown[$i]
        }
        '^--prettier-args=' {
            $prettierArgsRaw = $token.Substring(16)
        }
        '^--pssa-settings$' {
            $i += 1
            if ($i -ge $unknown.Count) {
                Write-Log -Level 'info' -Message 'ERROR: Missing value after --pssa-settings.'
                exit 1
            }
            $pssaSettings = $unknown[$i]
        }
        '^--pssa-settings=' {
            $pssaSettings = $token.Substring(16)
        }
        default {
            if (-not [string]::IsNullOrWhiteSpace($token)) {
                $files.Add($token)
            }
        }
    }
    $i += 1
}

$targets = Resolve-FormatTargets -Candidates $files.ToArray()

if ($targets.Count -eq 0) {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $gitFiles = (& $git.Source diff --name-only --cached) | Where-Object { $_ }
        if ($LASTEXITCODE -eq 0 -and $gitFiles) {
            $targets = Resolve-FormatTargets -Candidates $gitFiles
            Write-Log -Level 'debug' -Message 'Using staged files as targets.'
        }
    }
}

if ($flags.help) {
    Show-Help
    exit 0
}

if ($flags.version) {
    Emit-Version -Version '1.0.0' -ApiVersion '1' -Commit '' | Write-Output
    exit 0
}

$mode = ($env:MODE ?? 'tooling').ToLowerInvariant()

$resolvedFiles = @()
$missingFiles = @()
foreach ($path in $targets) {
    if (Test-Path -LiteralPath $path) {
        $resolvedFiles += (Resolve-Path -LiteralPath $path).Path
    } else {
        Write-Log -Level 'info' -Message "ERROR: File not found: $path"
        $missingFiles += $path
    }
}

$csFiles = @()
$psFiles = @()
$shFiles = @()
$mdFiles = @()
$unsupported = @()
foreach ($path in $resolvedFiles) {
    switch -Regex ($path) {
        '\.cs$' { $csFiles += $path }
        '\.(ps1|psm1|psd1)$' { $psFiles += $path }
        '\.sh$' { $shFiles += $path }
        '\.md$' { $mdFiles += $path }
        default { $unsupported += $path }
    }
}

$exitCode = if ($missingFiles.Count -gt 0 -or $unsupported.Count -gt 0) { 1 } else { 0 }

foreach ($item in $unsupported) {
    Write-Log -Level 'info' -Message "WARNING: Unsupported file type: $item"
}

$hasWork = ($csFiles.Count + $psFiles.Count + $shFiles.Count + $mdFiles.Count) -gt 0

if ($flags.dry_run) {
    if ($csFiles.Count -gt 0) { Write-Log -Level 'info' -Message "dry-run: would format $($csFiles.Count) C# file(s)." }
    if ($psFiles.Count -gt 0) { Write-Log -Level 'info' -Message "dry-run: would format $($psFiles.Count) PowerShell file(s)." }
    if ($shFiles.Count -gt 0) { Write-Log -Level 'info' -Message "dry-run: would format $($shFiles.Count) shell script(s)." }
    if ($mdFiles.Count -gt 0) { Write-Log -Level 'info' -Message "dry-run: would format $($mdFiles.Count) Markdown file(s)." }
    if ($flags.summary -or $flags.summary_json) {
        Add-SummaryItem -Kind 'info' -Message 'dry-run completed' -Data ("targets=$($csFiles.Count + $psFiles.Count + $shFiles.Count + $mdFiles.Count)")
    }
    if ($hasWork -and $exitCode -eq 0) {
        $exitCode = 3
    }
}
elseif ($mode -eq 'se' -and $flags.ci -and $hasWork) {
    Write-Log -Level 'info' -Message 'MODE=se and --ci supplied -> skipping formatter execution.'
    if ($flags.summary -or $flags.summary_json) {
        Add-SummaryItem -Kind 'info' -Message 'Formatting skipped in SE mode (CI).' -Data ("targets=$($csFiles.Count + $psFiles.Count + $shFiles.Count + $mdFiles.Count)")
    }
}
elseif ($hasWork) {
    $shfmtFlags = Split-Arguments -Value $shfmtFlagsRaw
    if ($shfmtFlags.Count -eq 0) {
        $shfmtFlags = @('-ln', 'bash', '-i', '2', '-ci', '-bn', '-sr')
    }
    $dotnetArgs = Split-Arguments -Value $dotnetArgsRaw

    if ($csFiles.Count -gt 0) {
        $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
        if (-not $dotnet) {
            Write-Log -Level 'info' -Message 'ERROR: dotnet command not found.'
            $exitCode = 1
        } else {
            $cmd = @('format', '--no-restore')
            if ($dotnetArgs.Count -gt 0) { $cmd += $dotnetArgs }
            foreach ($path in $csFiles) {
                $cmd += @('--include', $path)
            }
            Write-Log -Level 'info' -Message ("Running dotnet {0}" -f ($cmd -join ' '))
            & $dotnet.Source @cmd
            if ($LASTEXITCODE -ne 0) {
                $exitCode = 1
            } else {
                Add-SummaryItem -Kind 'info' -Message "Formatted $($csFiles.Count) C# file(s)."
            }
        }
    }

    if ($shFiles.Count -gt 0) {
        $shfmt = Get-Command shfmt -ErrorAction SilentlyContinue
        if (-not $shfmt) {
            Write-Log -Level 'info' -Message 'ERROR: shfmt command not found.'
            $exitCode = 1
        } else {
            $cmd = @()
            $cmd += $shfmtFlags
            $cmd += '-w'
            $cmd += $shFiles
            Write-Log -Level 'info' -Message ("Running shfmt {0}" -f ($cmd -join ' '))
            & $shfmt.Source @cmd
            if ($LASTEXITCODE -ne 0) {
                $exitCode = 1
            } else {
                Add-SummaryItem -Kind 'info' -Message "Formatted $($shFiles.Count) shell script(s)."
            }
        }
    }

    if ($mdFiles.Count -gt 0) {
        $npx = Get-Command npx -ErrorAction SilentlyContinue
        if (-not $npx) {
            Write-Log -Level 'info' -Message 'ERROR: npx command not found.'
            $exitCode = 1
        } else {
            $prettierArgs = Split-Arguments -Value $prettierArgsRaw
            $cmd = @('prettier', '--write')
            if ($prettierArgs.Count -gt 0) { $cmd += $prettierArgs }
            $cmd += $mdFiles
            Write-Log -Level 'info' -Message ("Running npx {0}" -f ($cmd -join ' '))
            & $npx.Source @cmd
            if ($LASTEXITCODE -ne 0) {
                $exitCode = 1
            } else {
                Add-SummaryItem -Kind 'info' -Message "Formatted $($mdFiles.Count) Markdown file(s)."
            }
        }
    }

    if ($psFiles.Count -gt 0) {
        try {
            Import-Module PSScriptAnalyzer -ErrorAction Stop | Out-Null
            foreach ($path in $psFiles) {
                $content = Get-Content -LiteralPath $path -Raw
                $formatted = Invoke-Formatter -ScriptDefinition $content -Settings $pssaSettings
                if ($formatted -ne $content) {
                    Set-Content -LiteralPath $path -Value $formatted -NoNewline
                }
            }
            Add-SummaryItem -Kind 'info' -Message "Formatted $($psFiles.Count) PowerShell file(s)."
        }
        catch {
            Write-Log -Level 'info' -Message "ERROR: PowerShell formatting failed: $_"
            $exitCode = 1
        }
    }
}
else {
    Write-Log -Level 'info' -Message 'No supported files supplied.'
}

if ($flags.summary -or $flags.summary_json) {
    $emitParams = @{ ExitCode = $exitCode }
    if ($flags.summary_format -eq 'json') {
        $emitParams['Format'] = 'json'
    }
    $summaryOutput = Emit-Summary @emitParams
    if ($flags.summary) {
        Write-Output $summaryOutput
    }
}

exit $exitCode
