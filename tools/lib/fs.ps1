# LibFs shared library (PowerShell implementation)
# Provides filesystem planning helpers (directory/file ensures, copy/move plans).
# Planning outputs are side-effect free; callers own any execution.

Set-StrictMode -Version Latest

$script:LibFsProtectedPatterns = @('*.mdk.ini', 'se-config.ini')

function Normalize-Path {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-ContentHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Bytes,
        [string]$Algorithm = 'sha256'
    )

    $algorithmName = $Algorithm.ToUpperInvariant()
    switch ($algorithmName) {
        'SHA256' { $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create() }
        default { throw "Unsupported hash algorithm: $Algorithm" }
    }

    try {
        $hash = $hashAlgorithm.ComputeHash($Bytes)
        return [System.BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $hashAlgorithm.Dispose()
    }
}

function Test-ProtectedPath {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string[]]$ProtectedPatterns = $script:LibFsProtectedPatterns
    )

    if (-not $Path) {
        return $false
    }

    $fullPath = Normalize-Path -Path $Path
    $lower = $fullPath.ToLowerInvariant()

    if ($lower.EndsWith('.local.ini')) {
        return $false
    }

    foreach ($pattern in $ProtectedPatterns) {
        if (-not $pattern) { continue }
        $wildcard = New-Object System.Management.Automation.WildcardPattern($pattern, 'IgnoreCase')
        if ($wildcard.IsMatch($fullPath) -or $wildcard.IsMatch([System.IO.Path]::GetFileName($fullPath))) {
            return $true
        }
    }

    return $false
}

function ConvertTo-LibFsPlan {
    param(
        [Parameter(Mandatory)] $Plan
    )

    if ($Plan -is [System.Collections.IDictionary]) {
        $actions = @()
        if ($Plan.Contains('Actions')) {
            $raw = $Plan['Actions']
            if ($null -ne $raw) {
                if ($raw -is [System.Collections.IEnumerable] -and -not ($raw -is [string])) {
                    $actions = @($raw)
                }
                else {
                    $actions = @($raw)
                }
            }
        }
        $conflicts = @()
        if ($Plan.Contains('Conflicts')) {
            $rawConflicts = $Plan['Conflicts']
            if ($null -ne $rawConflicts) {
                if ($rawConflicts -is [System.Collections.IEnumerable] -and -not ($rawConflicts -is [string])) {
                    $conflicts = @($rawConflicts)
                }
                else {
                    $conflicts = @($rawConflicts)
                }
            }
        }
        return [pscustomobject]@{
            Actions   = @($actions | ForEach-Object { $_ })
            Conflicts = @($conflicts | ForEach-Object { $_ })
        }
    }

    if ($Plan -is [psobject] -and $Plan.PSObject.Properties['Actions']) {
        $actions = @($Plan.Actions | ForEach-Object { $_ })
        $conflicts = @()
        if ($Plan.PSObject.Properties['Conflicts']) {
            $conflicts = @($Plan.Conflicts | ForEach-Object { $_ })
        }
        return [pscustomobject]@{
            Actions   = $actions
            Conflicts = $conflicts
        }
    }

    throw "Plan must expose Actions and Conflicts collections."
}

function Plan-EnsureDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    $fullPath = Normalize-Path -Path $Path
    $actions = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        $actions.Add([pscustomobject]@{ Op = 'mkdir'; Path = $fullPath })
    }

    return [pscustomobject]@{
        Actions   = $actions.ToArray()
        Conflicts = @()
    }
}

function Plan-EnsureFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content,
        [ValidateSet('create', 'overwrite', 'if-changed')]
        [string]$Mode = 'create',
        [string]$Encoding = 'utf-8'
    )

    $fullPath = Normalize-Path -Path $Path
    $actions = New-Object System.Collections.Generic.List[object]
    $conflicts = New-Object System.Collections.Generic.List[object]

    $textEncoding = [System.Text.Encoding]::GetEncoding($Encoding)
    $desiredBytes = $textEncoding.GetBytes($Content)
    $desiredHash = Get-ContentHash -Bytes $desiredBytes -Algorithm 'sha256'

    $fileExists = Test-Path -LiteralPath $fullPath -PathType Leaf
    $existingHash = $null

    if ($fileExists) {
        $existingBytes = [System.IO.File]::ReadAllBytes($fullPath)
        $existingHash = Get-ContentHash -Bytes $existingBytes -Algorithm 'sha256'
    }

    $diff = $null
    if ($null -ne $existingHash -and $existingHash -ne $desiredHash) {
        $diff = [pscustomobject]@{
            OldHash       = $existingHash
            NewHash       = $desiredHash
            HashAlgorithm = 'sha256'
        }
    }

    switch ($Mode) {
        'create' {
            if ($fileExists) {
                $conflicts.Add([pscustomobject]@{
                        Op      = 'write'
                        Path    = $fullPath
                        Reason  = 'File exists; use overwrite or if-changed mode.'
                        Current = 'exists'
                    })
            }
            else {
                $actions.Add([pscustomobject]@{
                        Op            = 'write'
                        Path          = $fullPath
                        Content       = $Content
                        Mode          = $Mode
                        Encoding      = $Encoding
                        Hash          = $desiredHash
                        HashAlgorithm = 'sha256'
                    })
            }
        }
        'overwrite' {
            $action = [pscustomobject]@{
                Op            = 'write'
                Path          = $fullPath
                Content       = $Content
                Mode          = $Mode
                Encoding      = $Encoding
                Hash          = $desiredHash
                HashAlgorithm = 'sha256'
            }
            if ($diff) { $action | Add-Member -MemberType NoteProperty -Name Diff -Value $diff }
            $actions.Add($action)
        }
        'if-changed' {
            if ($fileExists) {
                if ($existingHash -ne $desiredHash) {
                    $action = [pscustomobject]@{
                        Op            = 'write'
                        Path          = $fullPath
                        Content       = $Content
                        Mode          = $Mode
                        Encoding      = $Encoding
                        Hash          = $desiredHash
                        HashAlgorithm = 'sha256'
                    }
                    if ($diff) { $action | Add-Member -MemberType NoteProperty -Name Diff -Value $diff }
                    $actions.Add($action)
                }
            }
            else {
                $actions.Add([pscustomobject]@{
                        Op            = 'write'
                        Path          = $fullPath
                        Content       = $Content
                        Mode          = $Mode
                        Encoding      = $Encoding
                        Hash          = $desiredHash
                        HashAlgorithm = 'sha256'
                    })
            }
        }
    }

    return [pscustomobject]@{
        Actions   = $actions.ToArray()
        Conflicts = $conflicts.ToArray()
    }
}

function Plan-Copy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Target,
        [switch]$Overwrite
    )

    $sourcePath = Normalize-Path -Path $Source
    $targetPath = Normalize-Path -Path $Target

    return [pscustomobject]@{
        Actions   = @([pscustomobject]@{
                Op          = 'copy'
                Source      = $sourcePath
                Destination = $targetPath
                Overwrite   = [bool]$Overwrite
            })
        Conflicts = @()
    }
}

function Plan-Move {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Target,
        [switch]$Overwrite
    )

    $sourcePath = Normalize-Path -Path $Source
    $targetPath = Normalize-Path -Path $Target

    return [pscustomobject]@{
        Actions   = @([pscustomobject]@{
                Op          = 'move'
                Source      = $sourcePath
                Destination = $targetPath
                Overwrite   = [bool]$Overwrite
            })
        Conflicts = @()
    }
}

function Validate-Plan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Plan,
        [string[]]$ProtectedPatterns = $script:LibFsProtectedPatterns
    )

    $planObject = ConvertTo-LibFsPlan -Plan $Plan
    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    if ($planObject.Conflicts.Count -gt 0) {
        foreach ($conflict in $planObject.Conflicts) {
            $errors.Add("Plan contains conflict: $($conflict)")
        }
    }

    $validOps = 'mkdir', 'write', 'copy', 'move'
    foreach ($action in $planObject.Actions) {
        if (-not $validOps.Contains($action.Op)) {
            $errors.Add("Unsupported action op '$($action.Op)'")
            continue
        }

        if (-not $action.Path -and $action.Op -eq 'write') {
            $errors.Add('Write action missing Path property.')
        }

        if ($action.Op -eq 'write') {
            if (Test-ProtectedPath -Path $action.Path -ProtectedPatterns $ProtectedPatterns) {
                $errors.Add("Write action targets protected path: $($action.Path)")
            }
        }

        if ($action.Op -in @('copy', 'move')) {
            $source = $action.Source
            $destination = $action.Destination
            if (-not $source -or -not $destination) {
                $errors.Add("$($action.Op) action missing source or destination.")
            }
            if ($destination -and (Test-ProtectedPath -Path $destination -ProtectedPatterns $ProtectedPatterns)) {
                $errors.Add("$($action.Op) action targets protected destination: $destination")
            }
        }
    }

    return [pscustomobject]@{
        IsValid  = ($errors.Count -eq 0)
        Errors   = $errors.ToArray()
        Warnings = $warnings.ToArray()
        Plan     = $planObject
    }
}

function Render-Plan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Plan,
        [string]$Header
    )

    $planObject = ConvertTo-LibFsPlan -Plan $Plan
    $builder = New-Object System.Text.StringBuilder
    if ($Header) {
        [void]$builder.AppendLine($Header)
    }

    foreach ($action in $planObject.Actions) {
        switch ($action.Op) {
            'mkdir' {
                [void]$builder.AppendLine(("mkdir -> {0}" -f $action.Path))
            }
            'write' {
                $modeLabel = if ($action.PSObject.Properties['Mode']) { $action.Mode } else { 'create' }
                [void]$builder.AppendLine(("write({0}) -> {1}" -f $modeLabel, $action.Path))
            }
            'copy' {
                [void]$builder.AppendLine(("copy -> {0} -> {1}" -f $action.Source, $action.Destination))
            }
            'move' {
                [void]$builder.AppendLine(("move -> {0} -> {1}" -f $action.Source, $action.Destination))
            }
        }
    }

    foreach ($conflict in $planObject.Conflicts) {
        [void]$builder.AppendLine(("conflict -> {0}" -f ($conflict | Out-String).Trim()))
    }

    return $builder.ToString().TrimEnd()
}
