> Tone: second person, active, imperative; precise and concise.

# Coding Style (canonical)

## Files, encoding, line endings

- All text: **UTF-8 (no BOM)**, Unix **LF**.
- `.editorconfig` is the single source of truth for whitespace/formatting.
- `.gitattributes` must enforce LF to match `.editorconfig`.

```gitattributes
# Excerpt  -  see .gitattributes for full config

# Default: normalize to LF in repo; enforce UTF-8; allow tooling to choose on checkout
*           text=auto eol=lf working-tree-encoding=UTF-8
```

```ini
# Excerpt  -  see .editorconfig for full config

# root editorconfig for dev-framework
root = true

############################################
# Core text settings (applies to all files)
############################################
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

# Default indentation: 2-space for docs/scripts; override for C#
indent_style = space
indent_size = 2
max_line_length = off

# C# source files: 4-space indentation
[*.cs]
indent_style = space
indent_size = 4
```

## Language & text (human-facing)

- **Language:** Use English (US) in all human-facing docs, commit messages, and in-repo prose. Keep dialect consistent within a document.
- **Emojis:** Allowed in `README.md` files (top-level and subfolders) for clarity/tone. Keep usage sparse and accessible (do not replace essential words).
- **ASCII-only punctuation (default):**
  - **Dashes:** use `-` (ASCII hyphen with spaces). Do not use en/em/figure dashes.
  - **Quotes:** use `'` and `"` (no smart quotes).
  - **Ellipsis:** use `...` (not the single-character ellipsis).
  - **Hyphens/Spaces:** replace non-breaking/soft hyphens and non-breaking spaces with ASCII `-` and normal spaces.
  - **Exceptions:** Unicode is permitted in literal quotations or URLs when fidelity is required; otherwise normalize to ASCII.

## Unicode usage (paths & strings)

- **Paths:** Tooling-owned and generated paths **MUST** be ASCII-only. Unicode paths **MAY** be used only in explicitly whitelisted content areas with UTF-8 and NFC normalization plus CI checks; disallow non-printing characters and emoji. Keep project names/namespaces ASCII.
- **Strings in SE scripts:** Use ASCII punctuation in logs, keys, and protocol tokens. Unicode **MAY** be used for player-visible UI text (LCD/chat) with ASCII fallbacks (e.g., `->` for arrows, `...` for ellipsis). Normalize to NFC; strip control characters; use culture-invariant comparisons; be aware of in-game font coverage limits.

## C# / .NET (MDK2 ingame scripts)

_Related spec:_ `docs/spec/tooling/ScaffoldMdk2Project.md`

- **Formatter:** `dotnet format` (respects `.editorconfig`).
- **Linter:** **Roslyn analyzers** enforced in build (`dotnet build -warnaserror`).
- **Language:** C# **6** for MDK2 compatibility.
- **Docs & comments:** follow `@comment-level` policy (see `AGENTS.md` / `.ai/policies/comment-levels.yaml`). Public XML docs recommended at _minimal_, required at _standard/verbose_.

```xml
<!-- Directory.Build.props (excerpt) -->
<Project>
  <PropertyGroup>
    <LangVersion>6</LangVersion>
    <EnableNETAnalyzers>true</EnableNETAnalyzers>
    <AnalysisLevel>recommended</AnalysisLevel>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
  <!-- Optional analyzers: Microsoft.CodeAnalysis.NetAnalyzers, StyleCop.Analyzers -->
</Project>
```

```ini
# .editorconfig  -  C# naming & analyzer severities (excerpt)
[*.cs]
dotnet_analyzer_diagnostic.category-Security.severity = error
dotnet_analyzer_diagnostic.category-Performance.severity = warning
dotnet_analyzer_diagnostic.category-Reliability.severity = warning

# Naming
dotnet_naming_rule.public_members_should_be_pascal_case.severity = suggestion
dotnet_naming_rule.public_members_should_be_pascal_case.symbols  = public_symbols
dotnet_naming_rule.public_members_should_be_pascal_case.style    = pascal_case_style
dotnet_naming_symbols.public_symbols.applicable_kinds = property,method,field,event
dotnet_naming_symbols.public_symbols.applicable_accessibilities = public, protected, protected_internal
dotnet_naming_style.pascal_case_style.capitalization = pascal_case

# Prefer braces, sorted usings
csharp_prefer_braces = true:suggestion
dotnet_sort_system_directives_first = true

# C#6-friendly: relax some globalization/async rules
dotnet_diagnostic.CA1305.severity = none
dotnet_diagnostic.CA1303.severity = none
dotnet_diagnostic.CA2007.severity = none
```

## PowerShell (repo tooling)

_Related spec:_ `docs/spec/tooling/SetupTooling.md`

- **Formatter:** `Invoke-Formatter` (PSScriptAnalyzer).
- **Linter:** `PSScriptAnalyzer` with repo settings: `tools/pssa/PSScriptAnalyzerSettings.psd1`.
- **Comments:** follow `@comment-level`; _standard_ and _verbose_ require Comment-Based Help for script entry points.

```powershell
# Format staged PowerShell files
$ps = git diff --cached --name-only -- '*.ps1' '*.psm1' '*.psd1'
if ($ps) {
  Import-Module PSScriptAnalyzer
  foreach ($f in $ps) {
    $src = Get-Content -Raw -Path $f
    $fmt = Invoke-Formatter -ScriptDefinition $src -Settings 'tools/pssa/PSScriptAnalyzerSettings.psd1'
    if ($fmt -ne $src) { $fmt | Set-Content -NoNewline -Encoding utf8 $f }
  }
  git add -- $ps
}
```

## Bash (repo tooling)

- **Formatter:** `shfmt`.
- **Linter:** `shellcheck` (config: `tools/shell/shellcheckrc`).
- **Rules file:** See `tools/shell/shellcheckrc`. Prefer fixing issues over disabling checks; if you must disable (`-e SCxxxx`), add a short inline rationale.
- **Comments:** follow `@comment-level`; provide top-of-file header with purpose/usage for _standard/verbose_.

```bash
# Staged-only formatting
files=$(git diff --cached --name-only -- '*.sh')
[ -z "$files" ] || shfmt -w $files
```

## Comment levels (summary)

- **minimal**: document public surface; comment tricky logic only.
- **standard**: public+internal docs; brief rationale on nontrivial code.
- **verbose**: onboarding quality; examples and edge cases.

Set via file pragma, e.g.:

- C#: `// @comment-level: minimal`
- PS/Bash: `# @comment-level: standard`

(Policy defaults/overrides live in `.ai/policies/comment-levels.yaml`; precedence is pragma → pins → overrides → default.)

## File headers & autogenerated markers

- Add a brief header referencing project and license where feasible.
- Autogenerated files **must** start with:
  - Bash/PowerShell: `# AUTO-GENERATED: DO NOT EDIT`
  - C#: `// AUTO-GENERATED: DO NOT EDIT`

## PowerShell conventions

- **Naming:** PascalCase for functions and parameters.
- **Function style:** prefer **advanced functions** with `[CmdletBinding()]`.
- **Error handling:** `$ErrorActionPreference = 'Stop'` in tooling entry points.
- **CLI parity:** mirror option names/behavior with Bash twins where both exist.
- **Logging:** support `-Verbose`; optional `-NotesOnly` per tooling spec.

## Bash conventions

- Start scripts with `set -euo pipefail` (document deviations inline).
- **Naming:** `snake_case` for variables and functions.
- **CLI parity:** mirror PowerShell options where both exist.
- Shebang: `#!/usr/bin/env bash`.

## C# / MDK2 scaffolding

- Use **partial classes** for MDK2 scaffolds.
- Keep naming PascalCase for namespaces/types/members.

## Documentation references

- Keep Markdown soft wrap at **80–100** characters where practical.
- When introducing a new style rule, **link back** to its governing spec/policy.
