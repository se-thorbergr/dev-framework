> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# LibFs Specification

Last updated: 2025-09-28 - Owner: geho

## 1. Scope

- **Purpose:** `LibFs` provides **safe, policy-aware filesystem planning utilities** for repository tools. It normalizes paths, detects required changes, and produces an **action plan** for callers to execute. It favors **idempotency** and **dry-run first**.
- **In scope:** path normalization, existence checks, diffing current vs. desired state, planning creates/writes/copies/moves, rendering a human-readable summary of planned actions.
- **Out of scope:** performing the changes itself (no writes, no deletes); destructive operations are deferred and may be added later behind explicit policy.

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`

## 2. Preconditions & Assumptions

- PowerShell 7.x and Bash are available.
- Callers provide repository context (e.g., working directory, repo root) and required permissions.
- LibFs performs **no elevation** and **no writes**; callers own execution and side effects.

## 3. Shared Responsibilities

- **Supported platforms:** Windows and Linux.
- **Runtimes:** PowerShell 7.x and Bash.
- **Parity:** Feature/behavior parity between `tools/lib/fs.ps1` and `tools/lib/fs.sh` is REQUIRED.
- **No side effects:** The library **MUST NOT** perform filesystem mutations. It only **plans** and **renders** actions; callers own execution.
- **Policy compliance:** Respect read-only rules, ASCII-only console output, and ToolingGeneral semantics (e.g., `--dry-run`).

## 4. API Contract

> Library API (not a standalone CLI). Functions return **plans** and **diagnostics**, never perform writes.

### 4.1 PowerShell (tools/lib/fs.ps1)

| Function               | Parameters                                                                  | Returns                                                                                                                              | Notes                                                                                                        |
| ---------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `Normalize-Path`       | `-Path string`                                                              | string                                                                                                                               | Resolves separators/case per OS; no FS access required.                                                      |
| `Plan-EnsureDirectory` | `-Path string`                                                              | object `{ Actions:[{Op:'mkdir',Path}], Conflicts:[] }`                                                                               | If dir missing, adds a `mkdir` action; otherwise empty.                                                      |
| `Plan-EnsureFile`      | `-Path string -Content string -Mode ('create'\| 'overwrite'\|'if-changed')` | object `{ Actions:[{Op:'write',Path,Content,Hash,HashAlgorithm}], Diff:{OldContent?,NewContent?,OldHash?,NewHash?,HashAlgorithm?} }` | Computes write action; with `if-changed` emits only when content differs and surfaces SHA-256 hash metadata. |
| `Plan-Copy`            | `-Source string -Target string -Overwrite:bool`                             | object `{ Actions:[{Op:'copy',Src,Dest,Overwrite}], Conflicts:[] }`                                                                  | Plans a non-destructive copy; flags potential overwrites.                                                    |
| `Plan-Move`            | `-Source string -Target string -Overwrite:bool`                             | object `{ Actions:[{Op:'move',Src,Dest,Overwrite}], Conflicts:[] }`                                                                  | Plans a move; callers decide execution.                                                                      |
| `Validate-Plan`        | `-Actions object[]`                                                         | object `{ IsValid:bool; Errors:[…]; Warnings:[…] }`                                                                                  | Checks for contradictory or unsafe ops (e.g., write to protected path).                                      |
| `Render-Plan`          | `-Actions object[] -Header string?`                                         | string                                                                                                                               | ASCII-only, human-readable summary (for `--summary`).                                                        |

### 4.2 Bash (tools/lib/fs.sh)

| Function              | Parameters           | Returns                                                                          | Notes                                                               |
| --------------------- | -------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `fs_normalize`        | `path`               | string                                                                           | Normalize separators/case as applicable.                            |
| `fs_plan_ensure_dir`  | `path`               | map `{actions[],conflicts[]}`                                                    | Adds mkdir action if missing.                                       |
| `fs_plan_ensure_file` | `path,content,mode`  | map `{actions[],diff{oldContent?,newContent?,oldHash?,newHash?,hashAlgorithm?}}` | Only plans writes; `mode` like above and includes SHA-256 metadata. |
| `fs_plan_copy`        | `src,dest,overwrite` | map `{actions[],conflicts[]}`                                                    | Plan copy with overwrite flag.                                      |
| `fs_plan_move`        | `src,dest,overwrite` | map `{actions[],conflicts[]}`                                                    | Plan move with overwrite flag.                                      |
| `fs_plan_validate`    | `actions[]`          | map `{is_valid,errors[],warnings[]}`                                             | Validate plan against policy.                                       |
| `fs_plan_render`      | `actions[],header?`  | string                                                                           | Human-readable, ASCII-only.                                         |

### 4.3 Policy guards (normative)

- Paths matching **protected patterns** (e.g., `*.mdk.ini`) MUST NOT be targeted by `write/move/copy` ops unless targeting their `.local` counterparts.
- All rendered output MUST be ASCII-only.
- Plans MUST be deterministic given identical inputs.

## 5. Workflow

1. Normalize user-provided paths (`Normalize-Path`/`fs_normalize`).
2. Compute one or more **plan** objects for the desired state (ensure dir/file, copy/move).
3. Validate the merged plan with `Validate-Plan`/`fs_plan_validate` (reject unsafe ops).
4. Render the plan to text for logs/summary with `Render-Plan`/`fs_plan_render`.
5. **Caller** executes actions (outside the library) honoring `--dry-run`.

## 6. Configuration Handling

- LibFs has **no persistent configuration**. Behavior is parameter-driven.
- Protected patterns and policy inputs MAY be supplied by the caller (e.g., read-only globs).
- File content passed to planning functions is treated as opaque text; normalization is caller’s responsibility.

## 7. Normative Requirements

- The library **MUST NOT** perform filesystem mutations.
- The library **MUST** return deterministic plans and ASCII-only renders.
- PowerShell and Bash implementations **MUST** maintain behavior parity.
- Planning helpers **MUST** detect and flag attempts to modify protected files.
- `Validate-Plan`/`fs_plan_validate` **MUST** catch contradictory ops (e.g., move then copy same path).

## 8. Outputs

- **Plans:** arrays of action records with normalized paths.
- **Rendered summaries:** ASCII-only multi-line text suitable for `--summary`.
- **Diagnostics:** validation results (errors/warnings) explaining unsafe or contradictory ops.

## 9. Failure Modes & Recovery

Provide structured entries for common failures.

Optional columns: **Exit Code** and **Area** (e.g., `git`, `dotnet`, `fs`) to speed triage.

| ID     | Symptom                                                   | Remedy                                                                           |
| ------ | --------------------------------------------------------- | -------------------------------------------------------------------------------- |
| FS-001 | Attempt to target protected base file (e.g., `*.mdk.ini`) | Reject in validation; suggest writing corresponding `.local` instead.            |
| FS-002 | Non-deterministic plan order                              | Sort actions by `(Op, Path)` before rendering; treat as bug if variance remains. |
| FS-003 | Conflicting actions in merged plan                        | Report in `Validate-Plan`; require caller to split phases.                       |
| FS-004 | Non-ASCII content passed for render                       | Replace with safe placeholders in render; keep raw bytes only in memory.         |

## 10. Validation

- Unit tests for normalization, planning rules, and validation.
- Snapshot tests for `Render-Plan`/`fs_plan_render` outputs.
- Cross-shell parity tests (Pester/bats) confirming identical plans given the same inputs.

## 11. Acceptance Criteria

- Planning functions return correct action lists for representative scenarios.
- Protected files are never targeted; `.local` alternatives suggested.
- Rendered summaries are ASCII-only and stable across platforms.
- No filesystem mutations occur when using LibFs alone.

## 12. Security & Permissions

- Principle of least privilege: library operates without elevated rights.
- No secrets logged; callers own redaction before passing content.

## 13. Telemetry & Logging (optional)

- What to log and where; redaction rules if any.
- Opt-in/opt-out behavior.

## 14. Open Questions / Future Enhancements

- **Apply-plan execution helper:** Expose an opt-in `Apply-Plan` entry point so callers can execute planned actions when they explicitly opt in. The helper MUST enforce policy guards (dry-run preview, confirmation hooks, respect read-only globs) and remain optional so existing tooling can keep ownership of side effects.
- **Delete operations:** Deletions remain out of scope. If demand emerges, define an `allow_delete` flag with staged dry-run + double-confirm semantics before adding `remove` actions to the library.
- **Binary-safe diffing:** Implement lightweight hashing (SHA-256) for `if-changed` decisions so large/binary files can be compared without loading entire contents into memory. Expose results via plan metadata (`Hash`, `HashAlgorithm`, `OldHash`, `NewHash`) so callers can audit behavior, and document performance trade-offs.

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                                                                              | Approved By |
| ---------- | ------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-27 | Initial `LibFs` spec following common template; Section 4 set to **API contract**; planning-only (no side effects). | geho        |
| 2025-09-28 | Cleaned Section 2 (neutral, library-agnostic assumptions) and trimmed Section 4.3 to policy guards only.            | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.      | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                               | geho        |
| 2025-10-02 | Normalized "Last updated" line formatting and resolved markdownlint findings.                                       | geho        |
