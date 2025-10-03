> Tone: second person, active, imperative; precise and concise.

# Workflow Policy

This policy describes how the maintainer (human developer) and the AI assistant collaborate on the dev-framework project.

## Policy Relationships

Use the following diagram to understand how human-authored policies, AI machine rules, templates, and runtime contexts interact. The AI policies shown under `.ai/policies/` include both the primary rule files and the supporting configuration files (`comment-levels.yaml`, `file-policy.yaml`) that Core loads.

```mermaid
flowchart TD
  %% Human policies govern prose and workflow expectations
  subgraph HumanPolicies["Human Policies (docs/policy/**)"]
    PolicyEnv["Environment.md"]
    PolicyWorkflow["Workflow.md"]
    PolicyStyle["CodingStyle.md"]
    PolicySpecAuthor["SpecAuthoring.md"]
  end

  %% AI policy stack consumed by automation and agents
  subgraph AIPolicies["AI Policies (.ai/policies/**)"]
    AICore["core.yaml"]
    AIStyle["style.yaml"]
    AISafety["safety.yaml"]
    AIRouting["routing.yaml"]
    AIComment["comment-levels.yaml"]
    AIFilePolicy["file-policy.yaml"]
    AISpecAuthor["spec-authoring.yaml"]
  end

  %% Spec templates
  subgraph Templates["Spec Templates"]
    TTooling["docs/spec/tooling/_template.md"]
    TIngame["docs/spec/ingame/_template.md"]
  end

  %% Tooling specs (abridged)
  subgraph ToolingSpecs["Tooling Specs (docs/spec/tooling/**)"]
    SGeneral["ToolingGeneral.md"]
    SSetup["SetupTooling.md"]
    SScaffoldProj["ScaffoldMdk2Project.md"]
    SScaffoldSub["ScaffoldProjectSubmodule.md"]
    SSharedLibs["SharedLibrary & Lib*.md"]
  end

  %% In-game specs
  subgraph IngameSpecs["In-game Specs (docs/spec/ingame/**)"]
    IngSpecs["Profile-specific specs"]
  end

  %% Execution contexts
  subgraph Runtime["Execution Contexts"]
    Local["Local dev"]
    CI["CI / GitHub Actions"]
  end

  %% Relationships
  HumanPolicies --> Templates
  PolicySpecAuthor --> Templates
  Templates --> ToolingSpecs
  Templates --> IngameSpecs
  HumanPolicies --> ToolingSpecs
  HumanPolicies --> IngameSpecs

  AICore --> AIStyle
  AICore --> AISafety
  AICore --> AIRouting
  AICore --> AIComment
  AICore --> AIFilePolicy
  AICore --> AISpecAuthor

  AIPolicies -->|machine rules & gates| ToolingSpecs
  AIPolicies -->|machine rules & gates| IngameSpecs
  AIPolicies -->|workspace.mode & guards| Local
  AIPolicies -->|CI enforcement| CI

  SGeneral --> SSharedLibs
  SSetup --> SSharedLibs
```

## Collaboration Loop

1. **Context Share** – Developer provides repository state, priorities, and constraints. AI confirms understanding and surfaces clarifying questions when information is ambiguous.
2. **Scope Agreement** – Before executing commands or edits, AI drafts a short plan; developer can adjust or veto steps. Plans are tracked in conversation using the plan tool.
3. **Spec-First Changes** – For tooling or architecture work, AI checks that an approved specification exists. Missing or outdated specs are updated with developer sign-off before implementation proceeds.
4. **Incremental Work** – AI performs changes in small batches, validating after each significant action (e.g., running `Get-Content`, generating files). No destructive commands without explicit developer approval.
5. **Review & Handoff** – AI summarizes modifications referencing file paths and open questions. Developer reviews, requests adjustments, or approves next tasks.

## Communication Guidelines

- Developer remains the gatekeeper for decisions; AI avoids assumptions when requirements are unclear.
- AI records unknowns and follow-ups in spec "Open Questions" or TODOs so context is preserved.
- All tooling that may modify developer environment (installs, git operations) must prompt the developer unless explicitly forced via CLI switch or instruction.

## Documentation & TODO Hygiene

- When tasks complete, AI updates `docs/TODO.md` and relevant specs/policies to prevent drift.
- Every specification change must append a dated entry to its changelog so the history remains traceable.
- New ideas or deferred decisions belong in the appropriate spec section 9 or Supporting Documentation notes, ensuring future visibility.

## Commit Messages

- Format subject lines as `<scope[/sub-scope]>: summary` in lowercase (e.g. `tooling/setup: implement bash script`).
- Use imperative summary text without trailing punctuation; keep the line within 72 characters.
- Only add a body when extra context is essential; wrap additional lines at 72 characters.
- Choose scopes that describe the touched area (`tooling`, `docs/tooling`, `policy/workflow`, etc.).

## Test-first mode (tooling)

- For new features or changes to scripts under `tools/`, write or update tests **first** (Bats/Pester), then implement code to make tests pass.
- For regressions, add a failing test that reproduces the issue, then fix to green.
- Prefer component-style tests that exercise script entry points (flags/inputs) rather than internal helpers.
- `--help`/`--version` output **must** be stable and parseable in tests; `--dry-run` paths **must** have no side effects.
- Bash-based tests may invoke Python helpers for JSON parsing. Ensure an interpreter (`python3`, `python`, or `py -3`) is visible on `PATH` (or exported via `PYTHON`/`PYTHON_CMD`) before running suites locally or in CI.

## Workflow Diagrams

The Mermaid diagrams below capture the “golden order” implemented in `.ai/workflows/*.yaml`. Each node lists the command executed at that step; helper scripts (`tools/format*.ps1`, `tools/lint*.ps1`) route through our shared formatter/linter logic. Branches highlight conditional behaviour (e.g., CI-only checks).

### Code Workflow (`.ai/workflows/code.yaml`)

```mermaid
flowchart TD
  Start([Start]) --> Select["Select staged files within code scope"]
  Select --> Format["Run `pwsh tools/format-staged.ps1`"]
  Format --> Lint["Run `pwsh tools/lint-staged.ps1 --fail-on-warn`"]
  Lint --> Build["Run `dotnet build -warnaserror`"]
  Build --> Tests{Run test suites}
  Tests --> DotnetTest["`dotnet test --nologo`"]
  Tests --> Pester["`Invoke-Pester tools/tests/pwsh -CI`"]
  Tests --> Bats["`bats -r tools/tests/bash`"]
  DotnetTest --> Security["`dotnet list package --vulnerable`"]
  Pester --> Security
  Bats --> Security
  Security --> Verify["Record verify trace, present plan, enforce commit rules"]
  Verify --> End([Handoff / Commit])

  %% Notes
  Format -.-> FormatDetail["Uses tools/format.ps1 internally (C#, PowerShell, Bash, Markdown)"]
  Lint   -.-> LintDetail["Uses tools/lint.ps1 (markdownlint + optional Mermaid validation)"]

  %% CI minimal info path
  Security -.-> CIMin["CI-only checks (format/lint dry-runs)"]
```

### Docs Workflow (`.ai/workflows/docs.yaml`)

```mermaid
flowchart TD
  Start([Start]) --> SelectDocs["Select staged Markdown files"]
  SelectDocs --> FormatDocs["If MODE != se, run pwsh tools/format.ps1 --files ..."]
  FormatDocs --> LintDocs["If MODE != se, run pwsh tools/lint.ps1 --files ... --fail-on-warn"]
  LintDocs --> LinkCheck{MODE == tooling}
  LinkCheck -->|Yes| RunLink["Run markdown-link-check (quiet) on staged docs"]
  LinkCheck -->|No| SkipLink["Skip link check"]
  RunLink --> VerifyDocs["Record verify trace, present plan"]
  SkipLink --> VerifyDocs
  VerifyDocs --> EndDocs([Handoff / Commit])
```

### Config Workflow (`.ai/workflows/config.yaml`)

```mermaid
flowchart TD
  Start([Start]) --> SelectConfig["Select staged config files (*.yml, *.yaml, *.json)"]
  SelectConfig --> ModeCheck{MODE == se}
  ModeCheck -->|Yes| SkipAll["Skip local format/lint; CI enforces"]
  ModeCheck -->|No| FormatConfig["Run npx prettier (write) on YAML/JSON"]
  FormatConfig --> LintConfig["Run yamllint / jq validation"]
  SkipAll --> VerifyConfig["Record verify trace, present plan"]
  LintConfig --> VerifyConfig
  VerifyConfig --> EndConfig([Handoff / Commit])
```

## Verification

- After each edit, AI verifies the change by re-reading or diffing the affected file (e.g., `Get-Content`, `rg`, `git diff`) before proceeding.
- The verification step must capture the exact command or diff snippet in the handoff so future reviewers can trace what was inspected.
- AI reports commands run, highlights failed attempts, and proposes manual validation steps the developer can perform.
- Significant workflow changes require developer acknowledgment in this document before adoption.
