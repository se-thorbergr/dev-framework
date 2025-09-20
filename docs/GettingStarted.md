# Getting Started

Follow these steps to prepare your development environment and understand the project workflow.

## 1. Read the Policies

1. Review the [Environment Policy](policy/Environment.md) for platform/toolchain requirements.
2. Skim the [Workflow Policy](policy/Workflow.md) to understand how the maintainer and AI assistant collaborate.
3. Note language conventions in the [Coding Style Policy](policy/CodingStyle.md).

## 2. Prepare Dependencies

- Install dotnet SDK 9.0._ and PowerShell 7._ using your package manager when available; otherwise plan for manual installs.
- Ensure access to the Space Engineers `Bin64` directory. If you work cross-platform, expose the folder via shared storage.
- Decide whether to enable Codex tooling; it is optional but supported by the setup scripts.

## 3. Run the Setup Tooling

1. From the repository root, run the relevant script:
   - Windows: `pwsh ./tools/Setup.ps1`
   - Linux/macOS: `./tools/setup.sh`
2. The script honours CLI switches described in [Setup Tooling Specification](spec/tooling/SetupTooling.md); shared switches (e.g., `--dry-run`, `--verbose`, `--summary`, `--ci`, `--help`) come from [ToolingGeneral.md](spec/tooling/ToolingGeneral.md).
3. Follow prompts to resolve paths and install missing dependencies. When declining automatic installs, record the manual steps suggested by the tool.

## 4. Verify Configuration

- Confirm `se-config.local.ini` exists (use `docs/se-config.local.example.ini` as a starting template) and adjust helper `[Paths]` entries plus local `[mdk]` overrides (`output`, `binarypath`) for your machine.
- Check any seeded `ProjectName.mdk.local.ini` files within submodules before committing.
- If you maintain a custom solution name, ensure you invoke setup with `--sln <name>` so future runs stay aligned.

## 5. Next Steps

- Explore existing documentation via [docs/README.md](README.md).
- Use the scaffold tooling once setup completes (see specs in `docs/spec/tooling/`).
- Keep `docs/TODO.md` up to date when you finish tasks or raise new follow-ups.
