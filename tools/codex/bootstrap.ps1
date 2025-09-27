#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

# UTF-8 for console
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$root = (git rev-parse --show-toplevel)

# Core policy SSOT
$policyCore = @(
  ".ai/policies/core.yaml",
  ".ai/policies/style.yaml",
  ".ai/policies/safety.yaml",
  ".ai/policies/file-policy.yaml"
)

# Available workflows
$WF_DOCS   = ".ai/workflows/docs.yaml"
$WF_CODE   = ".ai/workflows/code.yaml"
$WF_CONFIG = ".ai/workflows/config.yaml"

# Staged files
$staged = (git diff --name-only --cached) -split "`n" | Where-Object { $_ -and ($_ -ne "") }
if (-not $staged) {
  Write-Error "No staged files. Stage exact targets first (git add <files>)."
  exit 1
}

# Parse --wf=docs|code|config and strip from args
$wfOverride = $null
$taskArgs = New-Object System.Collections.Generic.List[string]
foreach ($a in $args) {
  if ($a -like '--wf=*') {
    $wfOverride = ($a -split '=',2)[1]
  } else {
    [void]$taskArgs.Add($a)
  }
}

function Select-Workflows([string[]]$Paths) {
  $chosen = New-Object System.Collections.Generic.HashSet[string]
  foreach ($p in $Paths) {
    if ($p -like 'docs/*' -or $p -like '*.md') { [void]$chosen.Add($WF_DOCS) }
    if ($p -like 'tools/*' -or $p -like 'src/*' -or $p -like 'source/*') { [void]$chosen.Add($WF_CODE) }
    if ($p -like '*.ini' -or $p -like '*.yaml' -or $p -like '*.yml' -or $p -like '*.json' -or $p -like 'config/*') { [void]$chosen.Add($WF_CONFIG) }
  }
  return $chosen.ToArray()
}

switch ($wfOverride) {
  'docs'   { $workflows = @($WF_DOCS) }
  'code'   { $workflows = @($WF_CODE) }
  'config' { $workflows = @($WF_CONFIG) }
  default  { $workflows = Select-Workflows $staged }
}

if (-not $workflows -or $workflows.Count -eq 0) {
  $workflows = @($WF_DOCS)
}

# Verify files
$toCheck = @()
$toCheck += $policyCore | ForEach-Object { Join-Path $root $_ }
$toCheck += $workflows  | ForEach-Object { Join-Path $root $_ }
$missing = $toCheck | Where-Object { -not (Test-Path $_) }
if ($missing) {
  Write-Error ("Missing policy/workflow files:`n{0}" -f ($missing -join "`n"))
  exit 2
}

if ($taskArgs.Count -eq 0) {
  Write-Error "No task message provided. Example: bootstrap.ps1 'Align X with template, ASCII only.'"
  exit 1
}
$task = ($taskArgs -join ' ')

Write-Host "Staged scope:"
$staged | ForEach-Object { Write-Host (" - {0}" -f $_) }
Write-Host "Workflows:"
$workflows | ForEach-Object { Write-Host (" - {0}" -f $_) }

# Build --context (absolute paths, space-separated)
$context = @()
$context += $policyCore | ForEach-Object { Join-Path $root $_ }
$context += $workflows  | ForEach-Object { Join-Path $root $_ }
$contextArg = ($context -join ' ')

# Invoke Codex CLI
# Replace `codex` with your real CLI.
npx codex `
  --context $contextArg `
  --files $staged `
  --task "$task"

# Tips:
# - For new files, stage intent first: git add -N path\to\newfile
# - Prefer running your codex with a dry-run flag if available
