> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# Tooling General Specification

_Last updated: 2025-09-30 - Owner: geho_

## 1. Scope

- Define the shared CLI contract, logging expectations, and operational guarantees that apply to every dev-framework tooling script (PowerShell and Bash).
- Individual tooling specs build on this document and must explicitly note any deviations.

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Tooling Specs Index: `docs/spec/tooling/README.md`
- Shared Libraries Overview: `docs/spec/tooling/SharedLibrary.md`
- Domain Libs: `docs/spec/tooling/LibCli.md`, `docs/spec/tooling/LibConfig.md`, `docs/spec/tooling/LibFs.md`, `docs/spec/tooling/LibMDK2.md`, `docs/spec/tooling/LibDotnetProj.md`

## 2. Preconditions & Assumptions

- PowerShell 7.x and Bash are supported shells.
- ASCII-only console output; tools must redact/avoid secrets.
- CI runs in info-only mode for SE solutions; builds are local-only.

## 3. Shared Responsibilities

- Provide equivalent behavior between PowerShell (`*.ps1`) and Bash (`*.sh`) implementations.
- Honor repository policies: CodingStyle (line endings, headers), Workflow (verification/diff capture), Environment (supported platforms, prereqs).
- Surface errors with actionable messages and non-zero exit codes.
- Respect **read-only** configs by policy (e.g., `*.mdk.ini`); never write these files.

### Terminology

- `ProjectName` – base name passed via `--name` or `-Name`; used for directories and .mdk files.
- `ProjectFolder` – the output directory resolved from CLI (`--output`) or defaults.
- Shared CLI switches are defined here; each tooling spec documents only its additions.

## 4. CLI Contract

### 4.1 Shared options

| Purpose        | PowerShell          | Bash                | Notes                                                                        |
| -------------- | ------------------- | ------------------- | ---------------------------------------------------------------------------- |
| Dry run        | `-DryRun`           | `--dry-run`         | No side effects; print intended actions.                                     |
| Verbosity      | `-Verbose <level>`  | `--verbose <level>` | Levels: `quiet`, `info`, `debug` (default `info`).                           |
| Summary opt-in | `-Summary`          | `--summary`         | When supplied, print end-of-run summary (tasks executed, exit code, errors). |
| Help           | `-Help`, `-?`, `-h` | `--help`, `-h`      | Display usage and exit 0.                                                    |
| Version        | `-Version`          | `--version`         | Print tool name and version in a **stable, parseable** format; exit 0.       |
| CI output mode | `-Ci`               | `--ci`              | Format logs for CI/Actions friendly consumption.                             |

- `--debug` is a shorthand for `--verbose debug` in both shells.
- Scripts may add tool-specific options, but the above switches must exist with consistent semantics.
- Summary output should be suppressed unless the flag is provided.

### 4.2 Logging & output

- Respect verbosity level (`quiet` = minimal, `info` = default human-readable, `debug` = include command traces).
- `--summary` is off by default; only emit when explicitly requested.
- `--ci`/`-Ci` may imply `info` logs while emitting machine-readable annotations when useful.
- All tooling must end with exit code 0 on success, non-zero on failure (2 for unexpected errors recommended).

## 5. Workflow

> **Execution-mode SoT:** Local vs CI/GitHub behavior is authoritative in `.ai/policies/core.yaml` → `modes`. This spec mirrors the summary only.

- Typical lifecycle: parse args → validate env → plan actions (no side effects under `--dry-run`) → execute → optionally emit summary.
- Tools SHOULD source/import shared libraries for common concerns (see below).

### 5.1 Library usage (informative)

- **LibCli** (`tools/lib/cli.ps1`, `tools/lib/cli.sh`) – shared CLI runtime: common flags, logging (quiet/info/debug), `--summary`, stable `--help/--version`, CI annotations.
- **LibConfig** (`tools/lib/config.ps1`, `tools/lib/config.sh`) – read/merge/validate config; render minimal diffs for `.local`. No writes to protected bases (e.g., `*.mdk.ini`).
- **LibFs** (`tools/lib/fs.ps1`, `tools/lib/fs.sh`) – planning-only filesystem actions (mkdir/write/copy/move) and human-readable plan render. No side effects.
- **LibMDK2** (`tools/lib/mdk2.ps1`, `tools/lib/mdk2.sh`) – validate MDK2 configs and expected project layout. No writes.
- **LibDotnetProj** (`tools/lib/dotnetproj.ps1`, `tools/lib/dotnetproj.sh`) – read `.csproj`/`.shproj`/`.projitems` and compute minimal XML edit plans (no writes); useful for PB Script and Mixin projects.

> All libraries are validation/plan only; they MUST NOT call `exit` or mutate files. Callers execute changes (if any) and MUST honor `--dry-run`.

### 5.2 Local vs CI/GitHub behavior (summary)

| Area               | Local (dev)          | CI/GitHub Actions                  |
| ------------------ | -------------------- | ---------------------------------- |
| Installs           | Allowed by flags     | **Forbidden**                      |
| Prompts            | Allowed              | **None** (non-interactive)         |
| SE build           | Allowed (local-only) | **Forbidden**                      |
| Linters/formatters | Optional             | **Required**                       |
| Bin64 discovery    | Enabled              | **Skipped** (not applicable on CI) |
| Codex setup        | Optional             | **Not used**                       |

## 6. Configuration Handling

- No persistent config is defined at this level. Tool-specific configs are documented in their specs. Read-only files (e.g., `*.mdk.ini`) MUST NEVER be written.

## 7. Normative Requirements

Use RFC 2119 terms. Keep each requirement atomic.

- Tooling **MUST** implement shared CLI switches with consistent semantics (`--dry-run`, verbosity, `--summary`, `--help`, `--version`, `--ci`).
- Tooling **MUST** respect verbosity levels and exit codes (0 success, non-zero failure; `2` recommended for unexpected errors).
- Tooling **SHOULD** share common libraries (`tools/lib/…`) for argument parsing, logging, and summaries when available.
- CI **MUST NOT** attempt SE game-dependent builds; CI runs format/lint only. Build is local-only.
- Verification **MUST** include dry-run, verbose debug, and summary flag tests.
- Tooling **MUST** support `--debug` as an alias for `--verbose debug`.

## 8. Outputs

- Human-readable logs respecting verbosity and CI mode.
- Optional summary block when `--summary` is supplied.
- Stable, parseable strings for `--help`/`--version`.

## 9. Failure Modes & Recovery

| ID               | Symptom                  | Remedy                                                 |
| ---------------- | ------------------------ | ------------------------------------------------------ |
| missing-sdk      | `dotnet` 9.0.x not found | Install SDK 9.0.x; see Environment policy              |
| no-mdk-templates | MDK2 templates missing   | Install/repair MDK2 templates; re-run setup            |
| invalid-args     | CLI parse failure        | Show `--help`; return non-zero; do not perform actions |

## 10. Validation

### 10.1 Validation details

- In `--ci`, **skip Bin64 discovery** entirely (SE not present on CI runners); set summary `detected.binarypath = null` with reason "not applicable in CI" and **do not fail** due to missing SE.
- Print tool version(s) via `--version` (or equivalent) in logs.
- Lint/format steps succeed (PSScriptAnalyzer, ShellCheck, Prettier/markdownlint where applicable).
- Required files are present and in expected state.
- Summary output (when `--summary` is supplied) includes tasks executed, exit code, and errors.

## 11. Acceptance Criteria

- Preconditions are met; required tooling versions are available.
- Commands execute with expected exit codes and outputs for dry-run and debug modes.
- No write attempts to read-only config types (e.g., `*.mdk.ini`).
- CI logs show format/lint results; local build passes (where applicable).

## 12. Security & Permissions

- Use least privilege; no secrets in logs.
- Honor execution policies; prefer signed scripts where required.

## 13. Telemetry & Logging (optional)

- If telemetry is added, document events, destinations, and redaction rules; provide opt-in/opt-out.

## 14. Open Questions / Future Enhancements

**Open questions**

- Should the **Local vs CI/GitHub** execution matrix live in _ToolingGeneral_ only, or be elevated to **Environment Policy** with a machine-readable twin in `.ai/policies/modes.yaml`? Decide the single SoT and cross-references.
- Which additional package managers (e.g., `choco`, `brew`, `dnf`, `pacman`, `zypper`) should be supported in local mode, and what **security/manual-first** rules must apply per manager?

**Future enhancements**

- Add structured summary outputs: `--summary-format json` (stdout) and `--summary-json <path>` (opt-in file) with a stable schema; reflect in Section 4/Section 8/Section 10 and LibCli.
- Publish a small **PS/Bash parity coverage matrix** for shared libraries (what’s implemented/tested).
- Document explicit `--ci` behavior checklist (no prompts, no installs, no SE builds) and add validations.

## 15. Change Log

> **Policy:** On every spec edit, append a new row **at the bottom** with date, summary, and approver (chronological top→bottom).

| Date       | Change                                                                                                                                                                | Approved By |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-20 | Initial tooling general specification drafted                                                                                                                         | geho        |
| 2025-09-20 | Added terminology definitions for ProjectName/ProjectFolder                                                                                                           | geho        |
| 2025-09-26 | Align to template: added normative requirements, validation, acceptance criteria, failure modes, security/telemetry; added read-only config note and changelog policy | geho        |
| 2025-09-27 | Added `--version` to shared CLI contract (table, normative requirement) and to verification tests (stable, parseable output).                                         | geho        |
| 2025-09-27 | Updated references and **Shared Library Usage** to domain-lib family (LibCli/LibConfig/LibFs/LibMDK2/LibDotnetProj); removed legacy module names.                     | geho        |
| 2025-09-28 | Aligned to 15-section template; added Section 2 Preconditions, Section 5 Workflow, Section 6 Configuration Handling, Section 8 Outputs; renumbered later sections.    | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                                                                                 | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.                                                        | geho        |
| 2025-09-28 | Standardized verbosity: added `--debug` alias for `--verbose debug`; fixed subheading to Section 5.1.                                                                 | geho        |
| 2025-09-30 | Section 14: add Local vs CI/GitHub matrix question, JSON summary enhancement, package manager expansion; no behavior changes yet.                                     | geho        |
| 2025-09-30 | Clarified CI stance for Bin64: skip discovery in validation and mark as not applicable on CI runners.                                                                 | geho        |
| 2025-09-30 | Added Section 5.2 summary matrix for Local vs CI/GitHub behavior.                                                                                                     | geho        |
| 2025-09-30 | Added SoT pointer in Section 5 to `.ai/policies/core.yaml → modes`.                                                                                                   | geho        |
