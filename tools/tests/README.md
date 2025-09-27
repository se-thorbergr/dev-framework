> Tone: second person, friendly, example-driven; show exact commands.

# Tooling Tests — Overview (tools/tests)

This folder groups **tooling tests** for the dev‑framework. Tests live under language‑specific subfolders:

- `tools/tests/pwsh` — PowerShell tests (Pester)
- `tools/tests/bash` — Bash tests (bats)

> **Workspace mode**: In `${MODE} == se` (Space Engineers), local docs/config linters may be skipped. **Code and test suites still run locally**; CI always enforces the full gates.

---

## Run all tests

### PowerShell (Pester)

```pwsh
# From repo root
Invoke-Pester tools/tests/pwsh -CI
```

- Requires PowerShell 7+
- Uses the repo’s Pester configuration if present; otherwise, defaults to standard discovery

### Bash (bats)

```bash
# From repo root
bats -r tools/tests/bash
```

- Requires `bats` (>=1.10 recommended)
- `-r` runs tests recursively

---

## Adding tests

### PowerShell (Pester)

- Place test files under `tools/tests/pwsh/` with the `*.Tests.ps1` suffix.
- Example skeleton:

```pwsh
Describe 'tooling-shim' {
  It 'exits with 0 for --help' {
    $result = & ./scripts/tooling.ps1 --help
    $LASTEXITCODE | Should -Be 0
    $result | Should -Match 'Usage'
  }
}
```

### Bash (bats)

- Place test files under `tools/tests/bash/` with the `*.bats` suffix.
- Example skeleton:

```bash
#!/usr/bin/env bats

@test "tooling shim shows help" {
  run ./scripts/tooling.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ Usage ]]
}
```

---

## CI integration

- The `.ai/workflows/code.yaml` uses these exact paths:
  - `Invoke-Pester tools/tests/pwsh -CI`
  - `bats -r tools/tests/bash`
- CI runs these regardless of `${MODE}` to keep the tooling baseline enforced.

---

## Troubleshooting

- **Windows + bats**: bats is **not** available via winget. Use one of:
  - **WSL (recommended):** install per the official bats-core guide.
  - **MSYS2:** install via `pacman` as documented by bats-core.
  - **Manual (git clone):** follow the bats-core installation guide.

  See: https://bats-core.readthedocs.io/en/stable/installation.html

- **Path issues**: Ensure scripts are executable (`chmod +x`) and referenced with relative paths.
- **SE mode**: If you see messages about linters being skipped, that’s expected; tests still run.
