# Policy Index

Policies define the rules we expect contributors and tooling to follow. Keep them in sync with their corresponding specifications.

## Core Policies

- [Environment Policy](Environment.md) – supported platforms, toolchain requirements, and configuration expectations.
- [Workflow Policy](Workflow.md) – collaboration loop between maintainer and AI assistant.
- [Coding Style Policy](CodingStyle.md) – language conventions and formatting guidelines.

## Usage

- Specs under `docs/spec/` implement these policies. Whenever behaviour changes, update both the policy and the relevant spec.
- AGENTS.md or other project prompts should reference these policies rather than duplicating rules.

## Maintenance

- Review policies regularly to ensure they reflect current practice.
- Open questions should be tracked in `docs/TODO.md` or in the _Open Questions_ section of the related spec until resolved.
