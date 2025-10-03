# Space Engineers Ingame Script - Development Framework (dev-framework)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Built _by_ Space Engineers fans, _for_ Space Engineers fans. Drop in, wire modules, and make your grid feel alive. ⚙️🚀

## Goal

The idea is to provide a modular library for SE programming. Think of it like an Operating System that comes with libraries of basic functionality that can be used in all kinds of PB scripts - the programs running on the OS.

## Features

### Development Environment

- Windows
- Linux / WSL (Debian/Ubuntu)
- PowerShell 7.x or Bash
- Visual Studio Code
- GPT Codex support (CLI or VS Code extension), optional

## Git Super-Repo

The **dev-framework** is the **super-repo** providing the _development framework_ for creating Space Engineers Ingame Scripts using _Malware's Development Kit for SE_.

It includes:

- tools (project and CI helper tools)
  - - Tools to scaffold new projects (wrappers around the MDK2 toolkit)
  - Tools to scaffold Git submodules (for PB-script and Mixin projects)
  - Tools for GitHub CI workflows (Policy Gates)
- docs (policies, architecture, specs, guides, AI prompts)
- GitHub CI (workflows / GitHub Actions)

The MDK2 Programmable Block Scripts and Mixins are not directly contained in this super-repo. Each part of the library and each script/program has its own project in separated submodules linked to the super-repo.

The development framework manages submodules, build, and CI, and enforces policy alignment.

## Tooling Helpers

- Run `pwsh tools/format-staged.ps1 --dry-run` (or `bash tools/format-staged.sh --dry-run`) to preview formatter changes for staged C#, PowerShell, Bash, and Markdown files.
- Run `pwsh tools/lint-staged.ps1 --dry-run` to check staged files with ScriptAnalyzer, ShellCheck, markdownlint, and optional `dotnet build`.
- Use `pwsh tools/format.ps1 --files path/to/file.md` (or `bash tools/format.sh`) when you want to format specific files before staging them.
- Use `pwsh tools/lint.ps1 --files path/to/file.md --fail-on-warn` to lint explicit files while you iterate.
- Prefer the npm shortcuts: `npm run format -- <files>`, `npm run lint -- <files>`, or their `*:staged` variants route through the same helpers; Markdown is formatted with Prettier and Mermaid diagrams can be validated with `@mermaid-js/mermaid-cli` when installed.

## Important Note

This is a **hobby project**. That means I only work on it in my **_limited_ spare time**. So don't expect fast delivery of bugfixes and features.

As we are in a new era of _AI_ I decided to make heavily use of _GPT Codex_ to try out and learn what is possible. So you will find lots of **prompts** as part of the documentation.

## Getting Started

See **[Getting Started](docs/GettingStarted.md)**

## Contributing

See **[Contributing](docs/CONTRIBUTING.md)**

---

## Author

- [geho](https://github.com/geho)
- [Thorbergr](https://steamcommunity.com/profiles/76561198125979465)

---

## Credits

- [MDK2-SE by @malforge](https://github.com/malforge/mdk2) - Appreciation and thanks for this great toolkit!

---

_Space Engineers is trademarked to Keen Software House. This project is fan-made, and its developer has no relation to Keen Software House._
