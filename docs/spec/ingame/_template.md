> Tone: normative (MUST/SHOULD/MAY, RFC 2119); ASCII-only punctuation; use second person only in step-by-step instructions.

# <In-game Spec: Title>

_Last updated: 2025-09-28 - Owner: geho_

## 1. Scope

- What this in-game script/spec covers and does not cover.
- Audience: SE players/engineers; reviewers; CI/lint automation.

### 1.1 References

- Spec Template (SoT): `docs/spec/ingame/_template.md` (Last updated: 2025-09-28)
- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`

## 2. Preconditions & Assumptions

- World settings (SIM speed, programmable block enabled, IPC allowances).
- Update cadence available: `Update1`, `Update10`, `Update100`.
- Instruction quota and memory constraints per tick; no threads/network/reflection/file IO.

## 3. Shared Responsibilities

- Callers supply configuration via Custom Data or arguments to `Main(string argument)`.
- Script owns persistence in `Storage` and/or Custom Data; must version and migrate state.
- Script must remain deterministic for MP; avoid non-deterministic sources.

## 4. API Contract (SE ingame script)

> This section is normative for PB scripts. Define entry points and contracts precisely.

### 4.1 Entry points & update model

- `Program()` – initialize, set `Runtime.UpdateFrequency` (`Update1|10|100`).
- `Main(string argument)` – command dispatcher (document supported commands and args).
- `Save()` – persist minimal state for reloads/blueprints.

### 4.2 Inputs & configuration

- Custom Data schema (keys, types, defaults).
- Argument grammar (commands, switches, examples).

### 4.3 Outputs & interfaces

- Echo/log format (ASCII-only); panel/IGC output formats if used.
- IGC channels / unicast tags and message payload schema.

## 5. Workflow

- Initialization → command parsing → update loop → save.
- Budget per tick; back-pressure/defer work when over budget.

## 6. Configuration Handling

- Read/merge from Custom Data → runtime overrides via `argument`.
- Validate and coerce types; preserve unknown keys.

## 7. Normative Requirements

- Use RFC 2119 terms; keep atomic.
- MUST keep per-tick instruction usage under budget; SHOULD amortize heavy work.
- MUST avoid non-deterministic time/entropy; SHOULD provide deterministic seeds for tests.
- MUST not use file IO/network/threads/reflection; MUST not call external processes.

## 8. Outputs

- Echo lines for human readers; optional LCDs/IGC.
- Summary output shape (keys, order) if applicable.

## 9. Failure Modes & Recovery

- Quota exceeded handling; partial work resume; data migration fallback.
- Invalid config/arguments; safe defaults; error codes/messages.

## 10. Validation

- Unit tests against command grammar and config coercion.
- Perf tests: instruction count under `Update1/10/100` budgets.
- Determinism tests: replay same inputs yield same outputs.
- Save/Load round-trip tests: state survives blueprint/copy-paste.

## 11. Acceptance Criteria

- All validation scenarios pass on a representative save.
- No runtime exceptions under bad inputs; graceful messaging.

## 12. Security & Permissions

- Sandbox constraints: no file IO/network/threads/reflection.
- Do not expose unsafe commands; validate all inputs.

## 13. Telemetry & Logging (optional)

- In-game telemetry is limited; document any panel/IGC logging.

## 14. Open Questions / Future Enhancements

- TBD

## 15. Change Log

> **Policy:** Append new entries at the bottom; do not rewrite history.

| Date       | Change                                                        | Approved By |
| ---------- | ------------------------------------------------------------- | ----------- |
| 2025-09-28 | Initial in-game spec template created (profile: `se_ingame`). | geho        |
