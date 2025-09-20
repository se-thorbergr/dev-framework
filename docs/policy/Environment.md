# Environment Policy

This policy defines the supported development and build environment for the dev-framework project. Tooling (see specs under `docs/spec/tooling/`) must follow these requirements when guiding contributors.

## Supported Platforms

- Windows 10/11 with Steam-installed Space Engineers.
- Linux distributions capable of running dotnet SDK 9.0._ and PowerShell 7._. Mixed setups (e.g., Space Engineers installed on Windows but exposed to Linux via shared storage) are supported when the `Bin64` directory is reachable.
- Additional platforms may be documented later; contributors should provide feedback through issues before deviating.

## Required Toolchain

- **dotnet SDK 9.0.\*:** Provides Roslyn compiler and libraries required for MDK2 builds. Visual Studio is optional.
- **PowerShell 7.\*:** Required on Windows; optional on Linux unless the developer intends to run the PowerShell version of tooling.
- **MDK2 templates (Mal.Mdk2.ScriptTemplates 2.2.31):** Installed via `dotnet new --install`.
- **Space Engineers Bin64:** The `binarypath` used by builds. Developers must ensure the folder is accessible.
- **Node.js + npm (optional):** Only required when the developer opts into Codex CLI setup. Tooling must detect existing installs before offering guided installation.

## Installation Guidance

- Surface package-manager flows first: `winget` on Windows and `apt` on Debian/Ubuntu. When running with `--auto-install`, tooling may execute these commands directly after confirming with the developer.
- Provide clear fallback steps when package managers are unavailable or declined:
  - Windows: list official Microsoft download links for dotnet/PowerShell MSIs and the `nvm-setup.exe` installer for Node.js. Remind developers to verify publisher information, digital signatures, and licence terms before executing.
  - Debian/Ubuntu: explain how to install from official repositories (`sudo apt update && sudo apt install ...`). If developers choose manual or third-party sources, log that they must maintain updates themselves.
- Always offer a “manage manually” option before automated actions so contributors can apply corporate tooling or existing installs.
- The setup spec (`docs/spec/tooling/SetupTooling.md`) governs interactive prompts and CLI overrides (`--auto-install`, `--notes-only`, etc.).

## Configuration Files

- `se-config.ini` lives in the super-repo root and mirrors the semantics of `ProjectName.mdk.ini`, including the core `[mdk]` section (`type`, `trace`, `minify`, `ignores`, `donotclean`) and any dev-framework extensions. Setup tooling ensures this file exists.
- `se-config.local.ini` is gitignored, mirrors `ProjectName.mdk.local.ini`, and carries developer-specific overrides using the same section/key names plus helper paths such as `steam_path`, `game_path`.
- When PB-script projects are scaffolded, `se-config.ini` / `se-config.local.ini` act as templates for seeding missing `ProjectName.mdk.ini` / `ProjectName.mdk.local.ini`.
- The `[mdk]` section must stay aligned with the MDK² Project Configuration Guide (`type`, `trace`, `minify`, `ignores`, `donotclean`); see <https://github.com/malforge/mdk2/wiki/MDK%C2%B2-Project-Configuration-Guide>.
- Developers may override paths via CLI (`--binary-path`, `--steam-path`, `--game-path`) or by editing their local INI.

## Tooling Alignment

## Tooling Layers

| Policy | Spec | Tool |
| ------ | ---- | ---- |
| Environment | ToolingGeneral.md | All tooling |
| Environment | SetupTooling.md | tools/Setup.ps1, tools/setup.sh |
| Environment | ScaffoldMdk2Project.md | tools/ScaffoldMdk2Project.ps1, tools/scaffold-mdk2-project.sh |
| Environment | ScaffoldProjectSubmodule.md | tools/ScaffoldProjectSubmodule.ps1, tools/scaffold-project-submodule.sh |

- **Setup tooling** (`tools/Setup.ps1`, `tools/setup.sh`): prepares the super-repo environment, installs required SDKs, and ensures the root `se-config.ini` / `se-config.local.ini` templates exist (no per-project seeding).
- **MDK2 project scaffolding** (`tools/ScaffoldMdk2Project.ps1`, `tools/scaffold-mdk2-project.sh`): creates or updates standalone Programmable Block or mixin projects without touching git state.
- **Project submodule scaffolding** (`tools/ScaffoldProjectSubmodule.ps1`, `tools/scaffold-project-submodule.sh`): orchestrates git submodules and delegates project creation to the MDK2 scaffolder while wiring repository workflows.

- `tools/Setup.ps1` and `tools/setup.sh` must implement the behaviour defined in `docs/spec/tooling/SetupTooling.md`.
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
