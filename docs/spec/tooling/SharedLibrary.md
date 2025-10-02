> Tone: normative (MUST/SHOULD/MAY); ASCII-only punctuation.

# Shared Tooling Library Specification

Last updated: 2025-10-02 - Owner: geho

## 1. Scope

- Provide reusable helpers for dev-framework tooling so Bash/PowerShell scripts share consistent behavior defined in `ToolingGeneral.md`.
- Cover logging, CLI parsing, summary emission, CI formatting, and utility helpers (e.g., config validation hooks).
- Out of scope: tool-specific logic (setup, scaffolding) which will consume this library.

## 1.1 References

- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Tooling Specs Index: `docs/spec/tooling/README.md`
- Shared Libraries Overview: `docs/spec/tooling/SharedLibrary.md`
- Domain Libs: `docs/spec/tooling/LibCli.md`, `docs/spec/tooling/LibConfig.md`, `docs/spec/tooling/LibFs.md`, `docs/spec/tooling/LibMDK2.md`, `docs/spec/tooling/LibDotnetProj.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)

## 2. Preconditions & Assumptions

- PowerShell **7.x** and Bash available on supported platforms (Windows, Linux/WSL).
- UTF-8 console configured:
  - PowerShell 7+: `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $OutputEncoding = [System.Text.UTF8Encoding]::new($false)`
  - Bash: `export LANG=C.UTF-8; export LC_ALL=C.UTF-8`
- Consumers follow the staged-files workflow; library itself performs no direct writes or exits.

## 3. Shared Responsibilities

- Deliver two implementations with equivalent behavior:
  - PowerShell helper: `tools/lib/cli.ps1` (can be wrapped by a module if desired).
  - Bash helper: `tools/lib/cli.sh` (sourced via `. tools/lib/cli.sh`).
- Support Windows (PowerShell 7.x / Git Bash) and Linux shells.
- Expose only documented functions; treat everything else as internal.
- Honor repository policies (CodingStyle, Workflow, Environment) and rely on `ToolingGeneral.md` for CLI semantics.

## 4. API Contract

> This document is an **overview & index**. It does not define concrete APIs; those are specified in the **per-library specs** below. Use this section as a quick map.
>
> **Non-normative:** This section maps the library family. It does not define function signatures or return shapes. For concrete, testable APIs, see `docs/spec/tooling/LibCli.md`, `docs/spec/tooling/LibConfig.md`, `docs/spec/tooling/LibFs.md`, `docs/spec/tooling/LibMDK2.md`, and `docs/spec/tooling/LibDotnetProj.md`.

### 4.1 Library family (responsibilities & file locations)

| Library           | Responsibility (summary)                                                                                                                          | PowerShell file            | Bash file                 |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- | ------------------------- |
| **LibCli**        | Common CLI runtime: arg parsing, logging (quiet/info/debug), `--summary` aggregation, stable `--help/--version`, CI annotations. No domain logic. | `tools/lib/cli.ps1`        | `tools/lib/cli.sh`        |
| **LibConfig**     | Discover/read/merge INI/JSON, env overlays, schema hooks. Render minimal INI diffs for `.local`. **No writes** to protected bases.                | `tools/lib/config.ps1`     | `tools/lib/config.sh`     |
| **LibFs**         | **Planning-only** filesystem helpers (mkdir/write/copy/move) with deterministic plans and ASCII renders.                                          | `tools/lib/fs.ps1`         | `tools/lib/fs.sh`         |
| **LibMDK2**       | MDK2-specific validators (template/version presence, config shape, layout checks). **Pure validation**, no writes.                                | `tools/lib/mdk2.ps1`       | `tools/lib/mdk2.sh`       |
| **LibDotnetProj** | MSBuild project helpers: read `.csproj`/`.shproj`/`.projitems` and **plan minimal XML edits** (imports/items/properties). **Planning only**.      | `tools/lib/dotnetproj.ps1` | `tools/lib/dotnetproj.sh` |

### 4.2 Where to find the detailed specs

- `docs/spec/tooling/LibCli.md` — CLI runtime (args/logging/summary/CI)
- `docs/spec/tooling/LibConfig.md` — config sources/precedence, read-only rules, diff rendering
- `docs/spec/tooling/LibFs.md` — planning helpers & plan rendering
- `docs/spec/tooling/LibMDK2.md` — MDK2 validators & diagnostics
- `docs/spec/tooling/LibDotnetProj.md` — MSBuild XML reader & edit planner

> Code examples and full API tables have moved to the respective `Lib*.md` files.

## 5. Workflow

1. Tool script imports/sources the library.
2. Call `Initialize-Cli` / `initialize_cli` with argv and tool-specific option definitions.
3. Use `Write-Log` / `write_log` for output; the logger returned from init handles levels and ASCII-only formatting.
4. Execute tool logic, calling `Write-Log` and `Add-SummaryItem` / `add_summary_item` for major steps.
5. On exit, call `Emit-Summary` / `emit_summary` if the summary flag is present, passing exit code and any captured errors. Accept `--summary-format json` and `--summary-json <path>` to opt into structured outputs while preserving plain-text defaults.
6. Before persisting staged outputs, request `Normalize-TextFile` / `normalize_text_file` to enforce UTF-8 + LF + terminal newline rules on any buffers the tool prepares for policy-managed files.
7. When interactive progress feedback is needed, call `Start-Spinner` / `start_spinner` and `Stop-Spinner` / `stop_spinner`; these helpers MUST no-op automatically in CI mode or non-TTY contexts.

- Libraries must not exit the process; return status to the caller.

## 6. Configuration Handling

- No direct file writes. Helpers may consume `se-config.ini` / `se-config.local.ini` for validation via `Validate-Config` / `validate_config`.
- `Validate-Config` is a **generic** hook that delegates to a domain library (e.g., `mdk2.Verify-Mdk2Config`). The CLI library must not house MDK2-specific rules.
- Library-level defaults (e.g., default verbosity `info`) should be defined centrally and overridable through parsed options.
- Text normalization helpers operate only on buffers provided by callers; consumers remain responsible for staging and persisting any resulting content.

## 7. Normative Requirements

- The libraries **MUST NOT** write files or exit the process; callers control side effects and exit codes.
- All emitted text **MUST** be ASCII-only and deterministic across shells.
- PowerShell and Bash implementations **MUST** maintain behavior parity.
- Both shells **MUST** expose `Normalize-TextFile` / `normalize_text_file` helpers that enforce UTF-8 encoding, LF line endings, and a terminal newline when preparing policy-managed file content.
- Both shells **MUST** expose `Start-Spinner` / `start_spinner` and `Stop-Spinner` / `stop_spinner` helpers with identical behavior, automatically disabling output when `--ci` is set or STDOUT is not a TTY.
- JSON summary emission (`--summary-format json`, `--summary-json <path>`) **MUST** produce identical schema v1 payloads across shells with deterministic key ordering and ASCII-only content.
- `--help`/`--version` outputs **MUST** be stable and parseable for tests.
- CI annotations **MUST** degrade gracefully when CI is not detected or `--ci` not set.

## 8. Outputs

- No filesystem output; libraries only write to STDOUT/STDERR via the logging helpers.
- All log lines must be prefixed with level tags (`[info]`, `[debug]`, etc.)
  and respect `--ci` formatting rules.
- Spinner frames MUST remain ASCII-only, avoid overwriting durable log output, and stop cleanly when errors occur.
- JSON summaries MUST emit to STDOUT (default) or the path passed to `--summary-json`; the file write remains the caller’s responsibility.

## 9. Failure Modes & Recovery

- Logging helpers must never throw/fail; they downgrade to STDERR prints if misconfigured.
- Parsing helpers return error codes/structures for unknown options so callers can display help and exit 2.
- `Validate-Config` should bubble up the verifier script’s exit code and message without modification.

## 10. Validation

- Print tool version(s) via `--version` in logs.

- Unit tests: validate argument parsing (with/without extra options), logging prefixes, summary generation, CI annotation formatting.
- Integration tests: create sample scripts (one PS, one Bash) that consume the library and exercise dry-run + summary + CI flows.
- CI should run both unit and integration tests on Windows and Linux runners.

## 11. Acceptance Criteria

- Unit and integration tests pass on Windows and Linux runners.
- `--help` and `--version` outputs are stable and parseable in tests.
- `--summary` is off by default; emitted only when the flag is provided.
- `--dry-run` produces no side effects; commands are echoed only.
- Library performs no direct file writes and does not call exit; returns status to callers.
- All emitted text uses ASCII-only punctuation per policy.
- Parity tests cover `Normalize-TextFile` / `normalize_text_file` for ASCII-only output, idempotent newline handling, and error propagation.
- Parity tests cover `Start-Spinner` / `start_spinner` + `Stop-Spinner` / `stop_spinner`, including CI/non-TTY fallback behavior and nested usage.
- JSON summary tests cover happy path, error aggregation, CI metadata, and parity between PowerShell and Bash.
- Logs include version prints via `--version` at startup.
- Respects staged-files scope and other repository policies.

## 12. Security & Permissions

- Do not write to policy-protected files (e.g., `*.mdk.ini`); consumers must persist diffs to `.local` files.
- Never exit the process from the library; return status and let callers decide.
- Spinner helpers MUST guard against lingering background tasks and ensure cleanup on exceptions or cancellations.
- Sanitize/escape CI annotations to avoid control chars or non-ASCII where required by policy.

## 13. Telemetry & Logging (optional)

- If structured summaries are enabled, emit JSON to STDOUT/CI artifact with ASCII-only punctuation.
- JSON summaries MUST include `schema: "v1"`, retain deterministic key ordering, and add CI metadata fields when `--ci` is active.
- Do not transmit network telemetry; all outputs remain local to CI logs/artifacts.

## 14. Open Questions / Future Enhancements

- Consider adding localization hooks if non-English output is required later.

Resolved: text I/O normalization requirements now live in Sections 5, 6, 7, and 11.
Resolved: spinner helper requirements now live in Sections 5, 7, 8, 11, and 12.
Resolved: JSON summary requirements now live in Sections 5, 7, 8, 11, and 13.

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                                                                                                                                                   | Approved By |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-20 | Initial shared tooling library spec draft                                                                                                                                                | geho        |
| 2025-09-27 | Align with template: added 1.1 References; US spelling + ASCII; include `--version` in shared flags; renumbered sections; added validation note; aligned helper names to cli.ps1/cli.sh. | geho        |
| 2025-09-27 | Added Acceptance Criteria section; expanded UTF-8 console commands for PS7 and Bash.                                                                                                     | geho        |
| 2025-09-27 | Documented split into domain libraries (cli vs mdk2/config/fs), renamed API to Validate-Config/validate_config, and added stub examples.                                                 | geho        |
| 2025-09-27 | Refactor to **overview & index**; added library family table and links to per-library specs; included **LibDotnetProj**.                                                                 | geho        |
| 2025-09-28 | Aligned to 15-section template; preserved section order; set Section 4 to **API contract** overview; moved detailed APIs to per-library specs.                                           | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.                                                                           | geho        |
| 2025-09-28 | Clarified Section 4 as non-normative; retitled to "API contract (overview, non-normative)" and added explicit pointer to Lib\*.md for function signatures.                               | geho        |
| 2025-10-02 | Documented Normalize-TextFile, spinner, and JSON summary requirements across workflow, configuration, norms, outputs, telemetry, security, acceptance; closed related open questions.    | geho        |
| 2025-10-02 | Normalized "Last updated" line formatting and resolved markdownlint findings.                                                                                                            | geho        |
