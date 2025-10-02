> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# LibDotnetProj Specification

_Last updated: 2025-09-28 - Owner: geho_

## 1. Scope

- **Purpose:** `LibDotnetProj` provides **read/inspect/plan** capabilities for MSBuild XML project files used by MDK2 workflows: `.csproj` (PB Script), `.shproj` (Shared Project), and `.projitems` (Mixin items). It extracts structured information and **plans minimal, deterministic XML edits** as an action plan for callers to execute. The library **does not write files**.
- **In scope:** parsing and normalizing MSBuild XML, reading properties/items/imports, validating expected structure for PB Script and Mixin projects, computing **minimal edit plans** (add/update/remove node/attribute/import), and rendering human-readable summaries.
- **Out of scope:** executing edits, running `dotnet build`, installing SDKs, or editing MDK2 INI files. Use `LibFs` for plan rendering and future apply, and `LibMDK2` for MDK2-specific config validation.

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`
- Library overview: `docs/spec/tooling/SharedLibrary.md`
- MDK2 validators: `docs/spec/tooling/LibMDK2.md`

## 2. Preconditions & Assumptions

- **Runtimes:** PowerShell **7.x** and Bash. No `dotnet` runtime is required for parsing; the library treats XML as text.
- **Files:** MSBuild XML files (`*.csproj`, `*.shproj`, `*.projitems`). UTF-8 without BOM preferred; the library MUST tolerate UTF-8 with BOM.
- **Schema looseness:** MSBuild allows flexible ordering; this library MUST operate with **order-insensitive** comparisons and produce **stable ordering** in planned edits.

## 3. Shared Responsibilities

- **Parity:** Behavior parity between `tools/lib/dotnetproj.ps1` and `tools/lib/dotnetproj.sh` is REQUIRED.
- **Policy compliance:** ASCII-only console output; no file writes. Respect read-only protections (writes are planned only).
- **Determinism:** Given identical inputs, plans and renders MUST be identical across shells and runs.

## 4. API Contract

> Library API (not a standalone CLI). Functions return **structured models** and **edit plans**; callers apply plans (if at all).

### 4.1 PowerShell (tools/lib/dotnetproj.ps1)

| Function                   | Parameters                                                  | Returns                                                                                               | Notes                                                                                                                    |
| -------------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `Read-DotnetProject`       | `-Path string`                                              | object `{ Kind:'csproj'\|'shproj'\|'projitems'; Xml:string; Model:object }`                           | Reads XML and produces a normalized **Model** (props/items/imports).                                                     |
| `Validate-PbScriptProject` | `-Model object`                                             | object `{ IsValid:bool; Errors:[...]; Warnings:[...] }`                                               | Validates PB Script expectations (e.g., `TargetFramework`, required `ItemGroup` entries, optional `thumb.png` content).  |
| `Validate-MixinProject`    | `-Model object`                                             | object `{ IsValid:bool; Errors:[...]; Warnings:[...] }`                                               | Validates presence of `.projitems` and correct `<Import Project="..." Label="Shared" />` linkage in `.shproj`/`.csproj`. |
| `Plan-ImportShared`        | `-Model object -ProjitemsPath string`                       | object `{ Actions:[{Op:'ensure-import', Project, Label:'Shared', Before:string?}], Conflicts:[...] }` | Ensures a shared-items import exists once, at deterministic position.                                                    |
| `Plan-AddItem`             | `-Model object -Item string -Include string -Metadata map?` | object `{ Actions:[{Op:'ensure-item', Item, Include, Metadata?}], Conflicts:[...] }`                  | Plans to add an item (e.g., `Content` for `thumb.png`). Idempotent.                                                      |
| `Plan-SetProperty`         | `-Model object -Name string -Value string`                  | object `{ Actions:[{Op:'ensure-property', Name, Value}], Conflicts:[...] }`                           | Plans to set/update a property with stable placement.                                                                    |
| `Plan-Remove`              | `-Model object -Selector string`                            | object `{ Actions:[{Op:'remove', Selector}], Conflicts:[...] }`                                       | Plans a removal via a simplified selector (path/XPath-ish).                                                              |
| `Validate-PlanXml`         | `-Actions object[] -Kind string`                            | object `{ IsValid:bool; Errors:[...]; Warnings:[...] }`                                               | Checks plan safety (no duplicate imports, no conflicting edits).                                                         |
| `Render-XmlPlan`           | `-Actions object[] -Header string?`                         | string                                                                                                | ASCII-only human-readable description of planned changes.                                                                |

### 4.2 Bash (tools/lib/dotnetproj.sh)

| Function                     | Parameters                     | Returns                              | Notes                   |
| ---------------------------- | ------------------------------ | ------------------------------------ | ----------------------- |
| `dotproj_read`               | `path`                         | map `{kind,xml,model}`               | Read & normalize.       |
| `dotproj_validate_pbscript`  | `model`                        | map `{is_valid,errors[],warnings[]}` | PB Script expectations. |
| `dotproj_validate_mixin`     | `model`                        | map `{is_valid,errors[],warnings[]}` | Mixin expectations.     |
| `dotproj_plan_import_shared` | `model,projitems_path`         | map `{actions[],conflicts[]}`        | Ensure shared import.   |
| `dotproj_plan_add_item`      | `model,item,include,metadata?` | map `{actions[],conflicts[]}`        | Ensure item entry.      |
| `dotproj_plan_set_property`  | `model,name,value`             | map `{actions[],conflicts[]}`        | Ensure property.        |
| `dotproj_plan_remove`        | `model,selector`               | map `{actions[],conflicts[]}`        | Plan removal.           |
| `dotproj_plan_validate`      | `actions[],kind`               | map `{is_valid,errors[],warnings[]}` | Validate plan.          |
| `dotproj_plan_render`        | `actions[],header?`            | string                               | Render summary.         |

### 4.3 Model (normalized, shell-agnostic)

The **Model** MUST expose, at minimum:

- **Properties:** key→value map (`PropertyGroup`).
- **Items:** list of `{ Item:string; Include:string; Metadata:map }` (from `ItemGroup`).
- **Imports:** list of `{ Project:string; Label:string?; Condition:string? }`.
- **Kind:** `csproj` | `shproj` | `projitems`.
- **Path:** absolute or repo-relative path to the file.

## 5. Workflow

1. `Read-DotnetProject`/`dotproj_read` loads XML → builds **Model**.
2. Run `Validate-*` depending on project kind (PB Script vs Mixin) to surface structural issues.
3. Compose one or more **Plan-\*** calls (import shared, add item, set property, remove) to form an edit plan.
4. Validate the plan via `Validate-PlanXml`/`dotproj_plan_validate`.
5. Render plan with `Render-XmlPlan`/`dotproj_plan_render` for logs/summary.
6. **Caller** executes changes (not this library), ideally via a future `LibFs Apply-Plan` or a tool-specific executor, honoring `--dry-run`.

## 6. Configuration Handling

- No persistent config. Behavior is parameter-driven.
- Callers MAY supply project-type hints; otherwise the library infers `Kind` by file extension and root XML element.
- Path handling must be OS-appropriate; keep paths relative to repo when rendering.

## 7. Normative Requirements

- The library **MUST NOT** write or modify files.
- Plans and renders **MUST** be **deterministic** and **ASCII-only**.
- Import enforcement **MUST** be idempotent (no duplicate `<Import>` entries).
- Item/property planning **MUST** preserve stable ordering when materialized.
- PowerShell and Bash implementations **MUST** maintain parity.

## 8. Outputs

- **Model objects** describing properties/items/imports.
- **Edit plans** as arrays of action records (ensure-import/ensure-item/ensure-property/remove).
- **Rendered summaries** for human review and CI notes.

## 9. Failure Modes & Recovery

| ID     | Symptom                          | Remedy                                                                 |
| ------ | -------------------------------- | ---------------------------------------------------------------------- |
| DP-001 | Invalid XML                      | Return parse error with location; caller decides whether to halt.      |
| DP-002 | Duplicate shared import detected | Plan validator flags; suggest deduplication via `remove` op.           |
| DP-003 | Conflicting actions in plan      | Validator surfaces conflict; require caller to reorder or split plans. |
| DP-004 | Non-ASCII when rendering plan    | Replace with safe placeholders; treat as warning; tests enforce ASCII. |

## 10. Validation

- Unit tests: XML parsing across csproj/shproj/projitems; model construction; plan determinism.
- Snapshot tests: `Render-XmlPlan` outputs across shells.
- Integration tests: PB Script sample (`Program.cs`, `*.csproj`, `thumb.png`) and Mixin sample (`.shproj` + `.projitems`).

## 11. Acceptance Criteria

- Correct **Model** extracted from representative PB Script and Mixin projects.
- Validations catch missing imports or required items/properties.
- Plans are idempotent and pass validator; rendered summaries are ASCII-only.

## 12. Security & Permissions

- No elevation. No secrets in renders. Paths redacted to repo-relative where feasible.

## 13. Telemetry & Logging (optional)

- Library emits no logs; callers may count actions or validation findings for summaries.

## 14. Open Questions / Future Enhancements

- Add **apply** capability behind explicit policy (or integrate with future `LibFs Apply-Plan`).
- Provide higher-level recipes (e.g., “ensure PB Script essentials”) as composite planners.
- Support conditional edits based on `Condition` attributes.

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                                                                                     | Approved By |
| ---------- | -------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-27 | Initial `LibDotnetProj` spec following common template; Section 4 set to **API contract**; planning-only, no side effects. | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.             | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                                      | geho        |
