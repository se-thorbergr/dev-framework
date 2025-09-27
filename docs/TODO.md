# dev-framework TODO Plan

> Status reset (2025-09-24): Previous completion marks may be invalid due to broken tooling setup. Treat previously completed items as **unfinished**.

**Current phase focus:** Governance → Policy/spec alignment: review shared conventions, configs, and CLI contract.

## Priority 1 — Tooling foundation (governance, policies, minimal CI)

### Governance

- Policy/spec alignment: review shared conventions, configs, and CLI contract.

### Policies (moved up)

- Flesh out CodingStyle, Environment, and Workflow policies with rules enforceable by tooling (`docs/policy/*.md`).
- Align `.editorconfig`, `.gitattributes`, and dependency requirements (dotnet 9, PowerShell 7, MDK2 tooling).

### Shared Libraries

- Implement shared libraries (`DevFramework.Tooling.psm1`, `tooling.sh`) with CLI + text I/O helpers. (re-opened)

### Setup

- Ensure setup tooling creates templates, persists helper paths, and adds licensing headers. (re-opened)

### Minimal CI gates (moved up)

- CI runs (informational first): **format check** and **lint check** in CI; **build is local-only** (SE game not available in CI).
- Rollout: start info-only, then enforce once green on default branch.
- **TODO:** Flip CI from info-only → enforcing (**format/lint only**) once stability criteria are met (e.g., 7 consecutive green PRs on default). Update `.ai/workflows/code.yaml` and announce in changelog.

### Other

- **Optional:** Add `.ai/specs/adapter.yaml` (Agent adapter checklist) to guide external LLM runners: load core.yaml, resolve ${MODE}, enforce staged-only edits, respect read-only INI/.mdk.ini, execute scoped workflows, produce unified diffs, honor comment-levels.
- Respect Codex opt-in/out and document manual steps.
- Enforce dependency validation (MDK2 template, dotnet SDK 9, PowerShell 7, Steam path discovery).
- Keep `se-config.ini` / `se-config.local.ini` aligned with MDK2 defaults.
- Maintain appendix of MDK2 tool outputs.

## Priority 2 — Setup, Scaffolding & Bootstrap

### Setup (execution-first)

- Finalize setup flow (idempotent, detects prerequisites, clear error messages).
- Verify environment detection (dotnet SDK, MDK2 path, Steam path) and persist helper paths.
- Generate/update templates and licensing headers as part of setup.
- **Optional helper:** `devfw mode [se|tooling|auto]` to read/write `.devfw-mode` / `.devfw-mode.local`, print current status, and safely set mode (CI-safe).

### Scaffolding

- Implement MDK2 scaffolder (CLI parity, ini seeding/diffing, class stubs, initial build).
- Implement submodule scaffolder (git plumbing, project delegation, build/commit guidance).

### Bootstrap

- Create PB/Mixin directories, copy `.editorconfig`, trigger initial build, enhance logging.
- Honor `--sln` override and support additional repo layouts.

## Priority 3 — Architecture refinement

- Consolidate legacy VIOS material into current OS documentation (`docs/arch/OS.core.md`, `docs/arch/README.md`, `docs/arch/VIOS.obsolete.md`).
- Define module/component boundaries and interactions, including data flow between Programmable Blocks and mixins.
- Clarify how submodules integrate with the super-repo build and deployment process.

## Priority 4 — Specifications

- Translate finalized architecture into spec documents outlining APIs, data contracts, and lifecycle expectations (`docs/spec/README.md`, future per-module specs).
- Capture acceptance criteria for scaffolded projects (directory layout, required files, coding standards).
- Describe testing and verification approach for PBscript/Mixin modules.

## Priority 5 - CI Gates (full)

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
