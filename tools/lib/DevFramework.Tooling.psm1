# PowerShell shared tooling library for dev-framework (MIT License)
# Provides common CLI parsing, logging, summary, and CI helpers in line with
# docs/spec/tooling/SharedLibrary.md and ToolingGeneral.md.

Set-StrictMode -Version Latest

if (Get-Variable -Name ModuleInitialized -Scope Script -ErrorAction SilentlyContinue) {
    if ($script:ModuleInitialized) {
        return
    }
}
$script:ModuleInitialized = $true

$script:ToolingLibRoot = Split-Path -Parent $PSCommandPath
$script:ToolingRoot = Split-Path -Parent $script:ToolingLibRoot
$script:VerifyMdkScript = Join-Path $script:ToolingRoot 'Verify-Mdk2Config.ps1'

$script:LogLevel = 'info'
$script:LogLevelRank = 1
$script:CiMode = $false
$script:SummaryEnabled = $false
$script:DryRun = $false
$script:SummaryActions = New-Object System.Collections.Generic.List[string]

function Get-LevelRank {
    param(
        [Parameter(Mandatory)][string]$Level
    )

    switch ($Level.ToLowerInvariant()) {
        'quiet' { return 0 }
        'info'  { return 1 }
        'debug' { return 2 }
        'warn'  { return 1 }
        'warning' { return 1 }
        'error' { return 0 }
        default { return 1 }
    }
}

function Test-VerbosityLevel {
    param(
        [Parameter(Mandatory)][string]$Value
    )

    return @('quiet', 'info', 'debug') -contains $Value.ToLowerInvariant()
}

function Normalize-OptionName {
    param(
        [Parameter(Mandatory)][string]$Value
    )

    $trimmed = $Value.TrimStart('-')
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        $trimmed = 'option'
    }
    ($trimmed -replace '[^A-Za-z0-9_]', '_')
}

function Resolve-Descriptor {
    param(
        [Parameter(Mandatory)][string]$Option,
        [hashtable]$Descriptors
    )

    if (-not $Descriptors) {
        return $null
    }

    $current = $Option
    $guard = 0
    while ($guard -lt 10) {
        $guard++
        if (-not $current) { break }
        if (-not $Descriptors.ContainsKey($current)) { break }
        $descriptor = $Descriptors[$current]
        if ($descriptor -is [string]) {
            $parts = $descriptor.Split(':', 2)
            $dtype = $parts[0]
            $meta = if ($parts.Count -gt 1) { $parts[1] } else { $null }
            if ($dtype -eq 'alias') {
                $current = $meta
                continue
            }
            return [ordered]@{
                Type = $dtype
                Name = if ($meta) { $meta } else { (Normalize-OptionName -Value $current) }
                AllowMultiple = $false
            }
        }
        elseif ($descriptor -is [hashtable]) {
            $dtype = $descriptor['Type']
            if ($dtype -eq 'alias') {
                $current = $descriptor['Target']
                continue
            }
            $name = if ($descriptor.ContainsKey('Name')) {
                $descriptor['Name']
            } else {
                Normalize-OptionName -Value $current
            }
            $allowMulti = $false
            if ($descriptor.ContainsKey('AllowMultiple')) {
                $allowMulti = [bool]$descriptor['AllowMultiple']
            }
            return [ordered]@{
                Type = $dtype
                Name = $name
                AllowMultiple = $allowMulti
            }
        }
        else {
            break
        }
    }

    return $null
}

function Escape-CiAnnotationText {
    param(
        [Parameter(Mandatory)][string]$Text
    )

    $escaped = $Text -replace '%', '%25'
    $escaped = $escaped -replace "`r", '%0D'
    $escaped = $escaped -replace "`n", '%0A'
    return $escaped
}

function Parse-CommonArgs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string[]]$Args,
        [hashtable]$ExtraDescriptors,
        [switch]$CaptureExtraValues
    )

    $options = [ordered]@{
        DryRun = $false
        Verbose = 'info'
        Summary = $false
        Help = $false
        Ci = $false
    }

    $errors = New-Object System.Collections.Generic.List[string]
    $unknown = New-Object System.Collections.Generic.List[string]
    $remaining = New-Object System.Collections.Generic.List[string]
    $extraValues = if ($CaptureExtraValues -or $ExtraDescriptors) { @{} } else { @{} }

    $index = 0
    :parse while ($index -lt $Args.Count) {
        $argument = $Args[$index]
        $index++

        $optionKey = $argument
        $inlineValue = $null
        if ($optionKey -like '*=*') {
            $split = $optionKey.Split('=', 2)
            $optionKey = $split[0]
            $inlineValue = $split[1]
        }

        if ($optionKey -eq '--') {
            for (; $index -lt $Args.Count; $index++) {
                $remaining.Add($Args[$index]) | Out-Null
            }
            break
        }

        switch -Exact ($optionKey) {
            '--dry-run' {
                $options['DryRun'] = $true
                continue parse
            }
            '--summary' {
                $options['Summary'] = $true
                continue parse
            }
            '--help' {
                $options['Help'] = $true
                continue parse
            }
            '-h' {
                $options['Help'] = $true
                continue parse
            }
            '-?' {
                $options['Help'] = $true
                continue parse
            }
            '--ci' {
                $options['Ci'] = $true
                continue parse
            }
            '--verbose' {
                if (-not $inlineValue) {
                    if ($index -lt $Args.Count) {
                        $inlineValue = $Args[$index]
                        $index++
                    }
                    else {
                        $errors.Add('Missing value for --verbose') | Out-Null
                        continue parse
                    }
                }

                if (Test-VerbosityLevel -Value $inlineValue) {
                    $options['Verbose'] = $inlineValue
                }
                else {
                    $errors.Add("Invalid verbosity level: $inlineValue") | Out-Null
                }
                continue parse
            }
        }

        $descriptor = Resolve-Descriptor -Option $optionKey -Descriptors $ExtraDescriptors
        if ($descriptor) {
            if ($descriptor.Type -eq 'bool') {
                if ($inlineValue) {
                    $errors.Add("Option $optionKey does not accept a value") | Out-Null
                }
                $extraValues[$descriptor.Name] = $true
                continue parse
            }

            $needsList = $false
            if ($descriptor.Type -eq 'multi') {
                $needsList = $true
            }
            elseif (($descriptor.Type -ne 'value') -and ($descriptor.Type -ne 'string')) {
                $errors.Add("Unknown descriptor type '$($descriptor.Type)' for $optionKey") | Out-Null
                continue parse
            }

            if (-not $inlineValue) {
                if ($index -lt $Args.Count) {
                    $inlineValue = $Args[$index]
                    $index++
                }
                else {
                    $errors.Add("Missing value for $optionKey") | Out-Null
                    continue parse
                }
            }

            if ($needsList) {
                if ($extraValues.ContainsKey($descriptor.Name)) {
                    $existing = $extraValues[$descriptor.Name]
                    if ($existing -is [System.Collections.IList]) {
                        $existing.Add($inlineValue) | Out-Null
                    }
                    else {
                        $extraValues[$descriptor.Name] = @($existing, $inlineValue)
                    }
                }
                else {
                    $list = New-Object System.Collections.Generic.List[string]
                    $list.Add($inlineValue) | Out-Null
                    $extraValues[$descriptor.Name] = $list
                }
            }
            else {
                $extraValues[$descriptor.Name] = $inlineValue
            }
            continue
        }

        if ($optionKey.StartsWith('-')) {
            $unknown.Add($argument) | Out-Null
            $errors.Add("Unknown option: $optionKey") | Out-Null
            continue
        }

        $remaining.Add($argument) | Out-Null
    }

    foreach ($name in @($extraValues.Keys)) {
        $val = $extraValues[$name]
        if ($val -is [System.Collections.Generic.List[string]]) {
            $extraValues[$name] = $val.ToArray()
        }
    }

    $parseResult = @{
        Options = $options
        RemainingArgs = $remaining.ToArray()
        ExtraValues = $extraValues
        UnknownOptions = $unknown.ToArray()
        Errors = $errors.ToArray()
        Success = ($errors.Count -eq 0)
    }

    return $parseResult
}

function Initialize-Logging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Options
    )

    $script:LogLevel = $Options['Verbose']
    if (-not $script:LogLevel) { $script:LogLevel = 'info' }
    $script:LogLevelRank = Get-LevelRank -Level $script:LogLevel

    $script:CiMode = [bool]$Options['Ci']
    $script:SummaryEnabled = [bool]$Options['Summary']
    $script:DryRun = [bool]$Options['DryRun']
    $script:SummaryActions = New-Object System.Collections.Generic.List[string]
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )

    $rank = Get-LevelRank -Level $Level
    if ($rank -gt $script:LogLevelRank) {
        return
    }

    $prefix = "[{0}]" -f $Level
    if ($Level -eq 'error') {
        if ($script:CiMode) {
            Encode-CiAnnotation -Type 'error' -Message $Message
        }
        [Console]::Error.WriteLine("{0} {1}", $prefix, $Message)
    }
    elseif ($Level -in @('warn', 'warning')) {
        if ($script:CiMode) {
            Encode-CiAnnotation -Type 'warning' -Message $Message
        }
        [Console]::Error.WriteLine("{0} {1}", $prefix, $Message)
    }
    else {
        Write-Output ([string]::Format("{0} {1}", $prefix, $Message))
    }
}

function Register-Action {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Description)) {
        return
    }

    $script:SummaryActions.Add($Description) | Out-Null
}

function Emit-Summary {
    [CmdletBinding()]
    param(
        [Parameter()][int]$ExitCode = 0,
        [string[]]$Errors
    )

    if (-not $script:SummaryEnabled) {
        return
    }

    Write-Log -Level 'info' -Message ("Summary (exit code: {0})" -f $ExitCode)

    if ($script:SummaryActions.Count -gt 0) {
        foreach ($action in $script:SummaryActions) {
            Write-Log -Level 'info' -Message ("  action: {0}" -f $action)
        }
    }
    else {
        Write-Log -Level 'info' -Message '  action: none recorded'
    }

    if ($Errors) {
        foreach ($err in $Errors) {
            if ([string]::IsNullOrWhiteSpace($err)) { continue }
            Write-Log -Level 'error' -Message ("summary-error: {0}" -f $err)
        }
    }
}

function Encode-CiAnnotation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Message,
        [string[]]$Metadata
    )

    if (-not $script:CiMode) {
        return
    }

    $escapedMessage = Escape-CiAnnotationText -Text $Message

    $metaText = ''
    if ($Metadata) {
        $filtered = $Metadata | Where-Object { $_ -like '*=*' }
        if ($filtered) {
            $metaText = ' ' + ($filtered -join ',')
        }
    }

    Write-Output ("::{0}{1}::{2}" -f $Type, $metaText, $escapedMessage)
}

function Validate-MdkConfig {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )

    if (-not (Test-Path -LiteralPath $script:VerifyMdkScript)) {
        Write-Log -Level 'debug' -Message ("MDK verifier missing at {0}" -f $script:VerifyMdkScript)
        return 127
    }

    & $script:VerifyMdkScript @Arguments
    return $LASTEXITCODE
}

Export-ModuleMember -Function @(
    'Parse-CommonArgs',
    'Initialize-Logging',
    'Write-Log',
    'Register-Action',
    'Emit-Summary',
    'Encode-CiAnnotation',
    'Validate-MdkConfig'
)
