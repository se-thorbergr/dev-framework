> Tone: second person, active, imperative; precise and concise.

# Environment Policy

This policy defines the supported development and build environment for the dev-framework project. Tooling (see specs under `docs/spec/tooling/`) must follow these requirements when guiding contributors.

## Supported Platforms

- Windows 10/11 with Steam-installed Space Engineers.
- Linux distributions capable of running dotnet SDK 9.0.x and PowerShell 7.x. Mixed setups (e.g., Space Engineers installed on Windows but exposed to Linux via shared storage) are supported when the `Bin64` directory is reachable.
- Additional platforms may be documented later; contributors should provide feedback through issues before deviating.

## Required Toolchain

- **dotnet SDK 9.0.x:** Provides Roslyn compiler and libraries required for MDK2 builds. Visual Studio is optional.
- **PowerShell 7.x:** Required on Windows; optional on Linux unless the developer intends to run the PowerShell version of tooling.
- **MDK2 templates (Mal.Mdk2.ScriptTemplates 2.2.31):** Installed via `dotnet new --install`.
- **Space Engineers Bin64:** The `binarypath` used by builds. Developers must ensure the folder is accessible.
- **Node.js + npm:** Required. Used by docs/config workflows (e.g., Prettier, markdownlint) and for optional Codex CLI. Tooling must detect existing installs before offering guided installation.

## Installation Guidance

- Surface package-manager flows first: `winget` on Windows and `apt` on Debian/Ubuntu. When running with `--auto-install`, tooling may execute these commands directly after confirming with the developer.
- Provide clear fallback steps when package managers are unavailable or declined:
  - Windows: list official Microsoft download links for dotnet/PowerShell MSIs and the `nvm-setup.exe` installer for Node.js. Remind developers to verify publisher information, digital signatures, and license terms before executing. For Bash tests (`bats`), winget is **not** available; prefer **WSL** (recommended), or **MSYS2** with `pacman`, or manual install per the bats-core installation guide (see https://bats-core.readthedocs.io/en/stable/installation.html).
  - Debian/Ubuntu: explain how to install from official repositories (`sudo apt update && sudo apt install ...`). If developers choose manual or third-party sources, log that they must maintain updates themselves.
- Always offer a “manage manually” option before automated actions so contributors can apply corporate tooling or existing installs.
- The setup spec (`docs/spec/tooling/SetupTooling.md`) governs interactive prompts and CLI overrides (`--auto-install`, `--notes-only`, etc.).

## Encoding & Unicode

- **Encoding:** Use UTF-8 for all text files and console I/O. Tooling should set UTF-8 where needed (PowerShell 7+: set `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $OutputEncoding = [System.Text.UTF8Encoding]::new($false)`; Bash: `export LANG=C.UTF-8; export LC_ALL=C.UTF-8`).
- **Normalization:** Normalize filenames and emitted text to **NFC**.
- **Paths:** Tooling-owned and generated paths **MUST** be ASCII-only. Unicode paths **MAY** be used only in explicitly whitelisted content areas (e.g., `docs/i18n/**`) with UTF-8 + NFC; disallow non-printing characters and emoji. Keep project names/namespaces ASCII.
- **CI enforcement:** Include a check that rejects non-ASCII paths outside whitelisted areas and flags disallowed characters.
- **Strings:** Follow the Coding Style policy: ASCII punctuation by default; Unicode may be used for player-visible UI text with ASCII fallbacks.

## Workspace mode (SE vs tooling)

The dev-framework runs in one of two modes:

- **`se`** — Space Engineers only. You only need .NET/C# + MDK2 locally. Docs/config linters and formatters may be skipped on your machine; CI still enforces them.
- **`tooling`** — Full local toolchain for contributors working on the framework itself.

**How the mode is chosen (precedence):**

1. `.devfw-mode.local` file (repo root) — developer override (**gitignored**)
2. `DEVFW_MODE` environment variable
3. `.devfw-mode` file — repository default (**committed**)
4. Heuristic (auto) — falls back to `se` for MDK-only repos

**Check your current mode:**

```bash
[ -f .devfw-mode.local ] && echo "mode: $(cat .devfw-mode.local) (local override)" \
  || [ -f .devfw-mode ] && echo "mode: $(cat .devfw-mode) (repo default)" \
  || echo "mode: auto (override with .devfw-mode or .devfw-mode.local)"
```

**Change the mode (repo-local):**

```bash
echo se > .devfw-mode        # or: echo tooling > .devfw-mode
git add .devfw-mode
```

To change only your local machine without committing, create `.devfw-mode.local` instead (this file is gitignored).

## Configuration Files

- `se-config.ini` lives in the super-repo root and mirrors the semantics of `ProjectName.mdk.ini`, including the core `[mdk]` section (`type`, `trace`, `minify`, `ignores`, `donotclean`) and any dev-framework extensions. Setup tooling ensures this file exists and treats it as the canonical default configuration.
- `se-config.local.ini` is gitignored, mirrors `ProjectName.mdk.local.ini`, and carries only the developer-specific overrides using the same section/key names plus helper paths such as `steam_path`, `game_path`. The example template includes the MDK defaults (`output=auto`, `binarypath=auto`) so new local files align with scaffolding; developers can remove or override keys as they customise their environment. Tooling should avoid adding extra keys beyond those defaults unless a non-default value is required.
- Developers may freely duplicate keys from the tracked template in their local file for clarity. Verification tooling warns (but does not fail) when duplicate values match the defaults.
- When PB-script projects are scaffolded, `se-config.ini` / `se-config.local.ini` act as templates for seeding missing `ProjectName.mdk.ini` / `ProjectName.mdk.local.ini`.
- The `[mdk]` section must stay aligned with the MDK2 Project Configuration Guide (`type`, `trace`, `minify`, `ignores`, `donotclean`); see <https://github.com/malforge/mdk2/wiki/MDK%C2%B2-Project-Configuration-Guide>.
- Developers may override paths via CLI (`--binary-path`, `--steam-path`, `--game-path`, `--output-path`) or by editing their local INI.

## Tooling Alignment

## Tooling Layers

| Policy      | Spec                        | Tool                                                                    |
| ----------- | --------------------------- | ----------------------------------------------------------------------- |
| Environment | ToolingGeneral.md           | All tooling                                                             |
| Environment | SetupTooling.md             | tools/Setup.ps1, tools/setup.sh                                         |
| Environment | ScaffoldMdk2Project.md      | tools/ScaffoldMdk2Project.ps1, tools/scaffold-mdk2-project.sh           |
| Environment | ScaffoldProjectSubmodule.md | tools/ScaffoldProjectSubmodule.ps1, tools/scaffold-project-submodule.sh |

- **Setup tooling** (`tools/Setup.ps1`, `tools/setup.sh`): prepares the super-repo environment, installs required SDKs, and ensures the root `se-config.ini` / `se-config.local.ini` templates exist (no per-project seeding).
- **MDK2 project scaffolding** (`tools/ScaffoldMdk2Project.ps1`, `tools/scaffold-mdk2-project.sh`): creates or updates standalone Programmable Block or mixin projects without touching git state.
- **Project submodule scaffolding** (`tools/ScaffoldProjectSubmodule.ps1`, `tools/scaffold-project-submodule.sh`): orchestrates git submodules and delegates project creation to the MDK2 scaffolder while wiring repository workflows.

- `tools/Setup.ps1` and `tools/setup.sh` must implement the behavior defined in `docs/spec/tooling/SetupTooling.md`.
- All tooling follows the shared CLI conventions defined in `docs/spec/tooling/ToolingGeneral.md`; tool-specific specs list only additional flags.
- Scaffold tooling (`docs/spec/tooling/ScaffoldMdk2Project.md`, `.../ScaffoldProjectSubmodule.md`) relies on the resolved configuration; developers should run setup before scaffolding projects.
- Policy changes require corresponding updates to specs and tooling implementations.

## Optional Components (Codex)

- Codex integration is optional. Setup tooling must prompt developers or respect CLI switches (`--setup-codex`, `--skip-codex`).
- Codex CLI is installed via npm into the repository (creating `node_modules/`); tooling must note that Node/npm are prerequisites and remind developers about licence terms from the Codex project and npm registry.
- Teams relying on Codex should document CI implications (e.g., checks that warn when Codex assets are missing).

## Maintenance

- Keep this policy aligned with current toolchain versions and supported platforms. When updates are required, adjust the specs and tooling in tandem.
- Contributors deviating from these requirements must document their changes and share lessons learned for potential policy updates.
