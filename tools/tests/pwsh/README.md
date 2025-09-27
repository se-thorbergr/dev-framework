> Tone: second person, friendly, example-driven; show exact commands.

# PowerShell Tooling Tests (Pester)

This folder contains **Pester** tests for dev‑framework scripts and modules.

> **Workspace mode:** In `${MODE} == se`, local docs/config linters may be skipped. **Pester still runs locally**; CI always enforces the full gates.

## Prerequisites

- **PowerShell 7+** (pwsh)
- **Pester** (ships with PS7; ensure a recent version)

## Run tests

```pwsh
# From repo root
Invoke-Pester tools/tests/pwsh -CI
```

- `-CI` enables CI‑friendly output and exit codes.
- Use `-Output Detailed` locally if you need verbose diagnostics.

## Test layout

- Put test files under this directory using the `*.Tests.ps1` naming convention.
- Place any helper modules/scripts under `tools/tests/pwsh/_helpers/` and import from tests.

## Writing tests — example

```pwsh
# tools/tests/pwsh/tooling.Tests.ps1
Describe 'tooling CLI' {
  It 'prints help' {
    $result = & ./scripts/tooling.ps1 --help
    $LASTEXITCODE | Should -Be 0
    $result | Should -Match 'Usage'
  }
}
```

## CI integration

- `.ai/workflows/code.yaml` runs:
  - `Invoke-Pester tools/tests/pwsh -CI`
- CI runs regardless of `${MODE}`.

## Troubleshooting

- Ensure scripts are executable and paths are relative to repo root.
- If Pester isn’t found, update PowerShell 7 to a recent build.
- Use `-Output Detailed` for more context on failures.
