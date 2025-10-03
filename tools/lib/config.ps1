# LibConfig shared library (PowerShell implementation)
# Provides read-only configuration discovery, parsing, merging, validation, diff rendering, and schema lookup helpers.

$script:LibConfigSchemas = @{
    'se-config.ini' = [pscustomobject]@{
        Name     = 'se-config.ini'
        Version  = 'v1'
        Sections = [ordered]@{
            general = [ordered]@{
                Keys     = @('binarypath', 'output', 'steam_path', 'game_path')
                Required = @('binarypath', 'output')
            }
            mdk = [ordered]@{
                Keys     = @('output', 'binarypath')
                Required = @('output')
            }
        }
    }
}

function Get-ConfigSources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Root,
        [string[]]$Patterns = @('se-config.ini', 'se-config.local.ini', '*.mdk.ini', '*.mdk.local.ini')
    )

    if (-not (Test-Path -Path $Root)) {
        return [pscustomobject]@{ Sources = @() }
    }

    $sources = Get-ChildItem -Path $Root -Recurse -File -Include $Patterns -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    return [pscustomobject]@{ Sources = $sources }
}

function Read-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Config file not found: $Path"
    }

    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -eq '.json') {
        $data = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable
        return [pscustomobject]@{ Format = 'json'; Data = $data }
    }

    $iniData = [ordered]@{}
    $currentSection = $null
    foreach ($line in Get-Content -Path $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed || $trimmed.StartsWith(';') || $trimmed.StartsWith('#')) {
            continue
        }
        if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
            $sectionName = $trimmed.Trim('[', ']')
            if (-not $iniData.Contains($sectionName)) {
                $iniData[$sectionName] = [ordered]@{}
            }
            $currentSection = $iniData[$sectionName]
            continue
        }
        $parts = $trimmed.Split('=', 2)
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            if (-not $currentSection) {
                $iniData[''] = $iniData[''] ?? [ordered]@{}
                $currentSection = $iniData['']
            }
            $currentSection[$key] = $value
        }
    }

    return [pscustomobject]@{ Format = 'ini'; Data = $iniData }
}

function Merge-Configs {
    [CmdletBinding()]
    param(
        [hashtable]$Base,
        [hashtable]$Overlay,
        [hashtable]$Env
    )

    if (-not $Base) { $Base = [ordered]@{} }
    if (-not $Overlay) { $Overlay = [ordered]@{} }

    $result = [ordered]@{}
    $sections = New-Object System.Collections.Generic.HashSet[string]
    foreach ($s in @($Base.Keys) + @($Overlay.Keys)) { [void]$sections.Add($s) }

    foreach ($section in $sections) {
        $baseSection = $Base[$section]
        $overlaySection = $Overlay[$section]
        if (-not $baseSection -and -not $overlaySection) { continue }
        $merged = [ordered]@{}
        if ($baseSection) { foreach ($key in $baseSection.Keys) { $merged[$key] = $baseSection[$key] } }
        if ($overlaySection) { foreach ($key in $overlaySection.Keys) { $merged[$key] = $overlaySection[$key] } }
        $result[$section] = $merged
    }

    if ($Env) {
        foreach ($entry in $Env.GetEnumerator()) {
            $path = $entry.Key
            $value = $entry.Value
            $segments = $path.Split('.', 2)
            if ($segments.Count -eq 2) {
                $sectionName = $segments[0]
                $keyName = $segments[1]
                if (-not $result.Contains($sectionName)) {
                    $result[$sectionName] = [ordered]@{}
                }
                $result[$sectionName][$keyName] = $value
            }
        }
    }

    return [pscustomobject]@{ Data = $result }
}

function Validate-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable]$Data,
        [hashtable]$Schema
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    if ($Schema) {
        foreach ($sectionName in $Schema.Sections.Keys) {
            $sectionSchema = $Schema.Sections[$sectionName]
            $requiredKeys = $sectionSchema.Required
            if ($requiredKeys) {
                foreach ($req in $requiredKeys) {
                    if (-not ($Data.$sectionName) -or -not ($Data.$sectionName).Contains($req)) {
                        $warnings.Add("Missing recommended key '$sectionName.$req'")
                    }
                }
            }
        }
    }

    return [pscustomobject]@{
        IsValid  = ($errors.Count -eq 0)
        Errors   = $errors.ToArray()
        Warnings = $warnings.ToArray()
    }
}

function Diff-Local {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable]$Effective,
        [Parameter(Mandatory)] [hashtable]$Desired
    )

    $changes = New-Object System.Collections.Generic.List[pscustomobject]
    $sectionNames = New-Object System.Collections.Generic.HashSet[string]
    foreach ($s in @($Effective.Keys) + @($Desired.Keys)) { [void]$sectionNames.Add($s) }

    foreach ($section in $sectionNames) {
        $effectiveSection = $Effective[$section]
        $desiredSection = $Desired[$section]
        $effectiveKeys = if ($effectiveSection) { $effectiveSection.Keys } else { @() }
        $desiredKeys = if ($desiredSection) { $desiredSection.Keys } else { @() }

        $allKeys = New-Object System.Collections.Generic.HashSet[string]
        foreach ($k in @($effectiveKeys) + @($desiredKeys)) { [void]$allKeys.Add($k) }

        foreach ($key in $allKeys) {
            $effectiveValue = if ($effectiveSection) { $effectiveSection[$key] } else { $null }
            $desiredValue = if ($desiredSection) { $desiredSection[$key] } else { $null }

            if ($null -eq $desiredValue -and $null -ne $effectiveValue) {
                $changes.Add([pscustomobject]@{
                    Action  = 'remove'
                    Section = $section
                    Key     = $key
                    Old     = [string]$effectiveValue
                    New     = $null
                })
            }
            elseif ($null -eq $effectiveValue -and $null -ne $desiredValue) {
                $changes.Add([pscustomobject]@{
                    Action  = 'add'
                    Section = $section
                    Key     = $key
                    Old     = $null
                    New     = [string]$desiredValue
                })
            }
            elseif ($null -ne $desiredValue -and [string]$desiredValue -ne [string]$effectiveValue) {
                $changes.Add([pscustomobject]@{
                    Action  = 'update'
                    Section = $section
                    Key     = $key
                    Old     = [string]$effectiveValue
                    New     = [string]$desiredValue
                })
            }
        }
    }

    return [pscustomobject]@{ Changes = $changes.ToArray() }
}

function Render-Ini {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.IEnumerable]$Changes,
        [string]$Header
    )

    $sections = [ordered]@{}
    foreach ($change in $Changes) {
        if ($change.Action -notin @('add', 'update')) { continue }
        $section = if ([string]::IsNullOrEmpty($change.Section)) { '' } else { $change.Section }
        if (-not $sections.Contains($section)) {
            $sections[$section] = New-Object System.Collections.Generic.List[pscustomobject]
        }
        $sections[$section].Add($change)
    }

    $builder = New-Object System.Text.StringBuilder
    if ($Header) {
        [void]$builder.AppendLine($Header)
    }

    foreach ($section in $sections.Keys) {
        if ($section -ne '') {
            [void]$builder.AppendLine("[$section]")
        }
        foreach ($change in $sections[$section]) {
            [void]$builder.AppendLine("$($change.Key)=$($change.New)")
        }
    }

    return $builder.ToString().TrimEnd()
}

function Get-ConfigSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Name
    )

    $lookup = $Name.ToLowerInvariant()
    if ($script:LibConfigSchemas.ContainsKey($lookup)) {
        return $script:LibConfigSchemas[$lookup]
    }
    return $null
}

function Get-EffectiveConfig {
    [CmdletBinding()]
    param(
        [string]$Root,
        [hashtable]$Env
    )

    $sources = Get-ConfigSources -Root $Root
    $base = [ordered]@{}
    $overlay = [ordered]@{}
    foreach ($source in $sources.Sources) {
        $parsed = Read-Config -Path $source
        if ($parsed.Format -eq 'ini') {
            if ($source -like '*.local.*') {
                $overlay = Merge-Configs -Base $overlay -Overlay $parsed.Data | Select-Object -ExpandProperty Data
            } else {
                $base = Merge-Configs -Base $base -Overlay $parsed.Data | Select-Object -ExpandProperty Data
            }
        }
    }

    $merged = Merge-Configs -Base $base -Overlay $overlay -Env $Env
    return [pscustomobject]@{
        Data      = $merged.Data
        Sources   = $sources.Sources
        Precedence = @('base', 'local', 'env')
    }
}
