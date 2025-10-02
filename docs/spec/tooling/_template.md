> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# <Tool Name> Specification

_Last updated: 2025-09-28 - Owner: geho_

## 1. Scope

- Purpose of the tool and the problems it solves.
- In/out of scope (link to related specs).

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`

## 2. Preconditions & Assumptions

- Required versions (prose style): `PowerShell 7.x`, `dotnet 9.0.x`, etc.
- Required tools: MDK2 templates (e.g., `2.2.31`), Steam installation present, etc.
- Environmental assumptions (paths, permissions, network access).

## 3. Shared Responsibilities

- Supported platforms (Windows/Linux) and runtimes (PowerShell 7.x, Bash, dotnet 9.0.x).
- External dependencies (MDK2 templates, Steam installation, etc.).
- Configuration files read/written (`se-config.ini`, `se-config.local.ini`, `*.mdk(.local).ini`).

## 4. CLI Contract

| Option | Alias | Type | Default | Description |
| ------ | ----- | ---- | ------- | ----------- |
|        |       |      |         |             |

- **Inherited flags** (optional; if this tool wraps another CLI): list the forwarded flags and their semantics.
- **Help & version:** tool **MUST** support `--help` and `--version` with stable, parseable output suitable for automated tests.
- **Exit codes:** define explicit codes (`0`=success; `1`=validation failure; `2`=unexpected error; `3`=user-aborted [optional]).
- **Examples:** show PowerShell and Bash invocations, including `--dry-run` / `--notes-only` usage.

## 5. Workflow

1. Pre-flight checks (config discovery, dependency validation).
2. Main execution steps (per major phase).
3. Post-actions (cleanup, logging, git hooks, etc.).

- Include flow diagram or pseudo-code if helpful.

## 6. Configuration Handling

- INI sections/keys consumed or produced (name them explicitly).
- Resolution order for config: `.devfw-mode.local` → `DEVFW_MODE` → `.devfw-mode` → heuristic (for `${MODE}`), and `.local` overrides base files.
- Persistence policy: write only keys that differ from the effective merged config (diff-only) to the corresponding `.local` file; never rewrite the base file.
- Discovery: where configs live (repo root vs. submodule), defaults when missing, and seeding behavior (copy templates, add generated header).
- Environment overrides: list any supported env vars and how they map to keys.
- Validation: what must exist after handling (e.g., `se-config.ini`, `se-config.local.ini`, `.mdk(.local).ini` for PB projects).

- **Read-only files:** do not write to policy-protected files (e.g., `*.mdk.ini`). Persist diffs to corresponding `.local` files.

## 7. Normative Requirements

Use RFC 2119 terms. Keep each requirement atomic.

- The tool **MUST** …
- The tool **SHOULD** …
- The tool **MAY** …

## 8. Outputs

- Files/directories created or modified.
- Console/log output expectations (verbosity levels, structured logging).

## 9. Failure Modes & Recovery

Provide structured entries for common failures.

Optional columns: **Exit Code** and **Area** (e.g., `git`, `dotnet`, `fs`) to speed triage.

| ID  | Symptom | Remedy |
| --- | ------- | ------ |
|     |         |        |

## 10. Validation

- Print tool version(s) via `--version` (or equivalent) in logs.
- Required automated checks (unit/integration/smoke).
- Manual test cases (e.g., first-time setup, missing Steam path).
- Metrics or logging to verify success.

## 11. Acceptance Criteria

- Preconditions are met.
- Commands execute successfully (exit codes as specified).
- Expected outputs are produced.
- Linters/formatters are clean, or acceptable exceptions are documented.

## 12. Security & Permissions

- Principle of least privilege; no secrets written to logs.
- Code signing / script execution policy considerations (if applicable).

## 13. Telemetry & Logging (optional)

- What to log and where; redaction rules if any.
- Opt-in/opt-out behavior.

## 14. Open Questions / Future Enhancements

- Pending decisions before implementation.
- Nice-to-have extensions to revisit later.

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                                                          | Approved By |
| ---------- | ----------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-28 | Set SoT date; confirmed 15-section structure and RFC-2119 note; ready for downstream reference. | geho        |
