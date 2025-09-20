# <Tool Name> Specification

_Last updated: YYYY-MM-DD – Owner: <name/contact>_

## 1. Scope

- Purpose of the tool and the problems it solves.
- In/out of scope (link to related specs).

## 2. Shared Responsibilities

- Supported platforms (Windows/Linux) and runtimes (PowerShell 7._, Bash, dotnet 9.0._).
- External dependencies (MDK² templates, Steam installation, etc.).
- Configuration files read/written (`se-config.ini`, `se-config.local.ini`, `*.mdk(.local).ini`).

## 3. CLI Contract

| Option | Alias | Type | Default | Description |
| ------ | ----- | ---- | ------- | ----------- |
|        |       |      |         |             |

- Exit codes and meaning.
- Example invocations (PS/Bash).

## 4. Workflow

1. Pre-flight checks (config discovery, dependency validation).
2. Main execution steps (per major phase).
3. Post-actions (cleanup, logging, git hooks, etc.).

- Include flow diagram or pseudo-code if helpful.

## 5. Configuration Handling

- INI sections/keys consumed or produced.
- Resolution order (`.local` override rules, fallback to defaults).
- How missing configs are seeded (copying defaults, prompting user).

## 6. Outputs

- Files/directories created or modified.
- Console/log output expectations (verbosity levels, structured logging).

## 7. Error Handling & Recovery

- Known failure scenarios and messaging.
- Retry/rollback behaviour.
- Guidance for manual recovery if automatic handling fails.

## 8. Validation & Testing

- Required automated checks (unit/integration/smoke).
- Manual test cases (e.g., first-time setup, missing Steam path).
- Metrics or logging to verify success.

## 9. Open Questions / Future Enhancements

- Pending decisions before implementation.
- Nice-to-have extensions to revisit later.

## 10. Change Log

| Date | Change | Approved By |
| ---- | ------ | ----------- |
|      |        |             |
