# Tooling General Specification

_Last updated: 2025-09-20 – Owner: geho_

## 1. Scope

- Define the shared CLI contract, logging expectations, and operational guarantees that apply to every dev-framework tooling script (PowerShell and Bash).
- Individual tooling specs build on this document and must explicitly note any deviations.

## 2. Shared Responsibilities

- Provide equivalent behaviour between PowerShell (`*.ps1`) and Bash (`*.sh`) implementations.
- Honor repository policies: CodingStyle (line endings, headers), Workflow (verification/diff capture), Environment (supported platforms, prereqs).
- Surface errors with actionable messages and non-zero exit codes.

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
| CI output mode | `-Ci`               | `--ci`              | Format logs for CI/Actions friendly consumption.                             |

- Scripts may add tool-specific options, but the above switches must exist with consistent semantics.
- Summary output should be suppressed unless the flag is provided.

## 4. Logging & Output

- Respect verbosity level (`quiet` = minimal, `info` = default human-readable, `debug` = include command traces).
- `--ci`/`-Ci` may imply `info` logs while emitting machine-readable annotations when useful.
- All tooling must end with exit code 0 on success, non-zero on failure (2 for unexpected errors recommended).

## 5. Shared Library Usage

- PowerShell tooling can import `tools/lib/DevFramework.Tooling.psm1` (planned) for argument parsing, logging, summary helpers.
- Bash tooling can `source tools/lib/tooling.sh` for the same.
- Libraries must expose functions for: parsing the shared CLI flags, writing logs respecting verbosity, emitting summaries, and formatting CI output.

## 6. Verification & Testing

- Each tool must include: `--dry-run` tests, `--verbose debug` tests, and summary flag tests.
- CI should invoke the shared verification scripts (see `tools/verify-mdk2-config.sh`, `tools/Verify-Mdk2Config.ps1`) where applicable.

## 7. Change Log

| Date       | Change                                        | Approved By |
| ---------- | --------------------------------------------- | ----------- |
| 2025-09-20 | Initial tooling general specification drafted | geho        |
| 2025-09-20 | Added terminology definitions for ProjectName/ProjectFolder | geho        |

