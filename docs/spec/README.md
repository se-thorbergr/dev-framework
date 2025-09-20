# Specifications

This directory captures the authoritative contracts the tooling and architecture must follow. Each specification must be reviewed and approved before implementation changes.

## Tooling Specs

- [Setup Tooling](tooling/SetupTooling.md)
- [Scaffold MDK2 Project](tooling/ScaffoldMdk2Project.md)
- [Scaffold Project Submodule](tooling/ScaffoldProjectSubmodule.md)

These specifications align with three layered responsibilities documented in the policies:

1. Setup tooling prepares the super-repo environment.
2. MDK2 project scaffolding focuses on project structure without git automation.
3. Submodule scaffolding composes git workflows with the MDK2 scaffolder.

## TODO

- Translate architecture into coding specifications.
- Take over and refine from docs/arch/VIOS.obsolete.md (VIOS -> OS).
