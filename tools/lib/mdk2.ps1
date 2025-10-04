# LibMDK2 shared library (PowerShell implementation)
# Provides MDK2 configuration discovery, parsing, validation, and project diagnostics helpers.
# Planning/inspection only – no writes, no exits.

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'config.ps1')

$script:Mdk2TrackedPatterns = @('*.mdk.ini', '*.mdk.local.ini')
$script:Mdk2KeysToCompare = @('type', 'trace', 'minify', 'ignores', 'donotclean', 'output', 'binarypath')
$script:Mdk2AllowedTypes = @('programmableblock', 'mod')
$script:Mdk2AllowedTrace = @('on', 'off')
$script:Mdk2AllowedMinify = @('none', 'trim', 'stripcomments', 'lite', 'full')

function ConvertTo-CaseInsensitiveHashtable {
    param(
        [System.Collections.IDictionary]$Source
    )

    $target = New-Object System.Collections.Hashtable ([System.StringComparer]::OrdinalIgnoreCase)
    if (-not $Source) {
        return $target
    }

    foreach ($key in $Source.Keys) {
        $value = $Source[$key]
        if ($value -is [System.Collections.IDictionary]) {
            $target[$key] = ConvertTo-CaseInsensitiveHashtable -Source $value
        }
        else {
            $target[$key] = $value
        }
    }

    return $target
}

function Get-MdkSection {
    param(
        [System.Collections.IDictionary]$Data
    )

    if (-not $Data) {
        return $null
    }

    if ($Data.ContainsKey('mdk')) {
        return $Data['mdk']
    }

    return $null
}

function Find-Mdk2Configs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Root,
        [string[]]$Patterns = $script:Mdk2TrackedPatterns
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        return [pscustomobject]@{ Paths = @() }
    }

    $items = Get-ChildItem -Path $Root -Recurse -File -Include $Patterns -ErrorAction SilentlyContinue
    $paths = @($items | Sort-Object FullName | Select-Object -ExpandProperty FullName)
    return [pscustomobject]@{ Paths = $paths }
}

function Read-Mdk2Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    $raw = Read-Config -Path $Path
    if ($raw.Format -ne 'ini') {
        throw "Unsupported config format at $Path"
    }

    $data = ConvertTo-CaseInsensitiveHashtable -Source $raw.Data
    return [pscustomobject]@{
        Source = $Path
        Data = $data
    }
}

function Get-Mdk2ProjectInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ProjectRoot
    )

    $notes = New-Object System.Collections.Generic.List[string]
    $mdkDir = Join-Path $ProjectRoot 'MDK'
    $scriptsDir = Join-Path $ProjectRoot 'Scripts'

    $hasTemplates = Test-Path -LiteralPath $mdkDir
    if (-not $hasTemplates) {
        $notes.Add('MDK templates directory missing.')
    }

    $templateVersion = $null
    $templatesVersionPath = Join-Path $mdkDir 'Templates.version.txt'
    if (Test-Path -LiteralPath $templatesVersionPath) {
        $line = (Get-Content -LiteralPath $templatesVersionPath -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($line) {
            $templateVersion = $line.Trim()
        }
    }

    $scriptsPath = $null
    if (Test-Path -LiteralPath $scriptsDir) {
        $scriptsPath = $scriptsDir
    }
    else {
        $notes.Add('Scripts directory missing.')
    }

    return [pscustomobject]@{
        HasTemplates = $hasTemplates
        TemplateVersion = if ($templateVersion) { $templateVersion } else { $null }
        ScriptsPath = $scriptsPath
        Notes = $notes.ToArray()
    }
}

function Validate-Mdk2Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable]$Data,
        [string]$MinTemplate
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    $section = Get-MdkSection -Data $Data
    if (-not $section) {
        $errors.Add('Missing [mdk] section.')
        return [pscustomobject]@{
            IsValid = $false
            Errors = $errors.ToArray()
            Warnings = $warnings.ToArray()
        }
    }

    if (-not $section.ContainsKey('type')) {
        $errors.Add('Missing key mdk.type.')
    }
    else {
        $typeValue = $section['type'].ToLowerInvariant()
        if ($script:Mdk2AllowedTypes -notcontains $typeValue) {
            $errors.Add("Invalid mdk.type value '$typeValue'.")
        }
    }

    if ($section.ContainsKey('trace')) {
        $traceValue = $section['trace'].ToLowerInvariant()
        if ($script:Mdk2AllowedTrace -notcontains $traceValue) {
            $warnings.Add("Unexpected mdk.trace value '$traceValue'.")
        }
    }

    if ($section.ContainsKey('minify')) {
        $minifyValue = $section['minify'].ToLowerInvariant()
        if ($script:Mdk2AllowedMinify -notcontains $minifyValue) {
            $warnings.Add("Unsupported mdk.minify value '$minifyValue'.")
        }
    }

    return [pscustomobject]@{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors.ToArray()
        Warnings = $warnings.ToArray()
    }
}

function Compare-MdkValues {
    param(
        [string]$Key,
        [pscustomobject[]]$Entries
    )

    if (-not $Entries -or $Entries.Count -le 1) {
        return @()
    }

    $groups = $Entries | Group-Object -Property Value

    if ($groups.Count -le 1) {
        return @()
    }

    $details = $Entries | ForEach-Object {
        "{0} -> {1}" -f (Split-Path $_.Path -Leaf), $_.Value
    }

    if ($Key -in @('output', 'binarypath')) {
        return @()
    }

    return @("mdk.$Key differs between configs: $($details -join '; ')")
}

function Validate-Mdk2Project {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [string]$MinTemplate
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    $configPaths = (Find-Mdk2Configs -Root $ProjectRoot).Paths
    if ($configPaths.Count -eq 0) {
        $errors.Add('MDK-001: No MDK2 configs found.')
    }

    $configRecords = @()
    foreach ($path in $configPaths) {
        try {
            $config = Read-Mdk2Config -Path $path
            $validation = Validate-Mdk2Config -Data $config.Data
            foreach ($err in $validation.Errors) { $errors.Add(("{0}: {1}" -f $path, $err)) }
            foreach ($warn in $validation.Warnings) { $warnings.Add(("{0}: {1}" -f $path, $warn)) }
            $configRecords += [pscustomobject]@{ Path = $path; Data = $config.Data }
        }
        catch {
            $errors.Add("MDK-002: Failed to read $path. $_")
        }
    }

    foreach ($key in $script:Mdk2KeysToCompare) {
        $entries = @()
        foreach ($record in $configRecords) {
            $section = Get-MdkSection -Data $record.Data
            if ($section -and $section.ContainsKey($key)) {
                $entries += [pscustomobject]@{ Path = $record.Path; Value = $section[$key] }
            }
        }
        $differences = Compare-MdkValues -Key $key -Entries $entries
        foreach ($diff in $differences) {
            $warnings.Add($diff)
        }
    }

    $info = Get-Mdk2ProjectInfo -ProjectRoot $ProjectRoot

    if ($MinTemplate) {
        if ($info.TemplateVersion) {
            try {
                $actualVersion = [version]$info.TemplateVersion
                $requiredVersion = [version]$MinTemplate
                if ($actualVersion -lt $requiredVersion) {
                    $errors.Add("MDK-003: Template version $($info.TemplateVersion) below required $MinTemplate.")
                }
            }
            catch {
                $warnings.Add("Template version '$($info.TemplateVersion)' could not be parsed.")
            }
        }
        else {
            $warnings.Add('Template version unavailable; minimum cannot be enforced.')
        }
    }

    return [pscustomobject]@{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors.ToArray()
        Warnings = $warnings.ToArray()
        Info = $info
        ConfigPaths = $configPaths
    }
}

function Render-Mdk2Summary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Diagnostics
    )

    $isValid = if ($Diagnostics.PSObject.Properties['IsValid']) { [bool]$Diagnostics.IsValid } else { $false }
    $errorsCount = if ($Diagnostics.PSObject.Properties['Errors'] -and $Diagnostics.Errors) { $Diagnostics.Errors.Count } else { 0 }
    $warningsCount = if ($Diagnostics.PSObject.Properties['Warnings'] -and $Diagnostics.Warnings) { $Diagnostics.Warnings.Count } else { 0 }

    $status = if ($isValid) { 'passed' } else { 'failed' }
    $lines = @(
        "mdk2 validation: $status",
        "errors: $errorsCount",
        "warnings: $warningsCount"
    )

    return [string]::Join([Environment]::NewLine, $lines)
}
