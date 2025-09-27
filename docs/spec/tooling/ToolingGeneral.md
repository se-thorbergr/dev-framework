> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# Tooling General Specification

_Last updated: 2025-09-27 - Owner: geho_

## 1. Scope

- Define the shared CLI contract, logging expectations, and operational guarantees that apply to every dev-framework tooling script (PowerShell and Bash).
- Individual tooling specs build on this document and must explicitly note any deviations.

## 1.1 References

- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`

## 2. Shared Responsibilities

- Provide equivalent behavior between PowerShell (`*.ps1`) and Bash (`*.sh`) implementations.
- Honor repository policies: CodingStyle (line endings, headers), Workflow (verification/diff capture), Environment (supported platforms, prereqs).
- Surface errors with actionable messages and non-zero exit codes.
- Respect **read-only** configs by policy (e.g., `*.mdk.ini`); never write these files.

## Terminology

- `ProjectName` – base name passed via `--name` or `-Name`; used for directories and .mdk files.
- `ProjectFolder` – the output directory resolved from CLI (`--output`) or defaults.
- Shared CLI switches are defined here; each tooling spec documents only its additions.

## 3. Mandatory CLI Options

| Purpose        | PowerShell          | Bash                | Notes                                                                        |
| -------------- | ------------------- | ------------------- | ---------------------------------------------------------------------------- |
| Dry run        | `-DryRun`           | `--dry-run`         | No side effects; print intended actions.                                     |
| Verbosity      | `-Verbose <level>`  | `--verbose <level>` | Levels: `quiet`, `info`, `debug` (default `info`).                           |
| Summary opt-in | `-Summary`          | `--summary`         | When supplied, print end-of-run summary (tasks executed, exit code, errors). |
| Help           | `-Help`, `-?`, `-h` | `--help`, `-h`      | Display usage and exit 0.                                                    |
| Version        | `-Version`          | `--version`         | Print tool name and version in a **stable, parseable** format; exit 0.       |
| CI output mode | `-Ci`               | `--ci`              | Format logs for CI/Actions friendly consumption.                             |

- Scripts may add tool-specific options, but the above switches must exist with consistent semantics.
- Summary output should be suppressed unless the flag is provided.

## 4. Logging & Output

- Respect verbosity level (`quiet` = minimal, `info` = default human-readable, `debug` = include command traces).
- `--summary` is off by default; only emit when explicitly requested.
- `--ci`/`-Ci` may imply `info` logs while emitting machine-readable annotations when useful.
- All tooling must end with exit code 0 on success, non-zero on failure (2 for unexpected errors recommended).

## 5. Shared Library Usage

- PowerShell tooling can import `tools/lib/DevFramework.Tooling.psm1` (planned) for argument parsing, logging, summary helpers.
- Bash tooling can `source tools/lib/tooling.sh` for the same.
- Libraries must expose functions for: parsing the shared CLI flags, writing logs respecting verbosity, emitting summaries, and formatting CI output.

## 6. Verification & Testing

- Each tool must include: `--dry-run` tests, `--verbose debug` tests, summary flag tests, and a `--version` output test (stable, parseable).
- CI should invoke shared verification scripts (e.g., `tools/verify-mdk2-config.sh`, `tools/Verify-Mdk2Config.ps1`) where applicable.

## 7. Normative Requirements

Use RFC 2119 terms. Keep each requirement atomic.

- Tooling **MUST** implement shared CLI switches with consistent semantics (`--dry-run`, verbosity, `--summary`, `--help`, `--version`, `--ci`).
- Tooling **MUST** respect verbosity levels and exit codes (0 success, non-zero failure; `2` recommended for unexpected errors).
- Tooling **SHOULD** share common libraries (`tools/lib/…`) for argument parsing, logging, and summaries when available.
- CI **MUST NOT** attempt SE game-dependent builds; CI runs format/lint only. Build is local-only.
- Verification **MUST** include dry-run, verbose debug, and summary flag tests.

## 8. Failure Modes & Recovery

| ID               | Symptom                  | Remedy                                                 |
| ---------------- | ------------------------ | ------------------------------------------------------ |
| missing-sdk      | `dotnet` 9.0.x not found | Install SDK 9.0.x; see Environment policy              |
| no-mdk-templates | MDK2 templates missing   | Install/repair MDK2 templates; re-run setup            |
| invalid-args     | CLI parse failure        | Show `--help`; return non-zero; do not perform actions |

## 9. Validation

- Print tool version(s) via `--version` (or equivalent) in logs.

- Lint/format steps succeed (PSScriptAnalyzer, ShellCheck, Prettier/markdownlint where applicable).
- Required files are present and in expected state.
- Summary output (when `--summary` is supplied) includes tasks executed, exit code, and errors.

## 10. Acceptance Criteria

- Preconditions are met; required tooling versions are available.
- Commands execute with expected exit codes and outputs for dry-run and debug modes.
- No write attempts to read-only config types (e.g., `*.mdk.ini`).
- CI logs show format/lint results; local build passes (where applicable).

## 11. Security & Permissions

- Use least privilege; no secrets in logs.
- Honor execution policies; prefer signed scripts where required.

## 12. Telemetry & Logging (optional)

- If telemetry is added, document events, destinations, and redaction rules; provide opt-in/opt-out.

## 13. Change Log

> **Policy:** On every spec edit, append a new row **at the bottom** with date, summary, and approver (chronological top→bottom).

| Date       | Change                                                                                                                                                                | Approved By |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-20 | Initial tooling general specification drafted                                                                                                                         | geho        |
| 2025-09-20 | Added terminology definitions for ProjectName/ProjectFolder                                                                                                           | geho        |
| 2025-09-26 | Align to template: added normative requirements, validation, acceptance criteria, failure modes, security/telemetry; added read-only config note and changelog policy | geho        |
| 2025-09-27 | Added `--version` to shared CLI contract (table, normative requirement) and to verification tests (stable, parseable output).                                         | geho        |
