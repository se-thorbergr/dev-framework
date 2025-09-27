> Tone: second person, friendly, example-driven; show exact commands.

# Bash Tooling Tests (bats)

This folder contains **bats** tests for dev‑framework shell scripts.

> **Workspace mode:** In `${MODE} == se`, local docs/config linters may be skipped. **bats tests still run locally**; CI always enforces the full gates.

## Prerequisites

- **bats** ≥ 1.10
- A POSIX‑compatible shell environment

### Install on Windows

- **Not available via winget.** Use one of the following:
  - **WSL (recommended):** follow the official bats-core guide and install inside your Linux distro.
  - **MSYS2:** install MSYS2, then use `pacman` per the bats-core guide.
  - **Manual (git clone):** install from source as documented by bats-core.

> See the upstream instructions: https://bats-core.readthedocs.io/en/stable/installation.html

## Run tests

```bash
# From repo root
bats -r tools/tests/bash
```

- `-r` runs tests recursively.

## Test layout

- Place test files here with the `*.bats` suffix.
- Put helpers under `tools/tests/bash/_helpers/` and `load` them in tests.

## Writing tests — example

```bash
#!/usr/bin/env bats

@test "tooling shim shows help" {
  run ./scripts/tooling.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ Usage ]]
}
```

## CI integration

- `.ai/workflows/code.yaml` runs:
  - `bats -r tools/tests/bash`
- CI runs regardless of `${MODE}`.

## Troubleshooting

- If `bats` isn’t found, ensure it’s on `PATH` (or use WSL).
- Make sure scripts are executable (`chmod +x`) and paths are relative to repo root.
