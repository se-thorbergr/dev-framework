> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# LibCli Specification

_Last updated: 2025-09-28 - Owner: geho_

## 1. Scope

- **Purpose:** `LibCli` is the shared **CLI runtime library** for repository tools. It provides **argument parsing**, **logging** (quiet/info/debug), **summary aggregation** (`--summary`), **stable help/version emitters**, and **CI annotation helpers**. It is **implementation-agnostic** with **PowerShell** and **Bash** parity.
- **In scope:** common flags handling, parseable `--help/--version`, structured logging, summary collection/emit, CI annotations formatting. The library **MUST NOT** terminate the process (no `exit`).
- **Out of scope:** domain logic (config merges, MDK2 validation, filesystem operations). These belong to `LibConfig`, `LibMDK2`, and `LibFs` respectively.

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`

## 2. Preconditions & Assumptions

- **Runtimes:** PowerShell **7.x** and Bash on Windows/Linux.
- **Shell environment:** ASCII-only output on default code page/locale; UTF-8 input accepted where applicable.
- **CI detection:** MAY detect CI context via well-known envs (e.g., `GITHUB_ACTIONS=true`) to format annotations.
- **No external tools required** beyond the shell runtime.

## 3. Shared Responsibilities

- **Platform support:** Windows and Linux (PowerShell 7.x; Bash).
- **Parity:** Feature parity between `tools/lib/cli.ps1` and `tools/lib/cli.sh` is REQUIRED.
- **Policy compliance:** Respect read-only policy and logging redaction rules defined in repo policies. Do not write files.

## 4. API Contract

> This section defines the **library API** (not a standalone CLI). Function names are illustrative; concrete names MAY vary if parity and semantics are preserved.

### 4.1 PowerShell (tools/lib/cli.ps1)

| Function          | Parameters                                                                                 | Returns                                          | Notes                                                        |
| ----------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------ | ------------------------------------------------------------ |
| `Initialize-Cli`  | `-Args string[]`                                                                           | object `{ Flags; UnknownArgs; Logger; Summary }` | Parses common flags; sets defaults. No writes; no exit.      |
| `Write-Log`       | `-Level ('quiet'\|'info'\|'debug') -Message string`                                        | `void`                                           | Level-aware logging; MUST be ASCII-only.                     |
| `Add-SummaryItem` | `-Kind string -Message string -Data object?`                                               | `void`                                           | Collects summary entries for deferred emit.                  |
| `Emit-Summary`    | _(none)_                                                                                   | `void`                                           | Prints aggregated summary when requested.                    |
| `Emit-Help`       | _(none or context)_                                                                        | string                                           | Returns stable, parseable help text; caller prints.          |
| `Emit-Version`    | `-Version string -Commit string?`                                                          | string                                           | Returns stable version line(s); caller prints.               |
| `Annotate-CI`     | `-Level ('notice'\|'warning'\|'error') -Message string -File string? -Line int? -Col int?` | `void`                                           | Formats CI annotations when CI is detected; no-op otherwise. |
| `Make-Error`      | `-Code int -Message string -Area string?`                                                  | object `{ Code; Message; Area }`                 | Structured error object; library does not exit.              |

### 4.2 Bash (tools/lib/cli.sh)

> **Notation:** Space-separated positional arguments; callers MUST quote each argument. Do not use comma-separated pseudo-lists.

| Function       | Parameters (positional)                 | Returns                                                         | Notes                                     |
| -------------- | --------------------------------------- | --------------------------------------------------------------- | ----------------------------------------- |
| `cli_init`     | `$@`                                    | associative array: `flags`, `unknown_args`, `logger`, `summary` | Parse common flags; set defaults.         |
| `log`          | `<level> <message>`                     | none                                                            | Level-aware logging; ASCII-only.          |
| `summary_add`  | `<kind> <message> [data]`               | none                                                            | Collects summary entries.                 |
| `summary_emit` | _(none)_                                | none                                                            | Emits aggregated summary.                 |
| `help_emit`    | _(none or context)_                     | stdout string                                                   | Stable, parseable help text.              |
| `version_emit` | `<version> [commit]`                    | stdout string                                                   | Stable version line(s).                   |
| `ci_annotate`  | `<level> <message> [file] [line] [col]` | none                                                            | Formats CI annotations if CI is detected. |
| `error_make`   | `<code> <message> [area]`               | printf JSON-ish or delimited                                    | Structured error; caller decides exit.    |

**Quoting rule:** Call like `log "info" "starting..."` and `ci_annotate "warning" "msg" "$file" 12 3`. Omit optionals by leaving them out.

### 4.3 Common flags handled

The parser MUST recognize and normalize these flags (forwarding unknown tool-specific args to callers):

| Flag                    | Semantics                                                                 |
| ----------------------- | ------------------------------------------------------------------------- |
| `--help`                | Produce stable, parseable help text via `Emit-Help`/`help_emit`.          |
| `--version`             | Produce stable, parseable version text via `Emit-Version`/`version_emit`. |
| `--dry-run`             | Force **no side effects** mode; libraries MUST honor.                     |
| `--summary`             | Collect and print a summary at end via `Emit-Summary`/`summary_emit`.     |
| `--verbose` / `--debug` | Increase log verbosity (info→debug).                                      |
| `--ci`                  | Force CI formatting regardless of env autodetect.                         |

**Alias rule:** `--debug` **MUST** be treated as a shorthand for `--verbose debug` in both shells.

## 5. Workflow

Typical consumer usage pattern:

1. Call `Initialize-Cli`/`cli_init` with raw args; receive normalized flags + logger + summary handle.
2. Use `Write-Log`/`log` for user-visible messages at appropriate levels; avoid secrets.
3. If `--dry-run` is set, ensure downstream actions are simulated only; record via `Add-SummaryItem`.
4. When `--summary` is set, call `Emit-Summary`/`summary_emit` as the final step.
5. For `--help`/`--version`, the **tool** prints the strings returned by the lib and exits with code `0`.

## 6. Configuration Handling

- `LibCli` has **no persistent config files**.
- Behavior MAY be influenced by environment (e.g., CI detection); any such env keys MUST be documented by the caller.
- Logging level derives from flags; callers MAY override defaults before first log.

## 7. Normative Requirements

- The library **MUST NOT** call `exit`/`throw` to terminate the process.
- All outputs **MUST** be ASCII-only and deterministic given the same inputs.
- `--help`/`--version` outputs **MUST** be **stable and parseable** for automated tests.
- CI annotations **MUST** conform to the detected CI format when in CI; otherwise they **MUST** degrade gracefully to plain logs.
- PowerShell and Bash implementations **MUST** maintain behavior parity.
- The parser **MUST** accept `--debug` as an alias for `--verbose debug`.

## 8. Outputs

- Console output routed via logging functions respecting verbosity.
- Optional summary block emitted only when `--summary` is present.
- CI annotations emitted only when `--ci` is set or CI is detected.

## 9. Failure Modes & Recovery

| ID      | Symptom                            | Remedy                                                    |
| ------- | ---------------------------------- | --------------------------------------------------------- |
| CLI-001 | Unknown flag parsing ambiguity     | Return unknown args to caller; do not fail; log at debug. |
| CLI-002 | Non-ASCII message emitted          | Normalize or replace characters before emit; fail tests.  |
| CLI-003 | CI annotation requested outside CI | Log notice; print plain message without annotation.       |

## 10. Validation

- Unit tests for parsing, logging levels, summary aggregation, help/version stability.
- Integration tests in consumer tools confirming `--dry-run` produces **no side effects**.
- PS (Pester) and Bash (bats) parity tests producing identical expected outputs.

## 11. Acceptance Criteria

- Public functions present with documented parameters and return shapes.
- Help/version outputs match golden snapshots across shells.
- Summary emission occurs only with `--summary` and contains recorded items.
- No direct process termination; callers control exit codes.

## 12. Security & Permissions

- Do not log secrets or tokens; redact values when patterns resemble secrets.
- Follow least-privilege: no file writes, no process termination.

## 13. Telemetry & Logging (optional)

- Minimal telemetry: counts of warnings/errors MAY be surfaced to callers via summary or return object.
- If telemetry is added later, it MUST be opt-in.

## 14. Open Questions / Future Enhancements

- JSON summary schema vs. plain text: should `Emit-Summary` provide structured (machine-readable) output?
- CI providers: standardize adapter interface to add new providers beyond GitHub Actions?
- Version reporting: include library api_version in `Emit-Version` output?

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                                                                                                        | Approved By |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-27 | Initial LibCli spec under common template; Section 4 renamed to **API contract**; added PS/Bash parity API tables and normative requirements. | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.                                | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                                                         | geho        |
| 2025-09-28 | Standardized verbosity: treat `--debug` as an alias for `--verbose debug`; documented in Sections 4 and 7.                                    | geho        |
| 2025-09-28 | Bash API table: switch to positional argument notation and add quoting rule.                                                                  | geho        |
