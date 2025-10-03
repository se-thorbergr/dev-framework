> Tone: imperative, concise; use RFC-2119 MUST/SHOULD/MAY.

# Spec Authoring Policy

Last updated: 2025-09-30 - Owner: geho

This policy defines mandatory structure and authorship rules for specifications under `docs/spec/**`.

## 1. Source of Truth (SoT)

- Specs **MUST** follow the structure of `docs/spec/tooling/_template.md`.
- The template's **15 sections, titles, and order** are normative (see Section 2).
- Each spec **SHOULD** cite the template version at the top, e.g.:
  `Spec Template (SoT): docs/spec/tooling/_template.md (Last updated: 2025-09-28)`
- **Profiles:** When a profile-specific template exists (e.g., `docs/spec/ingame/_template.md`), specs in that profile **SHOULD** cite it instead; otherwise cite the default tooling template.

## 2. Required Sections (15)

All specs **MUST** contain these numbered sections in this exact order:

1. **Scope**
2. **Preconditions & Assumptions**
3. **Shared Responsibilities**
4. **Contract** (variant; see Section 3)
5. **Workflow**
6. **Configuration Handling**
7. **Normative Requirements**
8. **Outputs**
9. **Failure Modes & Recovery**
10. **Validation** _(Tools/libraries may title this “Validation & Testing”)_
11. **Acceptance Criteria**
12. **Security & Permissions**
13. **Telemetry & Logging (optional)**
14. **Open Questions / Future Enhancements**
15. **Change Log** (append-only; newest at bottom)

> **Presence rule:** If a section does not apply, keep the heading and write a single line: “Not applicable - <reason>.”

## 3. Section 4 Contract Variant & Profiles

- **Tools** (CLIs) **MUST** use **“Section 4 CLI Contract”**.
- **Libraries** **MUST** use **“Section 4 API Contract”**.
- For **Space Engineers in‑game scripts** (Programmable Block), Section 4 **MAY** be titled **“API Contract (SE ingame script)”**.
- Cross-reference any shared contract (e.g., ToolingGeneral) rather than duplicating it.

### 3.1 Profiles

This policy applies to all specs under `docs/spec/**`. Two profiles are recognized (more may be added):

- **tooling** — CLI tools and shared libraries (PowerShell/Bash). Same 15-section template; require PS/Bash parity and ASCII-only console output by default.
- **se_ingame** — Space Engineers Programmable Block scripts / in-world systems. Same 15-section template; **additional expectations**:
  - **Sandbox:** No file IO, networking, threads, reflection, or external processes.
  - **Runtime limits:** Respect instruction quota and memory constraints per tick.
  - **Update cadence:** Declare `Update1/10/100` usage and per-tick budget.
  - **Persistence:** Define `Save()` behavior, state schema, and migrations.
  - **Determinism:** MP-safe behavior; avoid non-deterministic sources.
  - **Security:** No unsafe code; no command abuse; surface only intended actions.
  - **Validation:** Perf/quota tests, save/load round-trips, and determinism replays.

## 4. References (Section 1.1)

- Use **repository filenames** when cross-referencing; avoid **session/editing identifiers**.
- Include relevant policies and peer specs (e.g., Environment/Workflow/CodingStyle; Lib\* specs).

## 5. Normative Language (Section 7)

- Use RFC-2119 terms (**MUST/SHOULD/MAY**). Keep each requirement **atomic**.

## 6. Separation of Concerns

- **Section 5 Workflow** describes process/sequence.
- **Section 6 Configuration Handling** documents config sources, precedence, persistence rules.
- Keep **Section 9/Section 10/Section 11** distinct: failures vs validation vs acceptance.

## 7. Security & Telemetry

- **Section 12 Security & Permissions** and **Section 13 Telemetry & Logging** **MUST** be present in every spec. It's acceptable to mark telemetry as “Not applicable.”
- **SE ingame specs** **MUST** state sandbox constraints (no file IO, networking, threads, reflection) and any determinism requirements in **Section 12**.

## 8. Dual-Implementation Parity

- Where both PowerShell and Bash exist, specs **MUST** assert **behavior parity**.
- Default to **ASCII-only** console output unless a spec explicitly allows Unicode.

## 9. Change Log (Section 15)

- On every edit, **update the top metadata banner** to today's date: `Last updated: YYYY-MM-DD - Owner: <name>`.
- Then append a row **at the bottom**: `| YYYY-MM-DD | change summary | approver |`.
- Keep the policy notice line above the table unmodified.

## 10. Template Versioning

- The template file **MUST** maintain its own “Last updated” line and a change log entry whenever structure or headings change.
- Specs **SHOULD** reference that date to make drift visible.

## 11. CI & Review Expectations

- Docs workflow **MUST** verify that headings of each spec match the template (allowing Section 4 variant titles — **CLI Contract**, **API Contract**, or **API Contract (SE ingame script)** — and allowing “Validation & Testing” as an alias for Section 10).
- Mismatches **FAIL** the docs job with a helpful message listing missing/out-of-order sections.

## 12. Examples & Duplications

- Prefer **links** to shared material (e.g., ToolingGeneral, SharedLibrary) over duplication.
- If examples are necessary, keep them short and non-normative unless explicitly stated.

## 13. Exceptions

- Temporary deviations **MUST** be recorded in **Section 14 Open Questions** with an owner and a resolution date.

## 14. Maintenance

- Review this policy when the template evolves. Update both together to keep SoT consistent.

## 15. Change Log

> **Policy:** On every spec edit, the author/AI **MUST** append a new row **at the bottom** (chronological top→bottom) with date, summary, and approver.

| Date       | Change                                                                                                                    | Approved By |
| ---------- | ------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-28 | Initial Spec Authoring Policy (adopt 15-section SoT)                                                                      | geho        |
| 2025-09-28 | Normalize punctuation to ASCII (hyphens, bullets, apostrophes).                                                           | geho        |
| 2025-09-28 | Require updating the top "Last updated" line on edits, in addition to the change log row.                                 | geho        |
| 2025-09-28 | Add **profiles** (tooling, se_ingame); allow Section 4 title "API Contract (SE ingame script)"; add profile expectations. | geho        |
| 2025-09-30 | Wording: use "repository filenames"; remove chat/canvas phrasing in Section 4. Bumped top banner date.                    | geho        |
| 2025-10-14 | Switched metadata banner guidance from italics to plain text.                                                             | geho        |
