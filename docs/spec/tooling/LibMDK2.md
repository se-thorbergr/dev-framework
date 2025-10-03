> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# LibMDK2 Specification

Last updated: 2025-09-28 - Owner: geho

## 1. Scope

- **Purpose:** `LibMDK2` provides **MDK2-specific validation and inspection helpers** for repository tools. It reads MDK2 config and project metadata, validates presence/versions/templates, and returns **structured diagnostics**. It performs **no writes**.
- **In scope:** discovering MDK2 config files, reading and normalizing values, validating required keys and template versions, checking project structure expectations, and emitting diagnostics suitable for CI.
- **Out of scope:** editing configs, installing MDK2, locating Steam libraries, or performing builds. Use other tooling for those concerns.

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`
- Library overview: `docs/spec/tooling/SharedLibrary.md`

## 2. Preconditions & Assumptions

- **Runtimes:** PowerShell **7.x** and Bash on Windows/Linux.
- **Inputs:** MDK2 configuration files (e.g., `*.mdk.ini`, optional `*.mdk.local.ini`) and project directories.
- **Encoding:** Files are UTF-8 without BOM; console outputs MUST be ASCII-only.
- **No MDK2 execution required:** Library validates statically and does not run MDK2.

## 3. Shared Responsibilities

- **Parity:** Feature parity between `tools/lib/mdk2.ps1` and `tools/lib/mdk2.sh` is REQUIRED.
- **Policy compliance:** Respect read-only rules for `*.mdk.ini`; never propose writes to protected files.
- **Determinism:** Given identical inputs, validations produce identical outputs across shells.

## 4. API Contract

> Library API (not a standalone CLI). Functions return **diagnostics objects** and **normalized info**; no file writes.

### 4.1 PowerShell (tools/lib/mdk2.ps1)

| Function               | Parameters                                 | Returns                                                                                   | Notes                                                                      |
| ---------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `Find-Mdk2Configs`     | `-Root string -Patterns string[]`          | object `{ Paths:[path...] }`                                                              | Discovers candidate MDK2 config files under `Root`.                        |
| `Read-Mdk2Config`      | `-Path string`                             | object `{ Data: hashtable; Source:string }`                                               | Parses a single `*.mdk(.local).ini` using LibConfig reader when available. |
| `Get-Mdk2ProjectInfo`  | `-ProjectRoot string`                      | object `{ HasTemplates:bool; TemplateVersion:string?; ScriptsPath:string?; Notes:[...] }` | Inspects project layout for expected MDK2 structure.                       |
| `Validate-Mdk2Config`  | `-Data hashtable -MinTemplate string?`     | object `{ IsValid:bool; Errors:[...]; Warnings:[...] }`                                   | Validates required keys and (optionally) minimum template version.         |
| `Validate-Mdk2Project` | `-ProjectRoot string -MinTemplate string?` | object `{ IsValid:bool; Errors:[...]; Warnings:[...]; Info:object }`                      | Orchestrates discovery+read+project checks; returns combined diagnostics.  |
| `Render-Mdk2Summary`   | `-Diagnostics object`                      | string                                                                                    | ASCII-only summary suitable for `--summary`.                               |

### 4.2 Bash (tools/lib/mdk2.sh)

| Function                | Parameters                   | Returns                                                       | Notes                                        |
| ----------------------- | ---------------------------- | ------------------------------------------------------------- | -------------------------------------------- |
| `mdk2_configs`          | `root,patterns...`           | array of paths                                                | Discover candidate MDK2 config files.        |
| `mdk2_read`             | `path`                       | map `{data,source}`                                           | Parse one config.                            |
| `mdk2_project_info`     | `project_root`               | map `{has_templates,template_version?,scripts_path?,notes[]}` | Inspect layout for MDK2.                     |
| `mdk2_validate_config`  | `data,min_template?`         | map `{is_valid,errors[],warnings[]}`                          | Validate required keys and template version. |
| `mdk2_validate_project` | `project_root,min_template?` | map `{is_valid,errors[],warnings[],info}`                     | End-to-end validation.                       |
| `mdk2_render_summary`   | `diagnostics`                | string                                                        | ASCII-only summary.                          |

### 4.3 Required/optional fields (normative)

`LibMDK2` treats `docs/mdk2.wiki/MDK²-Project-Configuration-Guide.md` (synced from the upstream wiki) as the authoritative schema for `*.mdk.ini` and `*.mdk.local.ini`. The library MUST enforce the following:

- **Required section:** `[mdk]` MUST be present in every config file (tracked and local).
- **Keys defined by the guide:**

  | Key          | Allowed values                                  | Typical file                | Notes                                                                |
  | ------------ | ----------------------------------------------- | --------------------------- | -------------------------------------------------------------------- |
  | `type`       | `programmableblock`, `mod`                      | `.mdk.ini` (tracked)        | Set by template; SHOULD remain unchanged.                            |
  | `trace`      | `on`, `off`                                     | Either                      | Debug logging for MDK tooling (default `off`).                       |
  | `minify`     | `none`, `trim`, `stripcomments`, `lite`, `full` | Either                      | Controls code minification level.                                    |
  | `ignores`    | Comma-separated glob patterns                   | Either                      | Excluded files when building scripts.                                |
  | `donotclean` | Comma-separated glob patterns                   | Either                      | Protected files when cleaning mods.                                  |
  | `output`     | `auto` or explicit path                         | `.mdk.local.ini` (override) | Determines script output directory; local overrides take precedence. |
  | `binarypath` | `auto` or explicit path                         | `.mdk.local.ini` (override) | Overrides MDK binary discovery (e.g., Space Engineers `Bin64`).      |

- **Additional keys:** The guide may introduce new `[mdk]` keys over time. `LibMDK2` MUST preserve unknown keys, warn only when values conflict with policy, and surface them in diagnostics.
- **Local overrides:** `.mdk.local.ini` entries override tracked `.mdk.ini` values. Diagnostics MUST clarify which file supplied each value.
- **Other sections:** Repo-specific tooling MAY add additional sections (e.g., `[paths]`). The library MUST tolerate these sections, ensuring they do not block validation.

## 5. Workflow

1. Discover MDK2 configs with `Find-Mdk2Configs`/`mdk2_configs`.
2. Read and normalize config with `Read-Mdk2Config`/`mdk2_read`.
3. Inspect project structure with `Get-Mdk2ProjectInfo`/`mdk2_project_info`.
4. Run validations via `Validate-Mdk2Config` and `Validate-Mdk2Project` (with optional `MinTemplate`).
5. Render a human-readable summary via `Render-Mdk2Summary`/`mdk2_render_summary` for logs or CI annotations.

## 6. Configuration Handling

- **Read-only policy:** Library never writes `*.mdk.ini`; if callers need changes, they MUST persist diffs to `*.mdk.local.ini` using LibConfig.
- **Discovery:** Default patterns include `*.mdk.ini` and `*.mdk.local.ini`; callers MAY extend.
- **Normalization:** Keys treated case-insensitively; values trimmed; unknown keys preserved for forward-compat.
- **Environment:** Library does not read env vars directly; callers pass any env-derived values explicitly.

## 7. Normative Requirements

- **No writes, no exits:** Library MUST NOT write files or terminate the process.
- **Deterministic outputs:** Given the same inputs, outputs MUST be stable across shells and runs.
- **ASCII-only renders:** All emitted text MUST be ASCII-only.
- **Parity:** PowerShell and Bash implementations MUST maintain behavior parity.
- **Cross-file consistency:** When multiple MDK2 configs are discovered (e.g., tracked + local overrides), the library MUST compare the `[mdk]` keys defined by the guide (`type`, `trace`, `minify`, `ignores`, `donotclean`, `output`, `binarypath`). Conflicts MUST surface as warnings (or errors when they break policy). Diagnostics MUST name the conflicting files and values so callers can resolve drift.

## 8. Outputs

- **Diagnostics objects:** booleans for validity and arrays of errors/warnings.
- **Info objects:** normalized metadata (template version, scripts path, etc.).
- **Rendered summary:** plain ASCII text suitable for logs or CI.

## 9. Failure Modes & Recovery

| ID      | Symptom                                 | Remedy                                                                  |
| ------- | --------------------------------------- | ----------------------------------------------------------------------- |
| MDK-001 | No MDK2 configs found                   | Return `IsValid:false` with guidance on expected file names/locations.  |
| MDK-002 | Parse error in `*.mdk.ini`              | Return detailed error (file/line/key); caller decides whether to halt.  |
| MDK-003 | Template version below minimum          | Return `IsValid:false` with required vs. found versions in message.     |
| MDK-004 | Project layout missing expected folders | Return warning or error depending on severity; include suggested fixes. |

## 10. Validation

- Unit tests for discovery patterns, parsing, and normalization.
- Schema/shape validation tests for required/optional keys.
- End-to-end tests using sample MDK2 project layouts across shells.

## 11. Acceptance Criteria

- `Validate-Mdk2Project` returns consistent diagnostics for representative projects.
- Missing optional keys yield warnings, not hard failures.
- Rendered summaries are ASCII-only and deterministic.

## 12. Security & Permissions

- Do not log secrets. Avoid emitting absolute user paths unless necessary; prefer relative paths.
- Operate under least privilege; never attempt to modify file permissions.

## 13. Telemetry & Logging (optional)

- Library itself emits no logs; counters (e.g., number of configs found) MAY be included in diagnostics for callers to surface.

## 14. Open Questions / Future Enhancements

- Provide adapters for common CI systems to format diagnostics automatically using `LibCli`’s CI annotation helpers (GitHub, Azure DevOps, etc.). This enhancement would surface errors inline in PRs while keeping plain summaries for other environments.

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                                                                           | Approved By |
| ---------- | ---------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-27 | Initial `LibMDK2` spec following common template; Section 4 set to **API contract**; validation-only, no writes. | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.   | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                            | geho        |
| 2025-10-02 | Normalized "Last updated" line formatting and resolved markdownlint findings.                                    | geho        |
