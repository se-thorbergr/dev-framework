> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# Scaffold MDK2 Project Specification

Last updated: 2025-09-28 - Owner: geho

## 1. Scope

- Provide a unified CLI (PowerShell/Bash) to create new Programmable Block scripts or mixins using MDK2 templates.
- Extend vanilla `dotnet new mdk2pbscript|mdk2mixin` behavior with repo-specific conventions (config seeding, `.editorconfig` propagation, solution integration, initial build).
- Excludes submodule management (delegated to Scaffold Project Submodule spec).

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`

## 2. Preconditions & Assumptions

- Required versions: PowerShell 7.x; dotnet SDK 9.0.x; MDK2 templates 2.2.31 available via `dotnet new --list`.
- Supported OS: Windows and Debian/Ubuntu (including WSL shells).
- Assumes valid MDK2 template install and a writable repo working tree.
- Solution integration requires an existing `.sln` path or an explicit one via `--add-sln`.
- CI note: SE solutions are **not** built in CI; build is **local-only**. CI runs format/lint only.

## 3. Shared Responsibilities

- `ProjectName` refers to the `--name` value used for namespaces, csproj files, and MDK configuration (`ProjectName.mdk.ini`). `ProjectFolder` refers to the target directory where files are generated.
- Scripts: `tools/ScaffoldMdk2Project.ps1` and `tools/scaffold-mdk2-project.sh` must remain behaviorally identical and honor the shared CLI contract defined in `ToolingGeneral.md`.
- Requires dotnet SDK 9.0.x with MDK2 template package 2.2.31 installed.
- Uses configuration keys from `se-config.ini` / `se-config.local.ini` to evaluate defaults for `ProjectName.mdk.ini` and the corresponding `ProjectName.mdk.local.ini` override file when scaffolding PB scripts (`--type pbscript`).
- Assumes execution within the repo root or accepts explicit output directory.

## 4. CLI Contract

See `ToolingGeneral.md` for mandatory shared options. This tool documents only its additional flags below.

All other shared switches (dry-run, verbosity, help, summary, CI) are inherited without change, and `--debug` is a shorthand for `--verbose debug`.

| Purpose              | PowerShell               | Bash                       | Notes                                                   |
| -------------------- | ------------------------ | -------------------------- | ------------------------------------------------------- |
| Project type         | `-Type <pbscript/mixin>` | `--type <pbscript\|mixin>` | Choose MDK template (default `pbscript`).               |
| Project name         | `-Name <string>`         | `--name <string>`          | Required; used for folder, namespace, config prefix.    |
| Output directory     | `-Output <path>`         | `--output <path>`          | Defaults to `./source/<type>/<ProjectName>`.            |
| Additional classes   | `-ClassName <name>`      | `--class-name <name>`      | Repeatable; generate stubs for partial classes.         |
| Solution integration | `-AddSln <path>`         | `--add-sln <path>`         | When provided, add project to solution (pbscript only). |

**Exit codes:** `0` = success; `1` = validation failure or unmet prerequisites; `2` = unexpected error; `3` = user-aborted (optional).

## 5. Workflow

1. Parse CLI, resolve defaults (type, ProjectName, ProjectFolder, solution path) and honor dry-run/logging flags. Default ProjectFolder is `./source/<type>/ProjectName` unless `--output` is supplied.
2. Validate prerequisites:
   - Confirm target directory absence (unless empty and allowed).
   - Ensure dotnet template availability (`dotnet new --list mdk2*`).
3. Invoke `dotnet new` with appropriate template (`mdk2pbscript` or `mdk2mixin`) into a temporary or final location depending on dry-run.
4. Apply repo conventions:
   - Copy `.editorconfig` (and future shared files) from repo root.
   - For PB scripts, seed missing `ProjectName.mdk.ini` / `ProjectName.mdk.local.ini` from `se-config.ini` / `se-config.local.ini`, then compute effective values and persist only differing keys into the `.local` file (with a generated header noting safe-to-edit overrides). Mixins do not create `.mdk` files.
   - Generate class stubs for each `ClassName` entry (C# file with namespace/project name, partial class?).
5. Integrate with solution (pbscript only): add generated `.csproj` using `dotnet sln <sln> add <project>` when requested/auto-detected.
6. Trigger initial build via `dotnet build` (pbscript) or template-specific command; capture output.
7. Summarize operations, point to next steps, and exit with corresponding code.

## 6. Configuration Handling

- Consume values from the `[mdk]` section (type, trace, minify, ignores, donotclean) plus dev-framework extensions under `[Paths]` and `[Build]`, using precedence `se-config.local.ini` → `se-config.ini` → template defaults. Persist only the keys that diverge into `ProjectName.mdk.local.ini`.
  - The `[mdk]` keys follow the MDK2 Project Configuration Guide: <https://github.com/malforge/mdk2/wiki/MDK%C2%B2-Project-Configuration-Guide>.
- Honor `output` and `binarypath` `auto` semantics by leaving `auto` in project config and reporting resolved paths separately.
- Append comment banner noting file generated by scaffolder and safe-to-edit instructions.

## 7. Normative Requirements

Use RFC 2119 terms. Keep each requirement atomic.

- The tool **MUST** use `dotnet new` with `mdk2pbscript` or `mdk2mixin`; do not handcraft template output.
- The tool **MUST** keep PowerShell and Bash behaviorally identical and honor the shared CLI contract.
- The tool **MUST NOT** modify `ProjectName.mdk.ini` values after creation; create it only if absent, and persist overrides to `ProjectName.mdk.local.ini`.
- The tool **MUST** seed only keys that differ from the effective configuration into `.mdk.local.ini` (diff-only writes) and add a generated banner.
- The tool **MUST** refuse destructive operations on existing non-empty target directories unless a future `--force` is explicitly provided.
- CI **MUST NOT** build SE solutions; CI runs format/lint only. Initial build is **local-only**.
- The tool **MUST** support `--debug` as an alias for `--verbose debug`.

## 8. Outputs

- Creates project directory containing MDK2 template output, class stubs, `.editorconfig`, and, for PB scripts, `ProjectName.mdk.ini` plus (when overrides exist) `ProjectName.mdk.local.ini`.
- Optionally updates solution file and any aggregated documentation index (future enhancement).
- Logs actions according to verbosity (debug includes dotnet command invocations, info summarizes steps, quiet minimal).

## 9. Failure Modes & Recovery

- Existing directory: abort with exit 1 unless `--force` (potential future option) is implemented.
- dotnet template failure: show command output, remove partially created directories when not dry-run.
- Solution modification failure: warn, continue with project creation, exit 1 to signal incomplete action.
- Build failure: surface diagnostics, exit 1 but leave project so developer can fix and re-run build.

## 10. Validation

- Verify `dotnet new --list` includes `Mal.Mdk2.ScriptTemplates` at `2.2.31` (template available for scaffolding).

- Unit tests for argument parsing, path resolution, class stub generation.
- Integration tests running dry-run and real scaffold on temp directories.
- Manual checks: pbscript creation with `--add-sln`, mixin creation without solution, repeated `--class-name` usage.
- Verification criteria: expected files present, `.sln` updated, build success (unless purposely invalid).

## 11. Acceptance Criteria

- Prerequisites satisfied: PowerShell 7.x, dotnet SDK 9.0.x, MDK2 templates 2.2.31 available via `dotnet new --list`.
- For pbscript: `ProjectName.mdk.ini` exists (created if absent) and `.mdk.local.ini` contains only differing keys with a generated header.
- Expected files present (template output, class stubs, `.editorconfig` copied).
- Solution updated when `--add-sln` is provided.
- Initial **local** build succeeds (CI does not build).
- Read-only rule respected: no in-place edits to `.mdk.ini` after creation.

## 12. Security & Permissions

- Use least privilege; do not require elevation.
- Do not log secrets or sensitive paths at `info` level. Keep dotnet invocation output but redact tokens if present.

## 13. Telemetry & Logging (optional)

- If telemetry is added later, document events, destinations, redaction rules; default to opt-in.

## 14. Open Questions / Future Enhancements

- Should scaffolder support additional template parameters (e.g., `--project`, `--language`)?
- Decide on namespace naming conventions for generated class stubs.
- Determine whether to auto-commit changes or leave for developer.

## 15. Change Log

> **Policy:** On every spec edit, append a new row **at the bottom** with date, summary, and approver (chronological top→bottom).

| Date       | Change                                                                                                                                       | Approved By |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-19 | Initial draft specification                                                                                                                  | geho        |
| 2025-09-19 | Documented ProjectName/ProjectFolder terminology and PB-script-only `.mdk` config generation                                                 | geho        |
| 2025-09-20 | Clarified PB-script seeding from se-config templates and mixin exclusions                                                                    | geho        |
| 2025-09-20 | Referenced ToolingGeneral shared CLI contract                                                                                                | geho        |
| 2025-09-27 | Minor edits reviewed; pending fixes noted (section renumbering, MDK2 prose, optional exit-codes note).                                       | geho        |
| 2025-09-27 | Final alignment: normalized US spelling (behavior/honor/summarizes) and added validation bullets for `${MODE}` echo and MDK2 template check. | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.                               | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                                                        | geho        |
| 2025-09-28 | Removed `${MODE}` echo from Section 10 Validation (orthogonal to scaffolding); kept template availability check.                             | geho        |
| 2025-09-28 | Standardized verbosity: added `--debug` alias note in Sections 4 and 7.                                                                      | geho        |
| 2025-10-02 | Normalized "Last updated" line formatting and resolved markdownlint findings.                                                                | geho        |
