# AGENTS.md (entrypoint)

> This file is **AI-only** guidance for this repo. Human policies live under `docs/policy/**`.

## Scope

- Keep this document **short**. The **authoritative AI config** is machine-readable in `.ai/`.

## Canonical config (read before acting)

- **Entry point:** `.ai/policies/core.yaml` (loads `.ai/policies/comment-levels.yaml` and `.ai/policies/file-policy.yaml` internally)
- **Style rules (SSOT):** `.ai/policies/style.yaml`
- **Edit safety rails (SSOT):** `.ai/policies/safety.yaml`
- **Workflows (scoped):**
  - **Code:** `.ai/workflows/code.yaml` (C#, PowerShell, Bash)
  - **Docs:** `.ai/workflows/docs.yaml` (Markdown)
  - **Config:** `.ai/workflows/config.yaml` (YAML/JSON/INI; **INI read-only**)
- Agents MUST load **core** and then select the workflow by **file scope** (**config > docs > code**).

**Applies to all agents:** Codex CLI and any local/CI runners. All agents MUST load `.ai/policies/*` before proposing or applying edits and MUST follow the same safety rails and workflows.

## Permissions

- **Ask first** (present a plan + diff/dry-run):
  - package installs/updates
  - file writes/creates/renames/deletes/chmod
  - `git add`, `git commit`, `git push`, `git reset`
  - branch creation/checkout (`git checkout -b`, `git switch -c`)
  - full build/publish
  - network beyond approved sources
  - any operation touching secrets/credentials
- **Allowed without prompt:** read/list files; `git status/diff`; run tests/static analysis.

## Comment levels

- Precedence: **pragma in file** → `.ai/policies/comment-levels.yaml` **pins** → **overrides** → **default**.
- Set with `@comment-level: minimal|standard|verbose` at file top.

## File selection boundary

- Writes/scan scope is governed by `.ai/policies/file-policy.yaml`.
- Treat `.gitignore` as the **write/scan** boundary; read-only exceptions for `.ai/handoffs/**` and `.ai/matrices/**` are defined there.

## Workflow (AI)

- **Code files:** follow `.ai/workflows/code.yaml` (staged-only format/lint/build/test).
- **Docs:** follow `.ai/workflows/docs.yaml` (staged-only format/lint/link-check). Use repo-local Prettier via **`npx prettier`**.
- **Config files:** follow `.ai/workflows/config.yaml` (staged-only format/lint/validate for YAML/JSON).
  - **INI and .mdk.ini are enforced read-only**. There are no pragma-based overrides; edits to these files are always denied.
- Do **not** run repo-wide format without explicit consent. Humans follow `docs/policy/Workflow.md`.

## Artifacts

- Write verification evidence to `.ai/handoffs/` (ignored). Matrices/decision logs go to `.ai/matrices/` (ignored).

## Non-AI rules

- Coding style, environment, and human workflow: see `docs/policy/CodingStyle.md`, `docs/policy/Environment.md`, `docs/policy/Workflow.md`.

## Commit Messages

- Use `.ai/templates/commit-template.md` for format and scopes (e.g., `tooling`, `docs/*`, `policy/*`, `config/*`).

## Editorial style for generated docs

> Source of truth: `.ai/policies/style.yaml` (CI-enforced). Summary only.

- Use **US English (en-US)**; keep a single dialect per doc.
- Write in **second person**, **imperative**, **active voice**.
- **Versions:** prose uses `7.x` style; code/config uses native syntax (e.g., `net7.0`).
- **Punctuation:** **ASCII-only** by default; normalize quotes/dashes/ellipsis/NBSP/soft hyphen before handoff; allow Unicode only in literals/URLs.
- **Paths:** tooling-owned/generated paths **ASCII-only**; Unicode allowed only in whitelisted content with **UTF-8 + NFC**; keep project names/namespaces ASCII.
- **SE script strings:** ASCII in logs/keys/tokens; Unicode allowed for UI text with ASCII fallbacks (`->`, `...`); normalize to NFC; use culture-invariant comparisons.

## Tool selection (edits & transforms)

- Use repo-native tools per scope:
  - **Code:** dotnet/Roslyn/MDK2 build & analyzers
  - **Docs:** Prettier via `npx`, markdownlint
  - **Config:** schema validators, `jq`/`yq` for JSON/YAML
- Codex CLI (or any local agent) **MUST NOT** bypass workflows or write directly. Produce patches or structured outputs; apply via the scoped workflows on **staged files** only.
- Use **Python** when it adds clear value (analysis, generation, complex transforms). Produce **patches or structured output**, then apply via the scoped workflows on **staged files**.
- **Do not** bypass workflows with ad-hoc writes from any runtime.
- **Respect read-only**: INI/`.mdk.ini` remain read-only regardless of tool.

## Edit Safety Protocol

> Source of truth: `.ai/policies/safety.yaml` (CI-enforced). Summary only.
> These rules apply to CLI and CI agents (Codex CLI, local runners). Noncompliant edits are rejected in CI.

- **Only edit explicitly targeted files.** No background or deferred edits.
- **Preflight:** refresh cache; locate **exact** targets; if not found, **abort**.
- **Apply:** make **minimal, atomic** diffs; renumber in a safe sequence; respect read-only (INI/`.mdk.ini`).
- **Verify:** reload target files; check presence/absence/count; emit a **minimal diff**.
- **Changelog:** ensure policy line; append new row **at the bottom**.
- **On failure:** stop and report; do **not** guess or chain edits.

## Tone & Voice (scope map)

- READMEs: second person, active, imperative; explanatory and friendly; examples welcome.
- Policies (`docs/policy/*`): second person, precise and concise; no anecdotes or marketing.
- Specs (`docs/spec/**`): normative language (MUST/SHOULD/MAY); use second person only in step-by-step instructions.
- `.ai/*` (policies/workflows): neutral, declarative; avoid "you"; reference SSOTs.
- Templates (`.ai/templates/*`): concise, imperative; keep subjects ≤72 chars.
- Configs (.editorconfig, .gitattributes, etc.): neutral comments; explain what/why briefly.

## Completeness expectations

- **Policies** (`docs/policy/*`): complete rules (prereqs, edge cases, exceptions).
- **Specs** (`docs/spec/**`): normative completeness (MUST/SHOULD, inputs/outputs, error cases, acceptance criteria).
- **AGENTS.md**: complete guardrails and SSOT pointers.
- **Environment/Setup**: complete OS-specific install, prerequisites, verification, rollback.
- **READMEs**: task-complete (quickstart + common tasks); link to policy/spec for depth.
- **Templates** (`.ai/templates/*`): structurally complete; all fields present; examples only if they unblock usage.
- **.ai/** (policies/workflows/configs): minimal; reference SSOTs; avoid restating prose.

**Acceptance checklist (for "complete" docs):** prereqs; exact steps/commands with context; expected outputs; inputs/outputs and side effects; common failure modes + fixes; verification steps; links to SSOT; dated changelog for major changes.

---

### Minimal bootstrap for agents (pseudocode)

```
load('.ai/policies/core.yaml')
load('.ai/policies/routing.yaml')
scope = detect_scope(file)  # 'docs' for *.md|*.markdown; config for *.ya?ml|*.json|*.ini; else 'code'
if scope == 'docs':
  load('.ai/workflows/docs.yaml')
else if scope == 'config':
  load('.ai/workflows/config.yaml')
else:
  load('.ai/workflows/code.yaml')
resolve_comment_mode(file) with precedence
limit_write_scope per file-policy + .gitignore
if file extension in (*.ini, *.mdk.ini): enforce read-only (deny writes regardless of scope)
execute golden-order steps on **staged files only**
record commands + diffs to .ai/handoffs/
```
