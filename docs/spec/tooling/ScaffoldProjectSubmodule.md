# Scaffold Project Submodule Specification

_Last updated: 2025-09-19 - Owner: geho_

## 1. Scope

- Automate creation or onboarding of Programmable Block script or mixin submodules within the dev-framework super-repo.
- Handle git submodule plumbing, MDK2 project scaffolding (via Scaffold MDK2 Project tool), initial build, and optional commit guidance.
- Out of scope: remote repository creation (GitHub API), CI configuration, or enforcing team workflow approvals.

## 2. Shared Responsibilities

- `ProjectName` refers to the `--name` value used for namespaces, csproj files, and MDK configuration (`ProjectName.mdk.ini`). `ProjectFolder` refers to the target directory where files are generated.
- Scripts: `tools/ScaffoldProjectSubmodule.ps1` and `tools/scaffold-project-submodule.sh` must provide identical functionality while honoring the shared CLI contract in `ToolingGeneral.md`.
- Depend on git with submodule support, dotnet SDK 9.0.\*, MDK2 templates 2.2.31, and Steam binaries detection (indirect via scaffold/build steps).
- For PB-script submodules, rely on `se-config.ini` / `se-config.local.ini` when invoking the MDK2 scaffolder so that `ProjectName.mdk.ini` / `ProjectName.mdk.local.ini` are seeded consistently (mixins continue to skip `.mdk` files).

## 3. CLI Contract

See `ToolingGeneral.md` for mandatory shared options. This tool documents only its additional flags below.

All other shared switches (dry-run, verbosity, help, summary, CI) are inherited without change.

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

## 4. Workflow

1. Parse CLI, validate name/type, and collect project-scaffolder options (`--output`, repeated `--class-name`, `--add-sln`, etc.). Determine target path (`source/pbscript/ProjectFolder` or `source/mixin/ProjectFolder`). By default `ProjectFolder` equals `ProjectName`, yielding `source/<type>/ProjectName`, unless an existing repository layout dictates otherwise (for example when `--repo` is provided and already contains a different structure).
2. Inspect existing git configuration:
   - Ensure submodule entry absent; if present, warn and abort.
   - Prepare git commands for submodule addition (dry-run renders commands only).
3. Acquire project contents:
   - If `--repo` supplied, add submodule and update to specified branch.
   - Else, initialise empty directory and schedule `git submodule add` pointing to placeholder path (developer completes remote setup later).
4. Seed shared configuration: copy `.gitignore` and `.gitattributes` from the super-repo into the submodule when they are missing (respect future `--force` semantics if added).
5. Detect whether the submodule already contains an MDK project (e.g., `*.csproj`, `ProjectName.mdk.ini`). If not present, invoke Scaffold MDK2 Project with the collected options (passing `--type`, `--name`, `--output`, `--class-name`, `--add-sln`, etc.). When files exist, log the detection and synchronize configuration instead of regenerating.
6. Perform initial build unless `--no-build` or (for mixins) no build target exists. Capture output for reporting.
7. Post-creation tasks:
   - Stage submodule in super-repo, optionally stage generated files in submodule.
   - Provide instructions for initial commit/push (automatic commit optional, see open questions).
   - Update root solution via scaffolded project when PB script and `--add-sln` (or auto-detected solution) applies.
8. Summarise results, including git commands to run, build status, and next steps.

## 5. Configuration Handling

- Reuse config loading logic from Setup tool: `se-config.local.ini` overrides default for keys such as Steam path, minification, etc.
- When the submodule hosts a PB script, ensure `ProjectName.mdk.local.ini` contains only keys that differ from the template `ProjectName.mdk.ini`, consistent with the scaffold spec.
- When cloning repo with existing config, merge values carefully (prefer remote file, log differences).
- Copy shared `.gitignore` and `.gitattributes` from the super-repo unless the submodule already provides them; emit a warning when files exist and no future `--force` flag is supplied.

## 6. Outputs

- Adds entry to `.gitmodules` and creates directory under `source/<type>/ProjectFolder`.
- Generates MDK2 project files, `.editorconfig`, and optional build artifacts. PB-script submodules additionally include `ProjectName.mdk.ini` and (when overrides exist) `ProjectName.mdk.local.ini`.
- Copies shared `.gitignore` and `.gitattributes` into the submodule when not already present.
- Prints summary with command suggestions (e.g., `git commit`, `git push`). Debug level logs include git/dotnet commands executed.

## 7. Error Handling & Recovery

- Git failures (network, auth): report stderr, advise re-run once resolved, remove partial directories when safe.
- Scaffold tool failure: display underlying message, leave submodule working tree for manual fix, exit 1.
- Build failure: treat as non-fatal? (decision) — likely exit 1 while leaving files intact.
- Dry-run ensures no filesystem/git changes.

## 8. Validation & Testing

- Unit tests mocking git interactions (validate command composition, path resolution).
- Integration tests in temporary repo verifying submodule addition and scaffold invocation (dry-run and real modes).
- Manual scenarios: cloning existing repo, creating new local submodule without remote, mixin flow skipping build.

## 9. Open Questions / Future Enhancements

- Should the tool auto-commit submodule addition and optionally push (requires user identity check)?
- How to handle credential prompts in non-interactive contexts?
- Potential support for removing/renaming submodules.
- Should the tool support remote repository creation (e.g., GitHub) directly, and how would credentials/ownership be provided?

## 10. Change Log

| Date       | Change                                                                                                                 | Approved By |
| ---------- | ---------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-19 | Initial draft specification                                                                                            | geho        |
| 2025-09-19 | Clarified ProjectName/ProjectFolder semantics and PB-script-specific `.mdk` config handling                            | geho        |
| 2025-09-19 | Added pass-through project options, existing-project detection, shared config seeding, and remote-creation limitations | geho        |
| 2025-09-20 | Referenced ToolingGeneral shared CLI contract                                                                          | geho        |
