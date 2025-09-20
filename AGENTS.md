# AGENTS Guide

Welcome to the dev-framework repository. Before making any changes, please review:

- `docs/policy/Environment.md`
- `docs/policy/Workflow.md`
- `docs/policy/CodingStyle.md`
- Tooling specs under `docs/spec/tooling/`, starting with `ToolingGeneral.md`.

Always align work with these documents, follow the shared CLI conventions, and verify changes (`git diff`, etc.) before handoff.

## Quick Reminders

- Run `tools/tests/run-all.sh` before handing off changes so Bash/PowerShell tooling and setup scripts are verified together.
- Prefer using the shared tooling libraries (`tools/lib/tooling.sh`, `tools/lib/DevFramework.Tooling.psm1`) instead of reimplementing argument parsing or logging.

## Editing Guidance

- Prefer Python scripts for file modifications (UTF-8, LF endings) when available.
- If Python is unavailable, fall back to shell-specific tooling (PowerShell/Bash), ensuring behaviour matches the Python flow.
- Always honor repository formatting rules: `.editorconfig` (UTF-8, LF, final newline) and `.gitattributes` line-ending expectations.
- After edits, run `git diff` (or equivalent) to verify changes before handoff.

### Quick Write Snippet

```bash
python_cmd=python
if ! command -v "$python_cmd" >/dev/null 2>&1; then
  python_cmd=python3
fi
"$python_cmd" <<'PY'
from pathlib import Path
path = Path('path/to/file')
text = path.read_text(encoding='utf-8').replace('
', '
')
# modify text...
if not text.endswith('
'):
    text += '
'
path.write_text(text, encoding='utf-8', newline='
')
PY
```

Use this pattern to enforce UTF-8 + LF when modifying files.
