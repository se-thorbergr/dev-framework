# Format Helpers Specification

Last updated: 2025-10-14 - Owner: geho

## 1. Scope

- **Purpose:** Define the repository tooling that formats source files (C#, PowerShell, Bash) with consistent settings for humans, AI agents, and CI.
- **In scope:** `tools/format.ps1`, `tools/format.sh`, and thin staged wrappers that invoke the parameterised helpers.
- **Out of scope:** Linting (`tools/lint*`), config/spec formatting (handled by docs/config workflows), and project scaffolding.

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`
- CLI runtime library: `docs/spec/tooling/LibCli.md`
- Shared library requirements: `docs/spec/tooling/SharedLibrary.md`

## 2. Preconditions & Assumptions

- **Runtimes:** PowerShell 7.x+ and Bash (GNU Bash 5.0+ recommended) on Windows and Linux/WSL.
- **Tooling:** `dotnet` 9.0.x with `dotnet format`, `shfmt` 3.6+, PowerShell `PSScriptAnalyzer`, and Node.js 20.x+ with `npx prettier` available.
- **Git:** Calls require an initialized Git repository; staged wrappers assume `git` 2.39+.
- **Node packages:** Repository `package.json` MUST expose Prettier; helpers reuse `npx prettier` (no global install required).
- **Mode detection:** `${MODE}` comes from `.ai/policies/core.yaml`; helpers must respect SE mode skips when invoked with `--ci`.

## 3. Shared Responsibilities

- Maintain **PowerShell/Bash parity** for features, options, and exit codes.
- Run only on files that exist inside the repo boundary defined by `.gitignore` and policy.
- Respect policy rules for read-only files (no writes to `*.mdk.ini`, `.ai/**`).
- Emit ASCII-only console output and summaries.

## 4. CLI Contract

| Option                   | Alias | Type        | Default                                    | Description                                                                   |
| ------------------------ | ----- | ----------- | ------------------------------------------ | ----------------------------------------------------------------------------- |
| `--help`                 | `-h`  | switch      | `false`                                    | Print usage and exit successfully.                                            |
| `--version`              | `-V`  | switch      | `false`                                    | Emit tool version (`format-helpers/1.0.0`) and API schema version.            |
| `--files <path...>`      |       | multi-value | `()`                                       | Explicit list of files/globs. If empty, staged wrappers provide staged files. |
| `--dry-run`              |       | switch      | `false`                                    | Discover targets and report actions without modifying files.                  |
| `--summary`              |       | switch      | `false`                                    | Emit CLI summary (text unless `--summary-format json`).                       |
| `--summary-format <text` |       | single      | `text`                                     | Override summary format (text or json). Requires `--summary`.                 |
| `--summary-json <path>`  |       | single      | `null`                                     | Write JSON summary to the provided path (schema v1).                          |
| `--ci`                   |       | switch      | `false`                                    | Hint that invocation runs inside CI. Forces SE-mode skips to match workflows. |
| `--shfmt-flags "..."`    |       | single      | repo default                               | Optional override for shfmt arguments.                                        |
| `--prettier-args "..."`  |       | single      | repo default                               | Extra flags appended to `npx prettier --write` for Markdown.                  |
| `--dotnet-args "..."`    |       | single      | repo default                               | Optional override appended to `dotnet format`.                                |
| `--pssa-settings <path>` |       | single      | `tools/pssa/PSScriptAnalyzerSettings.psd1` | Override settings file for PowerShell formatter.                              |

- **Exit codes:** `0` success; `1` validation failure (missing tool, unreadable file, unsupported extension); `2` unexpected runtime error; `3` dry-run detected pending writes.
- **Help & version:** Output MUST be stable and parseable by tests (`--version` includes `api_version=1`).
- **Examples:**
  - PowerShell: `pwsh tools/format.ps1 --files source/Game.sln --summary`
  - Bash: `bash tools/format.sh --files $(git diff --name-only -- '*.ps1' '*.sh')`

## 5. Workflow

1. **Initialize CLI:** parse flags via `LibCli`, set dry-run and summary behavior.
2. **Resolve targets:** gather explicit files or use staged wrapper input; deduplicate paths; ignore non-existent entries.
3. **Classify by language:** group files into C# (`*.cs`), PowerShell (`*.ps1`, `*.psm1`, `*.psd1`), Bash (`*.sh`), and Markdown (`*.md`).
4. **Pre-flight checks:** verify required external tools exist; respect `${MODE}` (skip formatters in SE mode when `--ci`).
5. **Execute formatters:**
   - For C#: run `dotnet format --no-restore --include ...` in batches.
   - For PowerShell: pipe each file through `Invoke-Formatter` with repo settings.
   - For Bash: run `shfmt` with repo flags.
   - For Markdown: run `npx prettier --write` with optional extra arguments.
6. **Dry-run handling:** when `--dry-run`, log intended commands, collect summary entries, and return exit code `3`.
7. **Post-actions:** emit summaries, report missing tools, and surface aggregated errors while preserving ASCII output.

## 6. Configuration Handling

- No persistent configuration files are read or written.
- Formatter settings are supplied via command-line flags and repo-owned files (`tools/pssa/PSScriptAnalyzerSettings.psd1` and shellcheck rc is ignored here).
- Environment variable overrides:
  - `DEVFW_MODE` influences `${MODE}` handling indirectly through LibConfig/ToolingGeneral.
- Helpers MUST NOT create or mutate INI/JSON/YAML configuration.

## 7. Normative Requirements

- The helpers **MUST** maintain feature parity between PowerShell and Bash implementations.
- The helpers **MUST** respect `--dry-run` by refraining from modifying files and by exiting with code `3` if changes would occur.
- The helpers **MUST** format Markdown inputs with Prettier using repo defaults when the tool is available (or skip with a clear error when missing).
- The helpers **MUST** restrict formatting operations to files explicitly provided (no globbing beyond caller intent).
- The helpers **MUST NOT** write to files outside the repo boundary or to read-only policy paths (`*.mdk.ini`, `.ai/**`).
- The helpers **SHOULD** short-circuit when no supported files remain after filtering.
- The helpers **MAY** emit informational logs (`info`) and debugging details (`debug`) via LibCli logging.

## 8. Outputs

- Mutated files: specified C#, PowerShell, Bash, and Markdown files (unless `--dry-run` or SE mode skip).
- Console output: ASCII logs of actions, skipped files, and summary lines.
- Optional JSON summary file when `--summary-json` is supplied.

## 9. Failure Modes & Recovery

| ID      | Symptom                                  | Remedy                                                                          |
| ------- | ---------------------------------------- | ------------------------------------------------------------------------------- |
| FMT-001 | `dotnet` command not found               | Install .NET SDK 9.x or adjust PATH; rerun.                                     |
| FMT-002 | `shfmt` missing                          | Install shfmt 3.6+ on the host; CI will flag missing dependency.                |
| FMT-003 | Prettier unavailable (`npx` fails)       | Install Node.js 20.x+, ensure `npx prettier` resolves, then rerun.              |
| FMT-004 | PowerShell PSSA module missing           | Run `pwsh -Command "Install-Module PSScriptAnalyzer"` (per Environment policy). |
| FMT-005 | Unsupported file extension provided      | Remove the path or extend helper capabilities; tool exits with code `1`.        |
| FMT-006 | Formatter writes fail due to permissions | Ensure files are writable or adjust ACLs; rerun once resolved.                  |

## 10. Validation & Testing

- Provide Bats tests (`tools/tests/bash`) covering dry-run, missing tool handling (mocked), and actual formatting on fixture files.
- Provide Pester tests (`tools/tests/pwsh`) verifying parity with Bats cases.
- Tests MUST assert stable `--help`/`--version` output and exit codes for success, dry-run, and failure modes.
- CI MUST run both test suites when helper scripts change.

## 11. Acceptance Criteria

- All preconditions satisfied (tools installed or SE-mode skip engaged).
- Formatting commands succeed with expected exit codes and produce deterministic changes.
- Dry-run reports operations without modifying files.
- Tests (Pester/Bats) pass locally or in CI for affected scripts.

## 12. Security & Permissions

- Helpers MUST execute only local binaries; no network calls or credential access.
- Avoid echoing secrets or tokens; logs limited to file paths and tool names.
- Honor user filesystem permissions; do not escalate privileges.

## 13. Telemetry & Logging (optional)

- Not applicable – tool writes logs to stdout/stderr only and collects optional summaries.

## 14. Open Questions / Future Enhancements

- Consider adding formatter detection for additional languages (e.g., JSON/YAML) if workflows expand.
- Evaluate caching formatted paths to reduce redundant executions in large repos.

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                        | Approved By |
| ---------- | ------------------------------------------------------------- | ----------- |
| 2025-10-14 | Initial specification draft.                                  | geho        |
| 2025-10-14 | Added Markdown formatting coverage and Prettier requirements. | geho        |
