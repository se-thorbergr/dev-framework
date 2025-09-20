# dev-framework TODO Plan

## Priority 1 - Tooling foundation

### Governance
- Policy/spec alignment: review shared conventions, configs, and CLI contract.

### Shared Libraries
- ✅ Implement shared libraries (`DevFramework.Tooling.psm1`, `tooling.sh`) with CLI + text I/O helpers. (completed 2025-09-20)

### Setup
- Ensure setup tooling creates templates, persists helper paths, and adds licensing headers.

### Scaffolding
- Implement MDK2 scaffolder (CLI parity, ini seeding/diffing, class stubs, initial build).
- Implement submodule scaffolder (git plumbing, project delegation, build/commit guidance).

### Bootstrap & CI
- Improve bootstrap workflow (create PB/Mixin directories, copy `.editorconfig`, trigger initial build, enhance logging).
- Honor `--sln` override and support additional repo layouts.
- ✅ Provide validation hooks (pre-commit, GitHub Actions). Initial MDK config verifiers landed 2025-09-20.

### Other
- Respect Codex opt-in/out and document manual steps.
- Enforce dependency validation (MDK2 template, dotnet SDK 9, PowerShell 7, Steam path discovery).
- Keep `se-config.ini` / `se-config.local.ini` aligned with MDK2 defaults.
- Maintain appendix of MDK2 tool outputs.



## Priority 2 - Architecture refinement

- Consolidate legacy VIOS material into current OS documentation (`docs/arch/OS.core.md`, `docs/arch/README.md`, `docs/arch/VIOS.obsolete.md`).
- Define module/component boundaries and interactions, including data flow between Programmable Blocks and mixins.
- Clarify how submodules integrate with the super-repo build and deployment process.

## Priority 3 - Specifications

- Translate finalized architecture into spec documents outlining APIs, data contracts, and lifecycle expectations (`docs/spec/README.md`, future per-module specs).
- Capture acceptance criteria for scaffolded projects (directory layout, required files, coding standards).
- Describe testing and verification approach for PBscript/Mixin modules.

## Priority 4 - Policies

- Flesh out CodingStyle, Environment, and Workflow policies with actionable rules tied to tooling enforcement (`docs/policy/*.md`).
- Align `.editorconfig`, `.gitattributes`, and related configs with the written policies and dependency requirements (dotnet 9, PowerShell 7, MDK2 tooling).
- Reference policy touchpoints within README/GettingStarted to onboard contributors quickly.

## Priority 5 - CI Gates

- Identify mandatory checks (linting, formatting, build, unit/integration) derivable from policies and tooling.
- Sketch GitHub Actions/Git hooks pipeline steps and artifacts required for each gate.
- Plan rollout sequence for CI enforcement, starting with informational checks before gating merges.

## Supporting Documentation

- Document the purpose of the `codex/` directory and how AI prompts integrate with the workflow.

## APPENDIX A (mdk toolkit outputs and ProjectName.mdk.ini)

```bash
dotnet new mdk2pbscript -h
Programmable Block Script (MDK2) (C#)
Author: github.com/malware-dev/MDK-SE
Description: A script for the programmable block in the game Space Engineers by Keen Software House.

Usage:
  dotnet new mdk2pbscript [options] [template options]

Options:
  -n, --name <name>       The name for the output being created. If no name is specified, the name of the output directory is used.
  -o, --output <output>   Location to place the generated output.
  --dry-run               Displays a summary of what would happen if the given command line were run if it would result in a template creation.
  --force                 Forces content to be generated even if it would change existing files.
  --no-update-check       Disables checking for the template package updates when instantiating a template.
  --project <project>     The project that should be used for context evaluation.
  -lang, --language <C#>  Specifies the template language to instantiate.
  --type <project>        Specifies the template type to instantiate.

Template options:
   (No options)

```

```bash
dotnet new mdk2mixin -h
MDK Mixin (MDK2) (C#)
Author: github.com/malware-dev/MDK-SE
Description: A mixin extension for MDK2 projects.

Usage:
  dotnet new mdk2mixin [options] [template options]

Options:
  -n, --name <name>       The name for the output being created. If no name is specified, the name of the output directory is used.
  -o, --output <output>   Location to place the generated output.
  --dry-run               Displays a summary of what would happen if the given command line were run if it would result in a template creation.
  --force                 Forces content to be generated even if it would change existing files.
  --no-update-check       Disables checking for the template package updates when instantiating a template.
  --project <project>     The project that should be used for context evaluation.
  -lang, --language <C#>  Specifies the template language to instantiate.
  --type <project>        Specifies the template type to instantiate.

Template options:
   (No options)

```

ProjectName.mdk.ini:

```ini
; This file is project specific and should be checked in to source control.

[mdk]
; This is a programmable block script project.
; You should not change this.
type=programmableblock

; Toggle trace (on|off) (verbose output)
trace=off

; What type of minification to use (none|trim|stripcomments|lite|full)
; none: No minification
; trim: Removes unused types (NOT members).
; stripcomments: trim + removes comments.
; lite: stripcomments + removes leading/trailing whitespace.
; full: lite + renames identifiers to shorter names.
minify=none

; A list of files and folder to ignore when creating the script.
; This is a comma separated list of glob patterns.
; See https://code.visualstudio.com/docs/editor/glob-patterns
ignores=obj/**/*,MDK/**/*,**/*.debug.cs

```

ProjectName.local.mdk.ini:

```ini
; This file is _local_ to your machine and should not be checked in to source control.

[mdk]
; Where to output the script to (auto|specific path)
output=auto
; Override the default binary path (auto|specific path)
binarypath=auto
```
