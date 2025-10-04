# LibDotnetProj shared library (PowerShell implementation)
# Provides read/inspect/plan helpers for MSBuild project files (csproj, shproj, projitems).
# No writes; callers own execution of planned actions.

Set-StrictMode -Version Latest

function Read-DotnetProject {
    [CmdletBinding()]
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Project file not found: $Path"
    }

    $xmlText = Get-Content -LiteralPath $Path -Raw
    try {
        [xml]$doc = $xmlText
    }
    catch {
        throw "Failed to parse project XML: $Path"
    }

    $kind = switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.csproj' { 'csproj' }
        '.shproj' { 'shproj' }
        '.projitems' { 'projitems' }
        default { 'unknown' }
    }

    $properties = [ordered]@{}
    $propertyGroups = $doc.SelectNodes('/*[local-name()="Project"]/*[local-name()="PropertyGroup"]')
    foreach ($propertyGroup in $propertyGroups) {
        foreach ($child in $propertyGroup.ChildNodes) {
            if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                $name = $child.Name
                if (-not $properties.Contains($name)) {
                    $properties[$name] = $child.InnerText.Trim()
                }
            }
        }
    }

    $items = @()
    $itemGroups = $doc.SelectNodes('/*[local-name()="Project"]/*[local-name()="ItemGroup"]')
    foreach ($itemGroup in $itemGroups) {
        foreach ($itemNode in $itemGroup.ChildNodes) {
            if ($itemNode.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
            $metadata = [ordered]@{}
            foreach ($meta in $itemNode.ChildNodes) {
                if ($meta.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                    $metadata[$meta.Name] = $meta.InnerText.Trim()
                }
            }
            $includeAttr = $itemNode.Attributes['Include']
            $items += [pscustomobject]@{
                Item     = $itemNode.Name
                Include  = if ($includeAttr) { $includeAttr.Value } else { $null }
                Metadata = $metadata
            }
        }
    }

    $imports = @()
    $importNodes = $doc.SelectNodes('/*[local-name()="Project"]/*[local-name()="Import"]')
    foreach ($import in $importNodes) {
        $projectAttr = $import.Attributes['Project']
        $labelAttr = $import.Attributes['Label']
        $conditionAttr = $import.Attributes['Condition']
        $imports += [pscustomobject]@{
            Project   = if ($projectAttr) { $projectAttr.Value } else { $null }
            Label     = if ($labelAttr) { $labelAttr.Value } else { $null }
            Condition = if ($conditionAttr) { $conditionAttr.Value } else { $null }
        }
    }

    $model = [pscustomobject]@{
        Path       = $Path
        Kind       = $kind
        Properties = $properties
        Items      = $items
        Imports    = $imports
    }

    return [pscustomobject]@{
        Kind  = $kind
        Xml   = $xmlText
        Model = $model
    }
}

function Validate-PbScriptProject {
    [CmdletBinding()]
    param(
        $Model
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    if ($Model.Kind -ne 'csproj') {
        $errors.Add('PB Script projects must be csproj files.')
    }

    if (-not $Model.Properties.Contains('TargetFramework')) {
        $errors.Add('TargetFramework property missing.')
    }

    return [pscustomobject]@{
        IsValid  = ($errors.Count -eq 0)
        Errors   = $errors.ToArray()
        Warnings = $warnings.ToArray()
    }
}

function Validate-MixinProject {
    [CmdletBinding()]
    param(
        $Model
    )

    return [pscustomobject]@{
        IsValid  = $true
        Errors   = @()
        Warnings = @()
    }
}

function Get-ImportKey {
    param(
        [string]$Project,
        [string]$Label
    )

    return ("{0}|{1}" -f ($Project ?? ''), ($Label ?? ''))
}

function Plan-ImportShared {
    param(
        $Model,
        [string]$ProjitemsPath
    )

    $actions = New-Object System.Collections.Generic.List[object]
    $existing = @($Model.Imports | Where-Object {
            $_.Project -and ($_.Project -eq $ProjitemsPath) -and (($_.Label ?? 'Shared') -eq 'Shared')
        })

    if ($existing.Count -eq 0) {
        $actions.Add([pscustomobject]@{
                Op      = 'ensure-import'
                Project = $ProjitemsPath
                Label   = 'Shared'
                Before  = $null
            })
    }

    return [pscustomobject]@{
        Actions   = $actions.ToArray()
        Conflicts = @()
    }
}

function Plan-AddItem {
    param(
        $Model,
        [string]$Item,
        [string]$Include,
        [hashtable]$Metadata
    )

    $actions = New-Object System.Collections.Generic.List[object]
    $exists = @($Model.Items | Where-Object { $_.Item -eq $Item -and $_.Include -eq $Include })
    if ($exists.Count -eq 0) {
        $meta = [ordered]@{}
        if ($Metadata) {
            foreach ($key in $Metadata.Keys) {
                $meta[$key] = $Metadata[$key]
            }
        }
        $actions.Add([pscustomobject]@{
                Op       = 'ensure-item'
                Item     = $Item
                Include  = $Include
                Metadata = $meta
            })
    }

    return [pscustomobject]@{
        Actions   = $actions.ToArray()
        Conflicts = @()
    }
}

function Plan-SetProperty {
    param(
        $Model,
        [string]$Name,
        [string]$Value
    )

    $actions = New-Object System.Collections.Generic.List[object]
    $currentValue = if ($Model.Properties.Contains($Name)) { $Model.Properties[$Name] } else { $null }
    if ($currentValue -ne $Value) {
        $actions.Add([pscustomobject]@{
                Op    = 'ensure-property'
                Name  = $Name
                Value = $Value
            })
    }

    return [pscustomobject]@{
        Actions   = $actions.ToArray()
        Conflicts = @()
    }
}

function Plan-Remove {
    param(
        [string]$Selector
    )

    return [pscustomobject]@{
        Actions   = @([pscustomobject]@{ Op = 'remove'; Selector = $Selector })
        Conflicts = @()
    }
}

function Validate-PlanXml {
    param(
        $Actions,
        [string]$Kind
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    if (-not $Actions) {
        return [pscustomobject]@{
            IsValid  = $true
            Errors   = @()
            Warnings = @()
        }
    }

    $actionsArray = if ($Actions -is [System.Array]) { $Actions } else { @($Actions) }
    $imports = $actionsArray | Where-Object { $_.Op -eq 'ensure-import' -and $_.Project }
    $importGroups = $imports | Group-Object -Property Project
    foreach ($group in $importGroups) {
        $labels = $group.Group | ForEach-Object { $_.Label ?? '' } | Sort-Object -Unique
        if ($labels.Count -gt 1) {
            $errors.Add("Conflicting ensure-import actions for project '$($group.Name)'.")
        }
    }

    return [pscustomobject]@{
        IsValid  = ($errors.Count -eq 0)
        Errors   = $errors.ToArray()
        Warnings = $warnings.ToArray()
    }
}

function Render-XmlPlan {
    param(
        $Actions,
        [string]$Header
    )

    $lines = New-Object System.Collections.Generic.List[string]
    if ($Header) { $lines.Add($Header) }

    $actionsArray = if ($Actions -is [System.Array]) { $Actions } else { @($Actions) }
    foreach ($action in $actionsArray) {
        switch ($action.Op) {
            'ensure-import' { $lines.Add("ensure-import -> $($action.Project) [Label=$($action.Label)]") }
            'ensure-item' { $lines.Add("ensure-item -> $($action.Item) Include=$($action.Include)") }
            'ensure-property' { $lines.Add("ensure-property -> $($action.Name)=$($action.Value)") }
            'remove' { $lines.Add("remove -> $($action.Selector)") }
            default { $lines.Add("$($action.Op)") }
        }
    }

    return [string]::Join([Environment]::NewLine, $lines)
}
