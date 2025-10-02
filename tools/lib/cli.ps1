# Shared CLI runtime library (PowerShell implementation)
# Provides argument parsing, logging helpers, summary aggregation, and CI-friendly utilities.

# Internal state container
$script:CliState = @{
    Flags       = @{}
    UnknownArgs = @()
    Summary     = @()
}

function Initialize-Cli {
    [CmdletBinding()]
    param(
        [string[]]$Args
    )

    $flags = [ordered]@{
        help           = $false
        version        = $false
        dry_run        = $false
        summary        = $false
        summary_format = 'text'
        summary_json   = $null
        log_level      = 'info'
        ci             = $false
    }

    $unknown = New-Object System.Collections.Generic.List[string]

    $argList = @()
    if ($Args) { $argList = @($Args) }

    $i = 0
    while ($i -lt $argList.Count) {
        $arg = $argList[$i]
        switch ($arg) {
            '--help' { $flags.help = $true }
            '--version' { $flags.version = $true }
            '--dry-run' { $flags.dry_run = $true }
            '--summary' { $flags.summary = $true }
            '--summary-format' {
                if ($i + 1 -lt $argList.Count) {
                    $selected = $argList[$i + 1]
                    if ($selected -in @('text', 'json')) {
                        $flags.summary_format = $selected
                        $i += 1
                    } else {
                        $unknown.Add($arg)
                        $unknown.Add($selected)
                        $i += 1
                    }
                } else {
                    $unknown.Add($arg)
                }
            }
            '--summary-json' {
                if ($i + 1 -lt $argList.Count) {
                    $flags.summary_json = $argList[$i + 1]
                    $i += 1
                } else {
                    $unknown.Add($arg)
                }
            }
            '--verbose' {
                if ($i + 1 -lt $argList.Count) {
                    $level = $argList[$i + 1]
                    if ($level -in @('quiet', 'info', 'debug')) {
                        $flags.log_level = $level
                        $i += 1
                    } else {
                        $unknown.Add($arg)
                        $unknown.Add($level)
                        $i += 1
                    }
                } else {
                    $unknown.Add($arg)
                }
            }
            '--debug' {
                $flags.log_level = 'debug'
            }
            '--ci' {
                $flags.ci = $true
            }
            default {
                $unknown.Add($arg)
            }
        }
        $i += 1
    }

    # Reset global state
    $script:CliState = @{
        Flags       = $flags
        UnknownArgs = $unknown.ToArray()
        Summary     = @()
    }

    return [pscustomobject]@{
        Flags       = $script:CliState.Flags
        UnknownArgs = $script:CliState.UnknownArgs
        Logger      = { param($Level, $Message) Write-Log -Level $Level -Message $Message }
        Summary     = [pscustomobject]@{
            Add   = { param($Kind, $Message, $Data) Add-SummaryItem -Kind $Kind -Message $Message -Data $Data }
            Items = { ,$script:CliState.Summary }
        }
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateSet('quiet','info','debug')] [string]$Level,
        [Parameter(Mandatory)] [string]$Message
    )

    $logLevels = @{ quiet = 0; info = 1; debug = 2 }
    $current = $script:CliState.Flags.log_level
    if (-not $logLevels.ContainsKey($current)) { $current = 'info' }

    if ($logLevels[$Level] -le $logLevels[$current]) {
        $prefix = "[$Level]"
        Write-Output "$prefix $Message"
    }
}

function Add-SummaryItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Kind,
        [Parameter(Mandatory)] [string]$Message,
        [Parameter()] $Data
    )

    $item = [ordered]@{
        kind    = $Kind
        message = $Message
    }
    if ($PSBoundParameters.ContainsKey('Data')) {
        $item.data = $Data
    }
    $script:CliState.Summary += [pscustomobject]$item
}

function Emit-Summary {
    [CmdletBinding()]
    param(
        [ValidateSet('text','json')] [string]$Format,
        [string]$OutputPath,
        [int]$ExitCode,
        [object[]]$Errors
    )

    $flags = $script:CliState.Flags

    if (-not $PSBoundParameters.ContainsKey('OutputPath') -and $flags.summary_json) {
        $OutputPath = $flags.summary_json
    }

    $formatToUse = if ($PSBoundParameters.ContainsKey('Format')) { $Format } else { $flags.summary_format }
    $summaryItems = $script:CliState.Summary
    if (-not $summaryItems) { $summaryItems = @() }

    $payload = [ordered]@{
        schema  = 'v1'
        summary = $summaryItems
        ci      = [ordered]@{
            enabled  = [bool]$flags.ci
            provider = if ($env:GITHUB_ACTIONS -eq 'true') { 'github_actions' } elseif ($env:CI) { 'generic' } else { $null }
        }
    }

    if ($PSBoundParameters.ContainsKey('ExitCode')) {
        $payload.exit_code = $ExitCode
    }
    if ($PSBoundParameters.ContainsKey('Errors')) {
        $payload.errors = $Errors
    }

    if ($formatToUse -eq 'json' -or $OutputPath) {
        $json = $payload | ConvertTo-Json -Depth 6 -Compress
        if ($OutputPath) {
            Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
        }
        return $json
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine('Summary:')
    foreach ($entry in $summaryItems) {
        [void]$builder.AppendLine("- [$($entry.kind)] $($entry.message)")
    }
    if ($PSBoundParameters.ContainsKey('ExitCode')) {
        [void]$builder.AppendLine("Exit code: $ExitCode")
    }
    if ($PSBoundParameters.ContainsKey('Errors')) {
        $count = $Errors.Count
        [void]$builder.AppendLine("Errors: $count")
    }
    return $builder.ToString().TrimEnd()
}

function Emit-Help {
    [CmdletBinding()]
    param()
    return "Usage: <tool> [options] --help --version --dry-run --summary"
}

function Emit-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Version,
        [string]$Commit,
        [Parameter(Mandatory)] [string]$ApiVersion
    )

    $commitValue = if ($Commit) { $Commit } else { 'n/a' }
    return "version=$Version commit=$commitValue api_version=$ApiVersion"
}

function Annotate-CI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateSet('notice','warning','error')] [string]$Level,
        [Parameter(Mandatory)] [string]$Message,
        [string]$File,
        [int]$Line,
        [int]$Col
    )

    if ($script:CliState.Flags.ci -and $env:GITHUB_ACTIONS -eq 'true') {
        $annotation = "::$Level"
        if ($File) { $annotation += " file=$File" }
        if ($Line) { $annotation += ",line=$Line" }
        if ($Col) { $annotation += ",col=$Col" }
        $annotation += "::$Message"
        Write-Output $annotation
    } else {
        Write-Log -Level 'info' -Message $Message
    }
}

function Make-Error {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int]$Code,
        [Parameter(Mandatory)] [string]$Message,
        [string]$Area
    )

    $errorObject = [ordered]@{
        Code    = $Code
        Message = $Message
    }
    if ($PSBoundParameters.ContainsKey('Area')) {
        $errorObject.Area = $Area
    }
    return [pscustomobject]$errorObject
}
