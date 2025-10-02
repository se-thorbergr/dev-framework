> Tone: normative for referenced specs. This page is informational.

# Tooling Specs - Index & Guide

_Last updated: 2025-09-30 - Owner: geho_

This index lists all **tooling specifications** and how they relate. Use it to navigate contracts, domain libraries, and tool-specific specs.

---

## 1) Contracts & Overviews

- **Shared CLI Contract** - `docs/spec/tooling/ToolingGeneral.md`
- **Shared Libraries Overview & Index** - `docs/spec/tooling/SharedLibrary.md`
- **Spec Template (use for new specs)** - `docs/spec/tooling/_template.md`

> _Note:_ Broader system architecture is documented in `docs/arch/README.md` and is intentionally out of scope for this tooling index.

---

## 2) Domain Libraries (PowerShell/Bash parity)

- **LibCli** - CLI runtime (arg parsing, logging, summary, CI annotations)  
  `docs/spec/tooling/LibCli.md`
- **LibConfig** - read/merge/validate config; diff rendering for `.local`  
  `docs/spec/tooling/LibConfig.md`
- **LibFs** - safe filesystem **planning** utilities; render action plans  
  `docs/spec/tooling/LibFs.md`
- **LibMDK2** - MDK2-specific validators (configs & project layout)  
  `docs/spec/tooling/LibMDK2.md`
- **LibDotnetProj** - MSBuild XML reader & **edit planner** for `.csproj`, `.shproj`, `.projitems`  
  `docs/spec/tooling/LibDotnetProj.md`

> All libraries are **planning/validation only**; they **do not write** files or call `exit`. Callers own side effects.

---

## 3) Tool Specifications (by feature area)

- **Setup Tooling** - `docs/spec/tooling/SetupTooling.md`
- **Scaffold MDK2 Project** - `docs/spec/tooling/ScaffoldMdk2Project.md`
- **Scaffold Project Submodule** - `docs/spec/tooling/ScaffoldProjectSubmodule.md`
- **Tooling General Notes** - `docs/spec/tooling/ToolingGeneral.md` _(contract; see Section 1)_

> For **Local vs CI/GitHub** execution behavior, see the matrices in `ToolingGeneral.md` Section 5 and `SetupTooling.md` Section 5. Authoritative SoT: `.ai/policies/core.yaml` → `modes`.

> New tools MUST follow the CLI contract and SHOULD reuse domain libraries above.

---

## 4) Conventions

- **Template-first:** Start from `docs/spec/tooling/_template.md`. Keep section titles and order. For libraries, rename Section 4 to **API contract**.
- **File references:** Use **repository filenames** in cross-references; avoid session/editing identifiers.
- **Parity:** All specs that define behavior MUST ensure PS7/Bash parity.
- **ASCII-only outputs:** Console outputs from libraries and tools MUST be ASCII-only unless otherwise stated.

---

## 5) Change Log

| Date       | Change                                                                                                   | Approved By |
| ---------- | -------------------------------------------------------------------------------------------------------- | ----------- |
| 2025-09-27 | Initial index covering contracts, domain libraries, and tool specs; added conventions & template ref.    | geho        |
| 2025-09-28 | Normalize punctuation to ASCII and bump date; no content changes.                                        | geho        |
| 2025-09-28 | Add architecture note pointing to `docs/arch/README.md` in Section 1.                                    | geho        |
| 2025-09-30 | Add link to Local vs CI/GitHub behavior matrices in ToolingGeneral Section 5 and SetupTooling Section 5. | geho        |
| 2025-09-30 | Wording: 'canvas names' → 'session/editing identifiers'; add execution-mode SoT pointer.                 | geho        |
