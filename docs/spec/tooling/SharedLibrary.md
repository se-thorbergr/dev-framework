# Shared Tooling Library Specification

_Last updated: 2025-09-20 – Owner: geho_

## 1. Scope

- Provide reusable helpers for dev-framework tooling so Bash/PowerShell scripts share consistent behaviour defined in `ToolingGeneral.md`.
- Cover logging, CLI parsing, summary emission, CI formatting, and utility helpers (e.g., config validation hooks).
- Out of scope: tool-specific logic (setup, scaffolding) which will consume this library.

## 2. Shared Responsibilities

- Deliver two implementations with equivalent behaviour:
  - PowerShell module: `tools/lib/DevFramework.Tooling.psm1` (imported via `Import-Module`).
  - Bash library: `tools/lib/tooling.sh` (sourced via `. tools/lib/tooling.sh`).
- Support Windows (PowerShell 7.\* / Git Bash) and Linux shells.
- Expose only documented functions; treat everything else as internal.
- Honor repository policies (CodingStyle, Workflow, Environment) and rely on `ToolingGeneral.md` for CLI semantics.

## 3. Public API

| Function                                     | Module    | Description                                                                                                                                                 |
| -------------------------------------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Parse-CommonArgs` / `parse_common_args`     | PS / Bash | Parse shared flags (`--dry-run`, `--verbose`, `--summary`, `--help`, `--ci`) plus caller-provided descriptors; return structured result and remaining args. |
| `Initialize-Logging` / `init_logging`        | PS / Bash | Configure global verbosity/CI settings using parsed options.                                                                                                |
| `Write-Log` / `log_msg`                      | PS / Bash | Emit messages at `quiet/info/debug` levels, respecting CI mode.                                                                                             |
| `Register-Action` / `register_action`        | PS / Bash | Record key steps for optional summary output.                                                                                                               |
| `Emit-Summary` / `emit_summary`              | PS / Bash | Print summary when `--summary` requested (actions list, exit code, errors).                                                                                 |
| `Encode-CiAnnotation` / `ci_annotation`      | PS / Bash | Helper for GitHub Actions-style annotations when `--ci` is set.                                                                                             |
| `Validate-MdkConfig` / `validate_mdk_config` | PS / Bash | Optional hook that delegates to `Verify-Mdk2Config` scripts; returns status code.                                                                           |

- Functions must accept/return data in simple hash/dictionary structures so tooling scripts can pipe results (
  e.g., PowerShell `[Hashtable]`, Bash associative arrays / exported vars).
- Each API should be documented with parameters, return values, and examples inside the module headers.

## 4. Workflow Integration

1. Tool script imports/sources the library.
2. Call `Parse-CommonArgs` / `parse_common_args` with tool-specific option definitions.
3. Use `Initialize-Logging` / `init_logging` immediately after parsing.
4. Execute tool logic, calling `Write-Log` for output and `Register-Action` for major steps.
5. On exit, call `Emit-Summary` if summary flag present, passing exit code and any captured errors.

- Libraries must not exit the process; return status to the caller.

## 5. Configuration Handling

- No direct file writes. Helpers may consume `se-config.ini` / `se-config.local.ini` for validation via `Validate-MdkConfig`.
- Library-level defaults (e.g., default verbosity `info`) should be defined centrally and overridable through parsed options.

## 6. Outputs

- No filesystem output; libraries only write to STDOUT/STDERR via the logging helpers.
- All log lines must be prefixed with level tags (`[info]`, `[debug]`, etc.)
  and respect `--ci` formatting rules.

## 7. Error Handling & Recovery

- Logging helpers must never throw/fail; they downgrade to STDERR prints if misconfigured.
- Parsing helpers return error codes/structures for unknown options so callers can display help and exit 2.
- `Validate-MdkConfig` should bubble up the verifier script’s exit code and message without modification.

## 8. Validation & Testing

- Unit tests: validate argument parsing (with/without extra options), logging prefixes, summary generation, CI annotation formatting.
- Integration tests: create sample scripts (one PS, one Bash) that consume the library and exercise dry-run + summary + CI flows.
- CI should run both unit and integration tests on Windows and Linux runners.

## 9. Open Questions / Future Enhancements

- Provide text I/O helpers enforcing UTF-8 encoding, LF newlines, and terminal newline when writing policy-managed files.
- Should the libraries include reusable spinner/progress helpers?
- Do we need structured JSON summaries for CI artifacts?
- Consider adding localization hooks if non-English output is required later.

## 10. Change Log

| Date       | Change                                    | Approved By |
| ---------- | ----------------------------------------- | ----------- |
| 2025-09-20 | Initial shared tooling library spec draft | geho        |
