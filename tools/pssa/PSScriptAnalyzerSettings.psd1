# PSScriptAnalyzer settings for dev-framework (tools/pssa/PSScriptAnalyzerSettings.psd1)
# - Purpose: consistent PowerShell lint rules across local runs and CI.
# - Scope: repository PowerShell scripts/modules; excludes tests and generated code.
# - Tone: neutral, minimal comments; see docs/policy/CodingStyle.md for rationale.
# - Encoding: UTF-8 (no BOM) per CodingStyle; PSScriptAnalyzer BOM rule intentionally not enforced.
@{
  # Prefer explicit tweaks over blanket disables. Keep disables minimal and documented.

  # Commonly noisy rules for CLI tooling; revisit if needed
  ExcludeRules = @(
    'PSAvoidUsingWriteHost'    # CLI tools may intentionally use Write-Host
  )

  # Baseline hygiene rules to keep scripts readable and safe
  IncludeRules = @(
    'PSUseConsistentIndentation',
    'PSUseConsistentWhitespace',
    'PSUseDeclaredVarsMoreThanAssignments',
    'PSAvoidUsingInvokeExpression',
    'PSAvoidUsingPlainTextForPassword'
  )

  # Rule configurations aligned with CodingStyle (2-space indent, brace/spacing hygiene)
  Rules = @{
    PSUseConsistentIndentation = @{ Enable = $true; IndentationSize = 4; PipelineIndentation = 'Increase' }
    PSUseConsistentWhitespace  = @{ Enable = $true; CheckOpenBrace = $true; CheckInnerBrace = $true; CheckOpenParen = $true; CheckSeparator = $true; CheckPipe = $true }
    PSPlaceOpenBrace           = @{ Enable = $true; OnSameLine = $true }
    PSAlignAssignmentStatement = @{ Enable = $true }
  }

  # Do not lint tests/helpers or generated output
  ExcludePaths = @(
    'tools/tests/**',
    '**/generated/**'
  )
}

