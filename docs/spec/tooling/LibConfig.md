> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# LibConfig Specification

Last updated: 2025-09-28 - Owner: geho

## 1. Scope

- **Purpose:** `LibConfig` provides **read-only configuration discovery, parsing, merging, validation, and diff rendering** for repository tools. It supports INI and JSON sources and produces normalized, policy-compliant outputs for callers.
- **In scope:** locating config files, parsing INI/JSON, merge/precedence rules, environment overrides, schema validation hooks, **diff calculation against effective config**, and **rendering** of `.ini` fragments for `.local` files.
- **Out of scope:** any file writes or destructive changes. **Libraries do not write**; callers own persistence. Domain checks unrelated to config (use LibMDK2 for MDK2-specific validation).

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
- **Formats:** INI (key/value with sections) and JSON (objects only). YAML is out of scope.
- **Paths:** Repository root is the default search base; submodules may contribute additional config roots.
- **Encoding:** Files are expected to be UTF-8 without BOM; output rendering MUST be ASCII-only.

## 3. Shared Responsibilities

- **Supported platforms:** Windows and Linux.
- **Parity:** Behavior parity between `tools/lib/config.ps1` and `tools/lib/config.sh` is REQUIRED.
- **Policy compliance:** Respect **read-only** policy for `*.mdk.ini` and other protected files. Resolve using `.local` overlays; never propose changes to protected bases.
- **Callers own side effects:** The library returns data structures and rendered text; **callers** decide whether/where to write.

## 4. API Contract

> This section defines the **library API** (not a standalone CLI). Function names are normative; PS/Bash parity is required.

### 4.1 PowerShell (tools/lib/config.ps1)

| Function              | Parameters                                | Returns                                                  | Notes                                                                                                                                |
| --------------------- | ----------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `Get-ConfigSources`   | `-Root string` `-Patterns string[]`       | object `{ Sources: [path...] }`                          | Discovers candidate files under `Root` by `Patterns` (e.g., `se-config.ini`, `se-config.local.ini`, `*.mdk.ini`, `*.mdk.local.ini`). |
| `Read-Config`         | `-Path string`                            | object `{ Format:'ini'\|'json'; Data: hashtable }`       | Parses a single file. No writes.                                                                                                     |
| `Merge-Configs`       | `-Base object -Overlay object -Env map?`  | object `{ Data: hashtable }`                             | Deterministic merge (Base ← Overlay ← Env). Scalar override; arrays replaced unless `-Strategy` added later.                         |
| `Validate-Config`     | `-Data hashtable -Schema object?`         | object `{ IsValid: bool; Errors:[...]; Warnings:[...] }` | Structural validation; schema optional/hookable.                                                                                     |
| `Get-EffectiveConfig` | `-Root string -Env map?`                  | object `{ Data; Sources:[...]; Precedence:[...] }`       | Orchestrates discovery, read, merge, env overlay; returns normalized config + provenance.                                            |
| `Diff-Local`          | `-Effective hashtable -Desired hashtable` | object `{ Changes:[{Section;Key;Old;New}] }`             | Computes **diff** between effective config and desired state; suitable for `.local` persistence.                                     |
| `Render-Ini`          | `-Changes object -Header string?`         | string                                                   | Renders minimal INI fragment for `.local` files (diff-only). ASCII-only.                                                             |

### 4.2 Bash (tools/lib/config.sh)

| Function            | Parameters          | Returns                              | Notes                                             |
| ------------------- | ------------------- | ------------------------------------ | ------------------------------------------------- |
| `config_sources`    | `root,patterns...`  | array of paths                       | Discover candidate files.                         |
| `config_read`       | `path`              | map `{format,data}`                  | Parse one file.                                   |
| `config_merge`      | `base,overlay,env?` | map `{data}`                         | Deterministic merge order (base ← overlay ← env). |
| `config_validate`   | `data,schema?`      | map `{is_valid,errors[],warnings[]}` | Structural validation.                            |
| `config_effective`  | `root,env?`         | map `{data,sources[],precedence[]}`  | Discovery + read + merge + env overlay.           |
| `config_diff_local` | `effective,desired` | map `{changes[]}`                    | Compute diff suitable for `.local`.               |
| `ini_render`        | `changes,header?`   | string                               | Render minimal INI fragment (ASCII-only).         |

### 4.3 Resolution & Precedence (normative)

When computing the **effective config**, the library MUST apply this order:

1. **Base files** (e.g., `se-config.ini`, `*.mdk.ini`, other tool bases)
2. **Local overlays** (e.g., `se-config.local.ini`, `*.mdk.local.ini`)
3. **Environment overrides** (explicit map argument and/or selected env vars)

The result MUST include **provenance**: which sources were used and their order.

## 5. Workflow

1. Discover sources via `Get-ConfigSources`/`config_sources` using known patterns.
2. Parse each file with `Read-Config`/`config_read`.
3. Merge into an **effective config** (Base ← Local ← Env) with `Merge-Configs`/`config_merge` or `Get-EffectiveConfig`/`config_effective`.
4. Optionally validate via `Validate-Config`/`config_validate` (schema is caller-provided).
5. To persist user-level changes, compute **diff** via `Diff-Local`/`config_diff_local` and render an INI fragment with `Render-Ini`/`ini_render` for the **caller** to write into the appropriate `.local` file.

## 6. Configuration Handling

- **INI sections/keys:** The library is agnostic to domain schemas; callers provide schemas when needed.
- **Discovery:** Default patterns include `se-config.ini`, `se-config.local.ini`, `*.mdk.ini`, `*.mdk.local.ini`; callers MAY extend patterns.
- **Persistence policy:** The library **MUST NOT** write to any files. Callers persist diffs only to `.local` files; **never** modify protected bases (e.g., `*.mdk.ini`).
- **Environment overrides:** Callers pass an explicit env map. A recommended mapping is UPPERCASE env keys to `Section.Key` or `KEY` according to domain rules (documented by callers).
- **Normalization:** Keys are treated case-insensitively for INI; JSON keys preserved as-is.
- **Validation:** If a schema is supplied, invalid keys/values are reported; the library returns `{IsValid:false}` but does not terminate.

## 7. Normative Requirements

- The library **MUST NOT** write files or terminate the process.
- INI rendering **MUST** be minimal-diff and ASCII-only.
- Merge operations **MUST** be deterministic and idempotent.
- Effective config **MUST** include provenance (sources + precedence).
- Reading protected files (e.g., `*.mdk.ini`) is allowed; **writing them is forbidden**.
- PowerShell and Bash implementations **MUST** maintain behavior parity.

## 8. Outputs

- **Data structures:** normalized config objects, validation results, change lists (diffs).
- **Rendered text:** minimal INI fragment for `.local` persistence (caller writes).
- **Logs:** none directly; callers use LibCli for logging.

## 9. Failure Modes & Recovery

| ID      | Symptom                         | Remedy                                                                              |
| ------- | ------------------------------- | ----------------------------------------------------------------------------------- |
| CFG-001 | Config file missing             | Proceed with defaults; report missing source in provenance and validation warnings. |
| CFG-002 | Parse error (INI/JSON)          | Return validation error with file/line info; caller decides whether to halt.        |
| CFG-003 | Conflicting keys across sources | Last-writer wins by precedence; include conflict note in warnings.                  |
| CFG-004 | Attempt to persist base changes | Deny by policy; render only `.local` diff; never write bases.                       |

## 10. Validation

- Unit tests for parsing (INI/JSON), merge determinism, and INI rendering minimality.
- Integration tests verifying precedence (Base ← Local ← Env) and provenance reporting.
- Negative tests for parse errors and schema violations.
- Parity tests (Pester/bats) ensuring identical outcomes across shells.

## 11. Acceptance Criteria

- `Get-EffectiveConfig` returns normalized data and provenance for representative repos.
- `Diff-Local` produces minimal change sets when desired≠effective; zero changes otherwise.
- `Render-Ini` yields ASCII-only minimal fragments; snapshots pass across shells.
- No file writes performed by the library; callers control persistence.

## 12. Security & Permissions

- Do not log secrets (library does not log by itself). If callers pass values for rendering, they own redaction policy.
- Respect repository read-only protections; never attempt elevation or chmod.

## 13. Telemetry & Logging (optional)

- Library itself emits no logs. Optional counters (e.g., number of sources, changes) MAY be returned in data structures for callers to surface.

## 14. Open Questions / Future Enhancements

- Should we support partial section deletion semantics in INI diffs?
- Add YAML parsing later (behind a feature flag)?
- Provide a built-in schema for common repo files to reduce duplication?

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                                                                                                        | Approved By |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-27 | Initial `LibConfig` spec following common template; Section 4 is **API contract**; added precedence, diff rendering, and no-writes guarantee. | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.                                | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                                                         | geho        |
| 2025-09-28 | Normalized punctuation to ASCII (hyphens and ellipses) across the spec.                                                                       | geho        |
| 2025-10-02 | Normalized "Last updated" line formatting and resolved markdownlint findings.                                                                 | geho        |
