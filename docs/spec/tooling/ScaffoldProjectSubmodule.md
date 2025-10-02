> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# Scaffold Project Submodule Specification

Last updated: 2025-09-28 - Owner: geho

## 1. Scope

- Automate creation or onboarding of Programmable Block script or mixin submodules within the dev-framework super-repo.
- Handle git submodule plumbing, MDK2 project scaffolding (via Scaffold MDK2 Project tool), initial build, and optional commit guidance.
- Out of scope: remote repository creation (GitHub API), CI configuration, or enforcing team workflow approvals.

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`
- Project scaffolder CLI: `docs/spec/tooling/ScaffoldMdk2Project.md`

## 2. Preconditions & Assumptions

- Required versions: PowerShell 7.x; dotnet SDK 9.0.x; MDK2 templates 2.2.31 available via `dotnet new --list`.
- Supported OS: Windows and Debian/Ubuntu (including WSL shells).
- Git with submodule support available; developer has push rights if committing.
- SE build is **local-only**; CI runs **format/lint** only.

## 3. Shared Responsibilities

- `ProjectName` refers to the `--name` value used for namespaces, csproj files, and MDK configuration (`ProjectName.mdk.ini`). `ProjectFolder` refers to the target directory where files are generated.
- Scripts: `tools/ScaffoldProjectSubmodule.ps1` and `tools/scaffold-project-submodule.sh` must provide identical functionality while honoring the shared CLI contract in `ToolingGeneral.md`.
- Depend on git with submodule support, dotnet SDK 9.0.x, MDK2 templates 2.2.31, and Steam binaries detection (indirect via scaffold/build steps).
- For PB-script submodules, rely on `se-config.ini` / `se-config.local.ini` when invoking the MDK2 scaffolder so that `ProjectName.mdk.ini` / `ProjectName.mdk.local.ini` are seeded consistently (mixins continue to skip `.mdk` files).

## 4. CLI Contract

See `ToolingGeneral.md` for mandatory shared options. This tool documents only its additional flags below.

All other shared switches (dry-run, verbosity, help, summary, CI) are inherited without change, and `--debug` is a shorthand for `--verbose debug`.

| Purpose             | PowerShell               | Bash                       | Notes                                                   |
| ------------------- | ------------------------ | -------------------------- | ------------------------------------------------------- |
| Submodule name      | `-Name <string>`         | `--name <string>`          | Required; determines directory under `source/<type>/`.  |
| Submodule type      | `-Type <pbscript/mixin>` | `--type <pbscript\|mixin>` | Controls directory placement and build flow.            |
| Remote repository   | `-Repo <url>`            | `--repo <url>`             | Optional existing git repo to add as submodule.         |
| Branch              | `-Branch <name>`         | `--branch <name>`          | Branch to checkout after clone (default remote HEAD).   |
| Output directory    | `-Output <path>`         | `--output <path>`          | Override default `source/<type>/<ProjectName>`.         |
| Forward class names | `-ClassName <name>`      | `--class-name <name>`      | Repeatable; forwarded to project scaffolder (pbscript). |
| Add to solution     | `-AddSln <path>`         | `--add-sln <path>`         | When pbscript, add generated project to solution.       |
| Skip build          | `-NoBuild`               | `--no-build`               | Skip initial build (useful for mixin/no target yet).    |

**Inherited flags from Scaffold MDK2 Project** (applies when `--type pbscript`; flags are forwarded to the project scaffolder):

- `--class-name <name>` (repeatable) — forwarded.
- `--add-sln <path>` — forwarded.
- `--output <path>` — forwarded (defaults to `source/pbscript/<ProjectName>` if omitted).
- Future project-scaffolder flags — forwarded transparently when safe; unknown flags cause a validation error with `--help` guidance.

**Exit codes:** `0` = success; `1` = validation failure or unmet prerequisites; `2` = unexpected error; `3` = user-aborted (optional).

## 5. Workflow

1. Parse CLI, validate name/type, and collect project-scaffolder options (`--output`, repeated `--class-name`, `--add-sln`, etc.). Determine target path (`source/pbscript/ProjectFolder` or `source/mixin/ProjectFolder`). By default `ProjectFolder` equals `ProjectName`, yielding `source/<type>/ProjectName`, unless an existing repository layout dictates otherwise (for example when `--repo` is provided and already contains a different structure).
2. Inspect existing git configuration:
   - Ensure submodule entry absent; if present, warn and abort.
   - Prepare git commands for submodule addition (dry-run renders commands only).
3. Acquire project contents:
   - If `--repo` supplied, add submodule and update to specified branch.
   - Else, initialize empty directory and schedule `git submodule add` pointing to placeholder path (developer completes remote setup later).
4. Seed shared configuration: copy `.gitignore` and `.gitattributes` from the super-repo into the submodule when they are missing (respect future `--force` semantics if added).
5. Detect whether the submodule already contains an MDK project (e.g., `*.csproj`, `ProjectName.mdk.ini`). If not present, invoke Scaffold MDK2 Project with the collected options (passing `--type`, `--name`, `--output`, `--class-name`, `--add-sln`, etc.). When files exist, log the detection and synchronize configuration instead of regenerating.
6. Perform initial build unless `--no-build` or (for mixins) no build target exists. Capture output for reporting.
7. Post-creation tasks:
   - Stage submodule in super-repo, optionally stage generated files in submodule.
   - Provide instructions for initial commit/push (automatic commit optional, see open questions).
   - Update root solution via scaffolded project when PB script and `--add-sln` (or auto-detected solution) applies.
8. Summarize results, including git commands to run, build status, and next steps.

## 6. Configuration Handling

- Reuse config loading logic from Setup tool: `se-config.local.ini` overrides default for keys such as Steam path, minification, etc.
- When the submodule hosts a PB script, ensure `ProjectName.mdk.local.ini` contains only keys that differ from the template `ProjectName.mdk.ini`, consistent with the scaffold spec.
- When cloning repo with existing config, merge values carefully (prefer remote file, log differences).
- Copy shared `.gitignore` and `.gitattributes` from the super-repo unless the submodule already provides them; emit a warning when files exist and no future `--force` flag is supplied.

## 7. Normative Requirements

Use RFC 2119 terms. Keep each requirement atomic.

- The tool **MUST** add submodules using git plumbing (`git submodule add`) and handle idempotency (no duplicate entries).
- The tool **MUST** invoke **Scaffold MDK2 Project** for PB-script scaffolding; do not handcraft template output.
- The tool **MUST** keep PowerShell and Bash behaviorally identical and honor the shared CLI contract.
- The tool **MUST NOT** modify `ProjectName.mdk.ini` after creation; create it only if absent, and persist overrides to `ProjectName.mdk.local.ini`.
- The tool **MUST** seed only keys that differ from the effective configuration into `.mdk.local.ini` (diff-only writes) and add a generated header.
- The tool **MUST** refuse destructive operations on existing non-empty targets unless a future `--force` is explicitly provided.
- CI **MUST NOT** build SE solutions; CI runs format/lint only. Initial build is **local-only**.
- The tool **MUST** support `--debug` as an alias for `--verbose debug`.

## 8. Outputs

- Adds entry to `.gitmodules` and creates directory under `source/<type>/ProjectFolder`.
- Generates MDK2 project files, `.editorconfig`, and optional build artifacts. PB-script submodules additionally include `ProjectName.mdk.ini` and (when overrides exist) `ProjectName.mdk.local.ini`.
- Copies shared `.gitignore` and `.gitattributes` into the submodule when not already present.
- Prints summary with command suggestions (e.g., `git commit`, `git push`). Debug level logs include git/dotnet commands executed.

## 9. Failure Modes & Recovery

- Git failures (network, auth): report stderr, advise re-run once resolved, remove partial directories when safe.
- Scaffold tool failure: display underlying message, leave submodule working tree for manual fix, exit 1.
- Build failure: treat as non-fatal? (decision) — likely exit 1 while leaving files intact.
- Dry-run ensures no filesystem/git changes.

## 10. Validation

- Print tool version(s) via `--version` (or equivalent) in logs.
- Verify git prerequisites: `git` available; working tree clean or warn when staging will occur.
- Verify target path resolves to `source/<type>/<ProjectFolder>` (or overridden by `--output`); path does not already contain a conflicting submodule.
- If `--repo` provided: confirm remote is reachable and `git submodule add` would succeed (dry-run prints commands only).
- Ensure `.gitmodules` will contain an entry for the target path; for existing entries, validate it refers to the same URL/branch.
- For `--type pbscript`:
  - Verify `dotnet new --list` includes `Mal.Mdk2.ScriptTemplates` at `2.2.31`.
  - After scaffolding (or when onboarding an existing project), verify `ProjectName.mdk.ini` exists and `ProjectName.mdk.local.ini` contains only differing keys with a generated header.
- Confirm shared `.gitignore` and `.gitattributes` are present in the submodule (copied only when missing).
- Build step behaves as requested: runs locally unless `--no-build` or mixin without target; capture exit code and key output.
- Read-only rule enforced: no in-place edits to `.mdk.ini` after creation; only `.mdk.local.ini` is written when diffs exist.
- Summary includes: submodule path/URL, commands to run (`git submodule add`, `git commit`, `git push`), scaffolded files, and build status.
- Dry-run / CI: assert no filesystem or git changes were performed; commands are printed instead.

## 11. Acceptance Criteria

- Prerequisites satisfied: PowerShell 7.x, dotnet SDK 9.0.x, MDK2 templates 2.2.31 available via `dotnet new --list`.
- `.gitmodules` updated and submodule directory created under `source/<type>/ProjectFolder`.
- For PB-script: `ProjectName.mdk.ini` exists (created if absent) and `.mdk.local.ini` contains only differing keys with a generated header.
- Shared `.gitignore`/`.gitattributes` present (copied only when missing).
- Initial **local** build succeeds unless `--no-build`.
- Read-only rule respected: no in-place edits to `.mdk.ini` after creation.

## 12. Security & Permissions

- Use least privilege; do not require elevation.
- Do not log secrets or tokens at `info` level. Keep git/dotnet command lines but redact sensitive values.

## 13. Telemetry & Logging (optional)

- If telemetry is added later, document events, destinations, redaction rules; default to opt-in.

## 14. Open Questions / Future Enhancements

- Should the tool auto-commit submodule addition and optionally push (requires user identity check)?
- How to handle credential prompts in non-interactive contexts?
- Potential support for removing/renaming submodules.
- Should the tool support remote repository creation (e.g., GitHub) directly, and how would credentials/ownership be provided?

## 15. Change Log

> **Policy:** On every spec edit, append a new row **at the bottom** with date, summary, and approver (chronological top→bottom).

| Date       | Change                                                                                                                                                                                                      | Approved By |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-19 | Initial draft specification                                                                                                                                                                                 | geho        |
| 2025-09-19 | Clarified ProjectName/ProjectFolder semantics and PB-script-specific `.mdk` config handling                                                                                                                 | geho        |
| 2025-09-19 | Added pass-through project options, existing-project detection, shared config seeding, and remote-creation limitations                                                                                      | geho        |
| 2025-09-20 | Referenced ToolingGeneral shared CLI contract                                                                                                                                                               | geho        |
| 2025-09-27 | Aligned to template: added References & Preconditions; Normative Requirements; split Validation/Acceptance; Security & Telemetry; inherited flags from project scaffolder; exit codes; section renumbering. | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.                                                                                              | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                                                                                                                       | geho        |
| 2025-09-28 | Removed `${MODE}` echo from Section 10 Validation (orthogonal to scaffolding); retained git/dotnet and template checks.                                                                                     | geho        |
| 2025-09-28 | Standardized verbosity: added `--debug` alias note in Sections 4 and 7.                                                                                                                                     | geho        |
| 2025-10-02 | Normalized "Last updated" line formatting and resolved markdownlint findings.                                                                                                                               | geho        |
