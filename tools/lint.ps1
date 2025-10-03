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
Lint Helpers (tools/lint.ps1)

Usage:
  pwsh tools/lint.ps1 [options] [--files <path...>]

Options:
  --help, -h                 Show this help text.
  --version, -V              Show tool version information.
  --files <path...>          One or more file paths or globs to lint.
  --dry-run                  Report planned actions without running linters (exit 3 when work pending).
  --summary                  Emit execution summary (text by default).
  --summary-format <mode>    Summary output format: text|json (requires --summary).
  --summary-json <path>      Write JSON summary (schema v1) to the given path.
  --shellcheck-flags "..."  Extra ShellCheck flags appended to repo defaults.
  --pssa-settings <path>     Override ScriptAnalyzer settings file.
  --dotnet-build             Run dotnet build -warnaserror when C# files targeted.
  --dotnet-args "..."        Extra arguments appended to dotnet build (used with --dotnet-build).
  --fail-on-warn             Treat warnings as failures (exit code 1).
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

function Resolve-LintTargets {
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

function Get-ShellCheckFlags {
    param(
        [string]$Override
    )

    $flags = @()
    $rcPath = Join-Path $PSScriptRoot 'shell/shellcheckrc'
    if (Test-Path -LiteralPath $rcPath) {
        foreach ($line in Get-Content -LiteralPath $rcPath) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $trimmed = $line.Split('#')[0].Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            $flags += $trimmed.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        $flags += (Split-Arguments -Value $Override)
    }

    return $flags
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
$shellcheckOverride = ''
$pssaSettings = Join-Path $PSScriptRoot 'pssa/PSScriptAnalyzerSettings.psd1'
$dotnetArgsRaw = ''
$markdownlintArgsRaw = ''
$dotnetBuild = $false
$failOnWarn = $false

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
        '^--shellcheck-flags$' {
            $i += 1
            if ($i -ge $unknown.Count) {
                Write-Log -Level 'info' -Message 'ERROR: Missing value after --shellcheck-flags.'
                exit 1
            }
            $shellcheckOverride = $unknown[$i]
        }
        '^--shellcheck-flags=' {
            $shellcheckOverride = $token.Substring(20)
        }
        '^--markdownlint-args$' {
            $i += 1
            if ($i -ge $unknown.Count) {
                Write-Log -Level 'info' -Message 'ERROR: Missing value after --markdownlint-args.'
                exit 1
            }
            $markdownlintArgsRaw = $unknown[$i]
        }
        '^--markdownlint-args=' {
            $markdownlintArgsRaw = $token.Substring(20)
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
        '^--dotnet-build$' {
            $dotnetBuild = $true
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
        '^--fail-on-warn$' {
            $failOnWarn = $true
        }
        default {
            if (-not [string]::IsNullOrWhiteSpace($token)) {
                $files.Add($token)
            }
        }
    }
    $i += 1
}

$explicitTargetsProvided = $files.Count -gt 0

$targets = Resolve-LintTargets -Candidates $files.ToArray()

if ($targets.Count -eq 0) {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $gitFiles = (& $git.Source diff --name-only --cached) | Where-Object { $_ }
        if ($LASTEXITCODE -eq 0 -and $gitFiles) {
            $targets = Resolve-LintTargets -Candidates $gitFiles
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

$exitCode = if ($missingFiles.Count -gt 0) { 1 } else { 0 }
$hasWork = ($csFiles.Count + $psFiles.Count + $shFiles.Count + $mdFiles.Count) -gt 0

foreach ($item in $unsupported) {
    Write-Log -Level 'info' -Message "WARNING: Unsupported file type: $item"
}

if ($flags.dry_run) {
    if ($psFiles.Count -gt 0) { Write-Log -Level 'info' -Message "dry-run: would run ScriptAnalyzer on $($psFiles.Count) file(s)." }
    if ($shFiles.Count -gt 0) { Write-Log -Level 'info' -Message "dry-run: would run ShellCheck on $($shFiles.Count) file(s)." }
    if ($mdFiles.Count -gt 0) { Write-Log -Level 'info' -Message "dry-run: would run markdownlint on $($mdFiles.Count) file(s)." }
    if ($dotnetBuild -and $csFiles.Count -gt 0) { Write-Log -Level 'info' -Message 'dry-run: would run dotnet build on C# targets.' }
    if ($flags.summary -or $flags.summary_json) {
        Add-SummaryItem -Kind 'info' -Message 'dry-run completed' -Data ("targets=$($csFiles.Count + $psFiles.Count + $shFiles.Count + $mdFiles.Count)")
    }
    if ($hasWork -and $exitCode -eq 0) {
        $exitCode = 3
    }
}
elseif ($mode -eq 'se' -and $flags.ci -and $hasWork) {
    Write-Log -Level 'info' -Message 'MODE=se and --ci supplied -> skipping lint execution.'
    if ($flags.summary -or $flags.summary_json) {
        Add-SummaryItem -Kind 'info' -Message 'Linting skipped in SE mode (CI).' -Data ("targets=$($csFiles.Count + $psFiles.Count + $shFiles.Count + $mdFiles.Count)")
    }
}
elseif ($hasWork) {
    $shellcheckFlags = Get-ShellCheckFlags -Override $shellcheckOverride
    $dotnetArgs = Split-Arguments -Value $dotnetArgsRaw

    if ($psFiles.Count -gt 0) {
        try {
            Import-Module PSScriptAnalyzer -ErrorAction Stop | Out-Null
            $results = Invoke-ScriptAnalyzer -Path $psFiles -Settings $pssaSettings -EnableExit:$false
            if ($results.Count -gt 0) {
                $errorCount = ($results | Where-Object { $_.Severity -eq 'Error' -or $_.Severity -eq 'ParseError' }).Count
                $warningCount = ($results | Where-Object { $_.Severity -eq 'Warning' }).Count
                $shouldFail = ($errorCount -gt 0) -or ($failOnWarn -and $warningCount -gt 0)
                $message = "PSSA: $($results.Count) finding(s)"
                if ($shouldFail) {
                    Write-Log -Level 'info' -Message "ERROR: $message"
                    $exitCode = 1
                    Add-SummaryItem -Kind 'error' -Message $message
                } else {
                    Write-Log -Level 'info' -Message $message
                    Add-SummaryItem -Kind 'warning' -Message $message
                }
            }
            else {
                Write-Log -Level 'info' -Message 'PSSA: no findings.'
                Add-SummaryItem -Kind 'info' -Message 'PSSA clean.'
            }
        }
        catch {
            Write-Log -Level 'info' -Message "ERROR: PowerShell linting failed: $_"
            $exitCode = 4
        }
    }

    if ($shFiles.Count -gt 0) {
        $shellcheck = Get-Command shellcheck -ErrorAction SilentlyContinue
        if (-not $shellcheck) {
            Write-Log -Level 'info' -Message 'ERROR: shellcheck command not found.'
            $exitCode = if ($exitCode -eq 0) { 4 } else { $exitCode }
        } else {
            $cmd = @()
            if ($shellcheckFlags.Count -gt 0) { $cmd += $shellcheckFlags }
            $cmd += $shFiles
            Write-Log -Level 'info' -Message ("Running shellcheck {0}" -f ($cmd -join ' '))
            & $shellcheck.Source @cmd
            $shellExit = $LASTEXITCODE
            switch ($shellExit) {
                0 {
                    Add-SummaryItem -Kind 'info' -Message 'ShellCheck clean.'
                }
                1 {
                    if ($failOnWarn) {
                        Add-SummaryItem -Kind 'error' -Message 'ShellCheck reported warnings.'
                        $exitCode = 1
                    } else {
                        Add-SummaryItem -Kind 'warning' -Message 'ShellCheck reported warnings.'
                    }
                }
                default {
                    Add-SummaryItem -Kind 'error' -Message "ShellCheck exited with code $shellExit."
                    $exitCode = 1
                }
            }
        }
    }

    if ($mdFiles.Count -gt 0) {
        $npx = Get-Command npx -ErrorAction SilentlyContinue
        if (-not $npx) {
            Write-Log -Level 'info' -Message 'ERROR: npx command not found.'
            $exitCode = if ($exitCode -eq 0) { 4 } else { $exitCode }
        } else {
            $markdownlintArgs = Split-Arguments -Value $markdownlintArgsRaw
            $cmd = @('markdownlint')
            $configPath = '.markdownlint.jsonc'
            if (Test-Path -LiteralPath $configPath) {
                $cmd += @('--config', $configPath)
            }
            if ($markdownlintArgs.Count -gt 0) { $cmd += $markdownlintArgs }
            $cmd += $mdFiles
            Write-Log -Level 'info' -Message ("Running npx {0}" -f ($cmd -join ' '))
            & $npx.Source @cmd
            $lintExit = $LASTEXITCODE
            switch ($lintExit) {
                0 {
                    Add-SummaryItem -Kind 'info' -Message 'markdownlint clean.'
                }
                1 {
                    Add-SummaryItem -Kind 'error' -Message 'markdownlint reported issues.'
                    $exitCode = 1
                }
                default {
                    Add-SummaryItem -Kind 'error' -Message "markdownlint exited with code $lintExit."
                    $exitCode = 1
                }
            }

            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
            $mermaidCliCandidates = @(
                (Join-Path $repoRoot 'node_modules/.bin/mmdc'),
                (Join-Path $repoRoot 'node_modules/.bin/mmdc.cmd')
            )
            $mermaidCliPath = $mermaidCliCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if (-not $mermaidCliPath) {
                Write-Log -Level 'info' -Message 'Mermaid CLI not installed; skipping diagram validation.'
            } else {
                $diagramCount = 0
                $diagramFailures = 0
                $mermaidLaunchFailed = $false
                foreach ($mdFile in $mdFiles) {
                    $content = Get-Content -LiteralPath $mdFile -Raw
                    $matches = [regex]::Matches($content, '(?ms)```mermaid\s*(.*?)```')
                    if ($matches.Count -eq 0) { continue }
                    foreach ($match in $matches) {
                        $diagram = $match.Groups[1].Value.Trim()
                        if ([string]::IsNullOrWhiteSpace($diagram)) { continue }
                        $diagramCount += 1
                        $tempInput = [System.IO.Path]::GetTempFileName()
                        $tempOutput = "$tempInput.svg"
                        try {
                            [System.IO.File]::WriteAllText($tempInput, $diagram, [System.Text.Encoding]::UTF8)
                            $mermaidOutput = & $mermaidCliPath '--input' $tempInput '--output' $tempOutput '--quiet' 2>&1
                            if ($LASTEXITCODE -ne 0) {
                                $outputText = ($mermaidOutput | Out-String).Trim()
                                if ($outputText -match 'Failed to launch the browser process') {
                                    $mermaidLaunchFailed = $true
                                    Write-Log -Level 'info' -Message 'WARNING: Mermaid validation skipped (browser launch blocked).'
                                    if ($outputText) {
                                        Write-Log -Level 'debug' -Message $outputText
                                    }
                                    break
                                }

                                $diagramFailures += 1
                                Write-Log -Level 'info' -Message "ERROR: Mermaid diagram validation failed in $mdFile"
                                if ($outputText) {
                                    $snippet = if ($outputText.Length -gt 400) { $outputText.Substring(0, 400) + '…' } else { $outputText }
                                    Write-Log -Level 'info' -Message "Mermaid CLI output: $snippet"
                                    Write-Log -Level 'debug' -Message $outputText
                                }
                            }
                        } finally {
                            Remove-Item -LiteralPath $tempInput -ErrorAction SilentlyContinue
                            Remove-Item -LiteralPath $tempOutput -ErrorAction SilentlyContinue
                        }
                    }
                    if ($mermaidLaunchFailed) { break }
                }

                if ($diagramCount -gt 0) {
                    if ($mermaidLaunchFailed) {
                        Add-SummaryItem -Kind 'warning' -Message 'Mermaid validation skipped (browser launch blocked).'
                    }
                    elseif ($diagramFailures -gt 0) {
                        Add-SummaryItem -Kind 'error' -Message "$diagramFailures Mermaid diagram(s) failed validation." -Data "validated=$diagramCount"
                        $exitCode = 1
                    } else {
                        Add-SummaryItem -Kind 'info' -Message "Validated $diagramCount Mermaid diagram(s)."
                    }
                }
            }
        }
    }

    if ($dotnetBuild -and $csFiles.Count -gt 0) {
        $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
        if (-not $dotnet) {
            Write-Log -Level 'info' -Message 'ERROR: dotnet command not found.'
            $exitCode = if ($exitCode -eq 0) { 4 } else { $exitCode }
        } else {
            $cmd = @('build', '-warnaserror')
            if ($dotnetArgs.Count -gt 0) { $cmd += $dotnetArgs }
            Write-Log -Level 'info' -Message ("Running dotnet {0}" -f ($cmd -join ' '))
            & $dotnet.Source @cmd
            if ($LASTEXITCODE -ne 0) {
                Add-SummaryItem -Kind 'error' -Message 'dotnet build reported failures.'
                $exitCode = 1
            } else {
                Add-SummaryItem -Kind 'info' -Message 'dotnet build clean.'
            }
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
