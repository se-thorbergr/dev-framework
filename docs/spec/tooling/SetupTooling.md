> Tone: normative (MUST/SHOULD/MAY); use second person only in step-by-step instructions.

# Setup Tooling Specification

Last updated: 2025-09-30 - Owner: geho

## 1. Scope

- Prepare a fresh clone of the dev-framework for development across Windows and Linux, including mixed setups where Space Engineers assets may reside on one OS but are shared to the other.
- Enforce the Environment Policy when validating platforms, dependencies, and configuration.
- Detect or collect platform-specific locations for the Space Engineers `Bin64` binaries (the build dependency) via CLI options or prompts, with optional helper inputs for Steam/game directories.
- Prefer secure, package-managed installations of required runtimes while allowing developer-managed (user-/project-local) installs with clear maintenance warnings. Installation guidance MUST cover Windows (`winget`, official MSIs) and Debian/Ubuntu (`apt`).
- Verify and assist with installation of core dependencies: PowerShell 7.x, dotnet SDK 9.0.x (Roslyn included), MDK2 templates 2.2.31, and (optionally) Codex tooling when the developer opts in.
- Offer guidance for installing Node.js and npm when Codex setup is requested, presenting manual/self-managed installation before automated options.
- Ensure the super-repo configuration templates (`se-config.ini`, `se-config.local.ini`) exist and ensure solution scaffolding exists (`.sln`).
- **Execution modes:**
  - **Local:** full setup flow is permitted (prompts/installers allowed under flags); SE builds occur **only locally**.
  - **CI/GitHub:** non-interactive checks only — **no prompts, no installs, no persistence, no SE builds**; emit annotations and summary.
- **Out of scope:** provisioning CI infrastructure, remote repository automation, or enforcing per-submodule workflow (delegated to other tooling).

## 1.1 References

- Spec Authoring Policy: `docs/policy/SpecAuthoring.md`
- Spec Template (SoT): `docs/spec/tooling/_template.md` (Last updated: 2025-09-28)
- Environment Policy: `docs/policy/Environment.md`
- Workflow Policy: `docs/policy/Workflow.md`
- Coding Style Policy: `docs/policy/CodingStyle.md`
- Shared CLI contract: `docs/spec/tooling/ToolingGeneral.md`

## 2. Preconditions & Assumptions

- Required versions: PowerShell 7.x; dotnet SDK 9.0.x; MDK2 templates 2.2.31.
- Supported OS: Windows and Debian/Ubuntu Linux.
- Assumes Steam and Space Engineers are installed on at least one OS; cross-OS access to `Bin64` path may be used.
- Network access for package managers (`winget`, `apt`) when `--auto-install` is used.
- Permissions: ability to run package managers or installers when chosen.

## 3. Shared Responsibilities

- `ProjectName`: value supplied via `--name`/`-Name`; used for naming config files and directories.
- `ProjectFolder`: resolved output directory for generated or updated artifacts.

- Behavior follows the requirements documented in `docs/policy/Environment.md`.
- Supported runtimes: PowerShell 7.x (`Setup.ps1`) and Bash (`setup.sh`) with equivalent CLI surface and behavior (see `ToolingGeneral.md` for shared options).
- Requires dotnet CLI 9.0.x with `Mal.Mdk2.ScriptTemplates` package version 2.2.31 available for `dotnet new`.
- Optional Node.js + npm is required only when the developer opts into Codex CLI setup; the tooling must detect existing installations before offering automated install flows.
- Configuration keys follow MDK2 conventions: for PB scripts, `ProjectName.mdk.ini`/`ProjectName.mdk.local.ini` capture build settings, where `binarypath` identifies the Space Engineers `Bin64` directory. Global overrides live in `se-config.ini`/`se-config.local.ini` using optional helper keys `steam_path` (Steam installation root) and `game_path` (Space Engineers install root) to derive `binarypath` when it remains `auto`.
- Reads/writes only the root-level `se-config.ini` and `se-config.local.ini` templates plus the solution file denoted by CLI or auto-detection; per-project `.mdk` files are managed by the scaffolding tooling.

## 4. CLI Contract

See `ToolingGeneral.md` for mandatory shared options. This tool documents only its additional flags below.

All other shared switches (dry-run, verbosity, help, summary, CI) are inherited without change, and `--debug` is a shorthand for `--verbose debug`.

| Purpose              | PowerShell           | Bash                   | Notes                                                         |
| -------------------- | -------------------- | ---------------------- | ------------------------------------------------------------- |
| Config file override | `-Config <path>`     | `--config <path>`      | Defaults to `./se-config.local.ini` when present.             |
| Auto install         | `-AutoInstall`       | `--auto-install`       | Attempt package-manager installs without prompting.           |
| Notes-only mode      | `-NotesOnly`         | `--notes-only`         | Emit diagnostics only; implies dry run and disables installs. |
| Binary path override | `-BinaryPath <path>` | `--binary-path <path>` | Absolute Space Engineers `Bin64` path.                        |
| Steam path helper    | `-SteamPath <path>`  | `--steam-path <path>`  | Optional helper for discovery.                                |
| Game path helper     | `-GamePath <path>`   | `--game-path <path>`   | Optional helper for discovery.                                |
| Output path          | `-OutputPath <path>` | `--output-path <path>` | Persist MDK `[mdk].output` override (mirrors local config).   |
| Solution file        | `-Sln <path>`        | `--sln <path>`         | Override default `<repo-name>.sln`.                           |
| Force Codex setup    | `-SetupCodex`        | `--setup-codex`        | Skip prompt and run Codex bootstrap.                          |
| Skip Codex setup     | `-SkipCodex`         | `--skip-codex`         | Bypass Codex bootstrap entirely.                              |

**Exit codes:** `0` = success; `1` = validation failure or unmet prerequisites; `2` = unexpected error; `3` = user-aborted (optional).

## 5. Workflow

> **Execution-mode SoT:** Local vs CI/GitHub behavior is authoritative in `.ai/policies/core.yaml` → `modes`. This spec mirrors the summary only.

### Local vs CI/GitHub behavior matrix

| Area               | Local (dev)                                      | CI/GitHub Actions                                                 |
| ------------------ | ------------------------------------------------ | ----------------------------------------------------------------- |
| Installs           | Allowed via `--auto-install` or prompts          | **Forbidden**                                                     |
| Prompts            | Allowed                                          | **None** (non-interactive)                                        |
| SE build           | Allowed (local-only)                             | **Forbidden**                                                     |
| Linters/formatters | Optional                                         | **Required**                                                      |
| Bin64 persistence  | May persist to `se-config.local.ini` (diff-only) | **Not applicable** (SE not present on CI runners); skip discovery |
| Codex setup        | Optional (`--setup-codex` / `--skip-codex`)      | **Not used**                                                      |

1. Parse CLI arguments, resolve forcing switches (`--notes-only`, `--auto-install`, `--setup-codex`, `--skip-codex`), and load configuration sources (default then local overrides).
2. Determine the effective `binarypath`:
   - If `--binary-path` supplied, trust it (validate existence when possible).
   - Else if `se-config.local.ini` contains a non-`auto` `binarypath`, reuse it.
   - Otherwise attempt auto-detection using helper values (`steam_path`, `game_path`) or common install locations per OS.
   - If unresolved and `--notes-only` inactive, prompt the developer to provide the Bin64 path explicitly; offer optional prompts for Steam/game directories only to assist discovery.
3. Validate runtime dependencies:
   - Confirm PowerShell 7.x (on Windows and Linux as needed), dotnet SDK 9.0.x (Roslyn included), and MDK2 template package availability.
   - When dependencies are missing, surface OS-specific guidance:
     - **Windows:** Prefer `winget install` commands when `winget` exists. When `--auto-install` is active, run `winget` automatically (surfacing license text). If `winget` is unavailable or declined, provide direct links to the official Microsoft MSI installers and remind the developer to verify signatures and publisher information before running the installer.
     - **Debian/Ubuntu:** Recommend `sudo apt update && sudo apt install <package>` commands. Under `--auto-install`, execute the `apt` commands (prompting for sudo confirmation when necessary). When `--notes-only`, output the commands without execution.
     - For the MDK2 template, use `dotnet new --install Mal.Mdk2.ScriptTemplates::2.2.31`. Honor `--auto-install` by executing the command; otherwise prompt (or note-only).
   - Always present the “manage manually” option first when prompting so developers can rely on existing corporate tooling. Record a security reminder that manual installs require the developer to maintain updates.
   - `--notes-only` prints detection results and remediation steps without executing commands or modifying the system. Record explicitly that `--notes-only` prevented side effects (include in summary).
4. Ensure configuration files:
   - If `se-config.ini` is missing, warn and restore the tracked version when possible (or emit guidance under `--notes-only`).
   - If `se-config.local.ini` is missing and not `--notes-only`, copy `docs/se-config.local.example.ini` verbatim. The template includes the MDK defaults (`output=auto`, `binarypath=auto`) so new local files match scaffolded projects; tooling must not append any extra keys beyond the template or explicit overrides. `--notes-only` prints the command/path the developer should create manually.
   - Update or confirm `[Paths]` (`steam_path`, `game_path`) whenever CLI arguments, interactive discovery, or helper detection produce values. Persist only the keys that changed, unless running with `--notes-only`/`--dry-run`, while avoiding overwriting explicit user entries without confirmation.
   - When persisting a resolved `binarypath`, `output`, or other `[mdk]` overrides, write only the specific keys whose values differ from `se-config.ini`. In `--notes-only`, report the value but do not persist.
5. Workspace setup:
   - Determine target solution file from `--sln` or default `<repo-name>.sln`. Create with `dotnet new sln` when absent (respect dry-run/notes-only restrictions).
   - Drive Codex tooling setup:
     - Honor `--skip-codex` by logging that Codex setup was skipped and exit the Codex branch early.
     - Detect existing Node.js and npm binaries. When missing (or outdated), present options in this order: (a) developer manages installation manually; (b) Windows `winget install OpenJS.NodeJS.LTS`; (c) Windows fallback to the official `nvm-setup.exe` installer (with security/license reminder); (d) Debian/Ubuntu `sudo apt install nodejs npm`. `--auto-install` executes the winget/apt commands automatically when chosen. Always remind the developer to review licences and verify download signatures when invoking installers.
     - Once Node.js and npm are available and the developer opts in (by prompt or `--setup-codex`), install Codex CLI locally using `npm install --no-save codex-cli` from the repo root. This creates or refreshes the `node_modules/` directory (already ignored by git); no `package.json` is created. Expose how to run the CLI via `npx codex ...`.
     - Under `--notes-only`, list the detection results, install commands, and expected npm invocation without executing them. When the developer declines Codex setup, record the decision and continue.
6. Summarize actions, outstanding manual steps (including security warnings for manual installs), and dependency status. Exit non-zero when mandatory prereqs remain unresolved.
7. `--dry-run` prints intended mutations and install commands without execution. `--notes-only` enforces dry-run semantics plus disables prompts, providing purely informational output.

## 6. Configuration Handling

- Global config files maintain the same `[mdk]` section as MDK2 templates (`type`, `trace`, `minify`, `ignores`, `donotclean`) and must stay in lockstep with the template schema.
  - Reference: <https://github.com/malforge/mdk2/wiki/MDK%C2%B2-Project-Configuration-Guide>.
  - Dev-framework extensions live under `[Paths]` (`steam_path`, `game_path`). Local `output`/`binarypath` overrides stay in the developer's `se-config.local.ini` `[mdk]` section per MDK2 guidance.
- Resolution order: CLI arguments -> local override (`se-config.local.ini`) -> default template (`se-config.ini`) -> built-in defaults. Validation loads both configuration files, applying local overrides on top of the tracked template before enforcing required keys.
- During validation runs the tooling should flag unknown sections/keys so schema drift is caught early; deviations require spec updates before implementation continues. When a local value duplicates the template value (including the MDK defaults that ship in the example template), issue a warning instead of failing the run. Tooling should persist only keys whose values change from the effective merged configuration, including `output` overrides supplied via CLI.
- When `binarypath` remains `auto`, the resolved absolute path is echoed for reference but not written; only explicit overrides provided via CLI or prompts are persisted into `se-config.local.ini`. In `--notes-only`, the path is reported without any persistence regardless of override status.
- Per-project `*.mdk.ini` files are read-only by policy; never write or modify them.

## 7. Normative Requirements

Use RFC 2119 terms. Keep each requirement atomic.

- The tool **MUST** prefer secure, package-managed installs; always offer a manual path first.
- The tool **MUST** detect existing installations before offering automated installs.
- The tool **MUST** resolve and validate `binarypath`; if unresolved, prompt or emit remedial guidance.
- The tool **MUST NOT** write to read-only config types (e.g., `*.mdk.ini`).
- The tool **MUST** persist only keys that differ from the effective merged configuration.
- The tool **SHOULD** support cross-OS setups where `Bin64` resides on the other OS.
- In `--ci` mode, the tool **MUST NOT** prompt, **MUST NOT** attempt installs, and **MUST NOT** persist any changes.
- In `--ci` mode, the tool **MUST** emit CI-friendly annotations and **MUST** exit non-zero when mandatory prerequisites are missing; otherwise exit 0.
- In `--ci` mode, Codex setup **MUST NOT** run.
- CI **MUST NOT** build SE solutions; CI runs format/lint only. Build is local-only.
- The tool **MUST** support `--debug` as an alias for `--verbose debug`.

## 8. Outputs

- Potential file touch points:
  - `se-config.ini` / `se-config.local.ini` (creation or updates limited to keys that represent actual overrides plus helper `[Paths]` values).
  - Solution file specified by `--sln`.
  - Optional Codex tooling directories/files when setup proceeds (local `node_modules/` and npm cache entries remain git-ignored).
- Console output respects verbosity while ensuring dependency guidance, security warnings, and Codex prompts are visible at `info`. Debug output includes executed commands and resolved path diagnostics.

## 9. Failure Modes & Recovery

- Missing or invalid `binarypath`: prompt for manual input when interactive; otherwise instruct the developer to supply `--binary-path` or update `se-config.local.ini`. Auto-detection failures should list attempted locations and suggest using helper options (`--steam-path`, `--game-path`).
- Missing dependency with auto-install declined/failing (or `--notes-only` active): emit specific remediation commands per OS and exit 1 once checks complete.
- Path resolution failures: provide contextual messages (e.g., "Could not locate Steam under &lt;paths&gt;") for helper lookups and reiterate manual input requirements.
- dotnet/winget/apt/npm command failures: surface exit codes/output, preserve existing files, and advise re-run after problem is addressed. Automated install attempts must report lack of privileges and recommend re-running with elevation or manual install.
- Unexpected exceptions: log stack trace in debug mode and guide the developer to re-run with `--verbose debug` if not already enabled.

## 10. Validation

- Print effective configuration sources and the merged result (template + local).
- Verify `binarypath` exists and contains Space Engineers `Bin64` binaries.
- Verify required runtimes: `pwsh` 7.x, `dotnet` 9.0.x; show versions detected.
- Verify `dotnet new --list` includes `Mal.Mdk2.ScriptTemplates` at `2.2.31` (template available for scaffolding).
- If Codex opted in: verify `node`/`npm` availability and `npx codex --version`.
- Confirm `se-config.ini` and `se-config.local.ini` exist with expected sections.
- Ensure no writes were attempted to read-only types (`*.mdk.ini`).
- On `--notes-only`, assert no side effects occurred; commands are printed, not executed.
- In `--ci`, **skip Bin64 discovery** entirely; set summary `detected.binarypath = null` with reason "not applicable in CI" and **do not fail** due to missing SE.

## 11. Acceptance Criteria

- `binarypath` is resolved and recorded (or reported) correctly.
- Dependencies are validated or installed per flags; missing deps produce actionable guidance.
- Security warnings are logged when manual installs are chosen.
- Codex CLI is available when requested.
- Exit code reflects the final state.
- In `--ci`, success **does not require** a resolved `binarypath`; acceptance is based on config shape and prerequisite checks.

## 12. Security & Permissions

- Use least privilege; do not require elevation unless the developer chooses an install path that needs it.
- Do not log secrets or sensitive paths; keep logs at `info` free of tokens.

## 13. Telemetry & Logging (optional)

- If telemetry is added later, document events, destinations, and redaction; default to opt-in.

## 14. Open Questions / Future Enhancements

### Resolved decisions

- Package manager support remains scoped to winget (Windows) and Debian/Ubuntu apt as of 2025-10-02; revisit only if new environments require it.

### Future enhancements

- Opportunity to emit structured JSON summary for future automation pipelines.

## 15. Change Log

> **Policy:** On every spec edit, append a new row **at the bottom** with date, summary, and approver (chronological top→bottom).

| Date       | Change                                                                                                                      | Approved By |
| ---------- | --------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-19 | Initial draft specification                                                                                                 | geho        |
| 2025-09-19 | Documented interactive/automatic install behavior                                                                           | geho        |
| 2025-09-19 | Added `--notes-only` flag and guidance expectations                                                                         | geho        |
| 2025-09-19 | Clarified platform/path handling, solution override, and Codex opt-in                                                       | geho        |
| 2025-09-19 | Documented package-manager preference and manual install warnings                                                           | geho        |
| 2025-09-19 | Prioritized binarypath resolution before helper path discovery                                                              | geho        |
| 2025-09-19 | Linked behavior back to Environment Policy                                                                                  | geho        |
| 2025-09-19 | Clarified PB-script-specific handling of ProjectName.mdk\*.ini and mixin exclusions                                         | geho        |
| 2025-09-20 | Documented winget/MSI and apt install flows plus Codex npm bootstrap with Node guidance                                     | geho        |
| 2025-09-20 | Clarified se-config template handling scope (root-only) and removed per-project writes                                      | geho        |
| 2025-09-20 | Referenced ToolingGeneral shared CLI contract                                                                               | geho        |
| 2025-09-20 | Documented ProjectName/ProjectFolder terminology                                                                            | geho        |
| 2025-09-20 | Clarified minimal local config overlay, duplicate-value warnings, and validation order                                      | geho        |
| 2025-09-26 | Align to template: added sections, renumbered headings, normalized MDK2 naming; added changelog policy note.                | geho        |
| 2025-09-28 | Added Spec Template (SoT) reference to Section 1.1; aligned with Spec Authoring Policy; no behavioral changes.              | geho        |
| 2025-09-28 | Added Spec Authoring Policy reference to Section 1.1.                                                                       | geho        |
| 2025-09-28 | Removed `${MODE}` echo from Section 10 Validation (orthogonal to Setup Tooling); no behavioral changes.                     | geho        |
| 2025-09-28 | Standardized verbosity: added `--debug` alias note in Sections 4 and 7.                                                     | geho        |
| 2025-09-30 | Clarify Local vs CI split: scope note, workflow matrix, and CI guardrails in Section 7; no behavioral change to local flow. | geho        |
| 2025-09-30 | Added SoT pointer in Section 5 to `.ai/policies/core.yaml → modes`.                                                         | geho        |
| 2025-10-02 | Normalized "Last updated" line formatting and resolved markdownlint findings.                                               | geho        |
| 2025-10-02 | Documented Section 14 decision on package manager scope and noted JSON summary enhancement as future work.                  | geho        |
