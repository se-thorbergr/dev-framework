# Lint Helpers Specification

Last updated: 2025-10-14 - Owner: geho

## 1. Scope

- **Purpose:** Define the linting helpers that evaluate repository scripts and code for policy compliance (`tools/lint.ps1`, `tools/lint.sh`) plus staged wrappers.
- **In scope:** PowerShell ScriptAnalyzer, ShellCheck integration, optional dotnet build warnings, and summary reporting for lint operations.
- **Out of scope:** Formatting (`tools/format*`), docs/config linting, and project-specific analyzers.

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`
- CLI runtime library: `docs/spec/tooling/LibCli.md`
- Format helpers spec: `docs/spec/tooling/FormatHelpers.md`

## 2. Preconditions & Assumptions

- **Runtimes:** PowerShell 7.x+ and Bash (GNU Bash 5.0+) on Windows and Linux/WSL.
- **Tooling:** PowerShell `PSScriptAnalyzer` with repo settings, `shellcheck` (respecting `tools/shell/shellcheckrc`), `dotnet` 9.0.x for optional C# linting, and Node.js 20.x+ with `npx markdownlint` available.
- **Git:** Staged wrappers rely on `git` 2.39+ for diff discovery.
- **Mode detection:** `${MODE}` from `.ai/policies/core.yaml` influences whether linters run in SE mode when `--ci` is set.
- **Node packages:** Repository `package.json` MUST expose `markdownlint-cli`; helpers reuse `npx markdownlint` without global installs.
- **Network:** Tools operate offline; no package installation during execution.

## 3. Shared Responsibilities

- Maintain **PowerShell/Bash parity** in flags, exit codes, and summary payloads.
- Enforce ASCII-only output and avoid leaking sensitive data.
- Skip or warn gracefully when external linters are unavailable, matching workflow behaviour.
- Respect policy-protected files and run only against explicit targets.

## 4. CLI Contract

| Option                      | Alias | Type        | Default                                    | Description                                                                |
| --------------------------- | ----- | ----------- | ------------------------------------------ | -------------------------------------------------------------------------- |
| `--help`                    | `-h`  | switch      | `false`                                    | Print usage and exit successfully.                                         |
| `--version`                 | `-V`  | switch      | `false`                                    | Emit tool version (`lint-helpers/1.0.0`) with API schema version.          |
| `--files <path...>`         |       | multi-value | `()`                                       | Paths/globs to lint. Missing paths ignored with warning.                   |
| `--dry-run`                 |       | switch      | `false`                                    | Discover targets and report commands without executing linters.            |
| `--summary`                 |       | switch      | `false`                                    | Emit summary per LibCli schema.                                            |
| `--summary-format <text`    |       | single      | `text`                                     | Change summary format (text or json). Requires `--summary`.                |
| `--summary-json <path>`     |       | single      | `null`                                     | Write JSON summary to given path.                                          |
| `--ci`                      |       | switch      | `false`                                    | Signal CI usage; enforces SE-mode skips and forces non-interactive output. |
| `--shellcheck-flags "..."`  |       | single      | repo default                               | Override additional ShellCheck flags.                                      |
| `--markdownlint-args "..."` |       | single      | repo default                               | Extra flags appended to `npx markdownlint`.                                |
| `--pssa-settings <path>`    |       | single      | `tools/pssa/PSScriptAnalyzerSettings.psd1` | Override ScriptAnalyzer configuration.                                     |
| `--dotnet-build`            |       | switch      | `false`                                    | Run `dotnet build -warnaserror` when C# files are targeted.                |
| `--dotnet-args "..."`       |       | single      | repo default                               | Extra flags appended to `dotnet build` when enabled.                       |
| `--fail-on-warn`            |       | switch      | `false`                                    | Treat ShellCheck/PSSA warnings as errors (exit code `1`).                  |

- **Exit codes:** `0` success or skipped (no targets); `1` lint failures; `2` unexpected runtime error; `3` dry-run with pending lint operations (no execution); `4` missing required tool when not allowed to skip.
- **Help & version:** Outputs MUST be stable and parseable (`api_version=1`).
- **Examples:**
  - PowerShell: `pwsh tools/lint.ps1 --files tools/*.ps1 --fail-on-warn --summary`
  - Bash: `bash tools/lint.sh --files $(git diff --name-only -- '*.sh') --shellcheck-flags "-S style"`

## 5. Workflow

1. **Initialize CLI:** parse options via LibCli; propagate `--ci`, `--dry-run`, and summary flags.
2. **Resolve targets:** collect provided files, deduplicate, filter non-existent paths with warnings.
3. **Classify by language:** map to PowerShell, Bash, Markdown, and C# buckets; ignore unsupported extensions.
4. **Pre-flight checks:** confirm linters exist; when `${MODE} == se` and `--ci`, skip with informational summary.
5. **Execute linters:**
   - PowerShell: run `Invoke-ScriptAnalyzer` using repo settings with optional `--fix:$false` (analysis only).
   - Bash: run `shellcheck` using repo rc plus overrides.
   - Markdown: run `npx markdownlint --config .markdownlint.jsonc ...`; helpers MAY follow up with `npx @mermaid-js/mermaid-cli` checks when available to validate diagrams.
   - C# (optional): run `dotnet build -warnaserror` when `--dotnet-build` and C# files detected (honour extra args).
   - NPM scripts (`npm run lint`, `npm run lint:staged`, `npm run lint:docs`) MUST remain thin wrappers around the helper CLI to keep behaviour consistent between humans, CI, and AI agents.
6. **Aggregate results:** capture warnings/errors per tool; treat `--fail-on-warn` as elevated severity.
7. **Dry-run:** if `--dry-run`, log intended commands and exit `3` without running the tools.
8. **Summaries:** report successes/failures per language and emit JSON when requested.

## 6. Configuration Handling

- Linters rely on repo-managed settings files (`tools/pssa/PSScriptAnalyzerSettings.psd1`, `tools/shell/shellcheckrc`).
- Tools MUST NOT modify configuration files or create new config artifacts.
- Environment variables (e.g., `DEVFW_MODE`) indirectly influence behaviour via shared libraries.
- No persistence of lint state or baselines.

## 7. Normative Requirements

- The helpers **MUST** detect missing linters and report actionable guidance without crashing.
- The helpers **MUST** exit with code `1` when lint findings reach error severity or when `--fail-on-warn` is set and warnings occur.
- The helpers **MUST** lint Markdown inputs with `markdownlint` and SHOULD validate Mermaid diagrams via `@mermaid-js/mermaid-cli` when it is available (otherwise log that validation was skipped).
- The helpers **MUST NOT** modify source files; linting is read-only.
- The helpers **SHOULD** honour `${MODE}`: skip linters in SE mode when policy forbids local execution, while CI enforces warnings.
- The helpers **MAY** allow opt-in dotnet build checks when `--dotnet-build` is set.

## 8. Outputs

- Console logs describing executed linters, skipped checks, and summaries.
- Optional JSON summary file capturing per-tool result counts.
- No file mutations performed.

## 9. Failure Modes & Recovery

| ID      | Symptom                                                | Remedy                                                              |
| ------- | ------------------------------------------------------ | ------------------------------------------------------------------- |
| LNT-001 | `shellcheck` not installed                             | Install ShellCheck per Environment policy; rerun.                   |
| LNT-002 | ScriptAnalyzer module missing                          | Install module (`Install-Module PSScriptAnalyzer`); rerun.          |
| LNT-003 | `npx markdownlint` unavailable                         | Install Node.js 20.x+, ensure repo dependencies are present; rerun. |
| LNT-004 | Dotnet command missing when `--dotnet-build` requested | Install .NET SDK 9.x or omit the flag.                              |
| LNT-005 | Mermaid CLI missing (optional validation skipped)      | Install `@mermaid-js/mermaid-cli`; rerun to validate diagrams.      |
| LNT-006 | Unsupported file extension passed                      | Remove or ignore the file; tool exits with `1`.                     |
| LNT-007 | Linter produces warnings/errors                        | Fix the reported issues or suppress via repo policy; rerun.         |

## 10. Validation & Testing

- Provide parallel Pester and Bats tests covering success, warning, error, missing tool, and dry-run scenarios across PowerShell, Bash, Markdown, and optional C# cases.
- Tests MUST assert `--help`/`--version` stability and correct exit codes for each scenario.
- CI MUST run both test suites when lint helpers change.
- Mocks/stubs may simulate missing binaries to assert failure handling.

## 11. Acceptance Criteria

- Required linters detected or skipped per policy with clear messaging.
- Lint helpers exit with expected codes and summarise results accurately.
- Dry-run produces no side effects and exits with code `3`.
- All tests pass locally (or in CI) for affected scripts.

## 12. Security & Permissions

- Helpers MUST execute only on provided files; no directory traversal beyond inputs.
- No secrets or tokens may be printed; logs limited to file paths and diagnostic text.
- No network calls or privilege escalation.

## 13. Telemetry & Logging (optional)

- Not applicable – output limited to stdout/stderr and optional summaries.

## 14. Open Questions / Future Enhancements

- Explore aggregating linter results into SARIF for richer CI reporting.
- Consider supporting additional linters (e.g., `eslint` when JS tooling appears).

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                         | Approved By |
| ---------- | -------------------------------------------------------------- | ----------- |
| 2025-10-14 | Initial specification draft.                                   | geho        |
| 2025-10-14 | Added Markdown linting support and Node tooling prerequisites. | geho        |
| 2025-10-14 | Documented optional Mermaid CLI validation and npm script expectations. | geho        |
