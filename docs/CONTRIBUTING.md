# Contributing Guide

Thank you for supporting the dev-framework project. This guide summarizes expectations and points you to the authoritative policies.

## Before You Start

1. Review the [Environment Policy](policy/Environment.md) to ensure your toolchain matches the supported versions.
2. Read the [Workflow Policy](policy/Workflow.md) to understand the collaboration loop and review process.
3. Familiarize yourself with the [Coding Style Policy](policy/CodingStyle.md).

## Working with Tooling

- Always consult the relevant specification under `spec/tooling/` (shared conventions live in `ToolingGeneral.md`) before modifying or invoking scripts.
- Run the setup script (`tools/Setup.ps1` or `tools/setup.sh`) to seed configuration files prior to scaffolding projects.
- Record any deviations or discovered gaps in the _Open Questions_ section of the appropriate spec.

## Making Changes

1. Align your plan with the maintainer/AI workflow (share context, agree on scope, follow incremental updates).
2. Update documentation and specs whenever you change behavior; policy/spec drift leads to rejected merges.
3. Ensure `docs/TODO.md` reflects completed tasks or newly identified follow-ups.

## Submitting Updates

- Use concise commits referencing the specs or policies you touched.
- Include testing notes (commands executed, platforms verified) in your PR or review message.
- Be prepared for review focused on spec compliance, risk assessment, and missing test coverage.

## Support

Open an issue if you are unsure how a policy applies or if tooling behavior diverges from its specification.
