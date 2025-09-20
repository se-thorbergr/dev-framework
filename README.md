# Space Engineers Ingame Script - Development Framework (dev-framework)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Built _by_ Space Engineers fans, _for_ Space Engineers fans. Drop in, wire modules, and make your grid feel alive. ⚙️🚀

## Goal

The idea is to provide a modular library for SE programming. Think of it like an Operating System that comes with libraries of basic functionality that can be used in all kinds of PB scripts - the programs running on the OS.

## Features

### Development Environment

- Windows
- Linux
- Powershell or Bash (Windows & Linux)
- Visual Studio Code (Windows & Linux)
- GPT Codex support (Codex cli or VSCode extension) for coding

## Git Super-Repo

The **dev-framework** is the **super-repo** providing the _development framework_ for creating Space Engineers Ingame Scripts using _Malware's Development Kit for SE_.

It includes:

- tools (project and CI helper tools)
  - Tools to scaffold new projects (wrappers to the MDK2 toolkit).
  - Tools to scaffold git submodules (for PBScript and Mixin projects)
  - Tools for GitHub CI workflows (Policy Gates)
- docs (policies, architecture, specs, guides, AI prompts)
- github CI (workflows / github actions)

The MDK2 Programmable Block Scripts and Mixins are not directly contained in this super-repo. Each part of the library and each script/program has its own project in separated submodules linked to the super-repo.

The Development Framework itself is responsible for the projects/submodules management, build process, CI workflow, etc. and enforcing the policies alignment.

## Important Note

This is a **hobby project**. That means I only work on it in my **_limited_ spare time**. So don't expect fast delivery of bugfixes and features.

As we are in a new era of _AI_ I decided to make heavily use of _GPT Codex_ to try out and learn what is possible. So you will find lots of **prompts** as part of the documentation.

## Getting Started

see [Getting Started](docs/GettingStarted.md)

## Contributing

see [Getting Started](docs/CONTRIBUTING.md)

---

## Author

- [geho](https://github.com/geho)
- [Thorbergr](https://steamcommunity.com/profiles/76561198125979465)

---

## Credits

- [MDK²-SE by @malforge](https://github.com/malforge/mdk2) - Appreciation and thanks for this great toolkit!

---

_Space Engineers is trademarked to Keen Software House. This project is fan-made, and its developer has no relation to Keen Software House._
