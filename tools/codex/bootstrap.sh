#!/usr/bin/env bash
set -euo pipefail

# UTF-8 for console
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

ROOT="$(git rev-parse --show-toplevel)"

# Core policy SSOT
POLICY_CORE=(
  ".ai/policies/core.yaml"
  ".ai/policies/style.yaml"
  ".ai/policies/safety.yaml"
  ".ai/policies/file-policy.yaml"
)

# Available workflows
WF_DOCS=".ai/workflows/docs.yaml"
WF_CODE=".ai/workflows/code.yaml"
WF_CONFIG=".ai/workflows/config.yaml"

# Read staged files
mapfile -t STAGED < <(git diff --name-only --cached | sed '/^$/d')
if (( ${#STAGED[@]} == 0 )); then
  echo "No staged files. Stage exact targets first (git add <files>)." >&2
  exit 1
fi

# Detect manual workflow override --wf=docs|code|config (remove from args)
WF_OVERRIDE=""
TASK_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --wf=docs)   WF_OVERRIDE="docs" ;;
    --wf=code)   WF_OVERRIDE="code" ;;
    --wf=config) WF_OVERRIDE="config" ;;
    *) TASK_ARGS+=("$arg") ;;
  esac
done

# Build chosen workflow list
declare -a WORKFLOWS=()

select_workflows_auto() {
  local p
  local chosen_docs=0 chosen_code=0 chosen_config=0
  for p in "${STAGED[@]}"; do
    # docs/specs markdown
    if [[ "$p" == docs/** || "$p" == *.md ]]; then chosen_docs=1; fi
    # code and tooling
    if [[ "$p" == tools/** || "$p" == src/** || "$p" == source/** ]]; then chosen_code=1; fi
    # configs
    if [[ "$p" == *.ini || "$p" == *.yaml || "$p" == *.yml || "$p" == *.json || "$p" == config/** ]]; then chosen_config=1; fi
  done
  (( chosen_docs ))   && WORKFLOWS+=("$WF_DOCS")
  (( chosen_code ))   && WORKFLOWS+=("$WF_CODE")
  (( chosen_config )) && WORKFLOWS+=("$WF_CONFIG")
}

case "$WF_OVERRIDE" in
  docs)   WORKFLOWS=("$WF_DOCS") ;;
  code)   WORKFLOWS=("$WF_CODE") ;;
  config) WORKFLOWS=("$WF_CONFIG") ;;
  *)      select_workflows_auto ;;
esac

# Default to docs if nothing matched
if (( ${#WORKFLOWS[@]} == 0 )); then
  WORKFLOWS=("$WF_DOCS")
fi

# Verify policies and chosen workflows exist
for f in "${POLICY_CORE[@]}" "${WORKFLOWS[@]}"; do
  if [[ ! -f "$ROOT/$f" ]]; then
    echo "Missing policy/workflow file: $f" >&2
    exit 2
  fi
done

# Ensure a task message exists
if (( ${#TASK_ARGS[@]} == 0 )); then
  echo "No task message provided. Example: bootstrap.sh \"Align X with template, ASCII only.\"" >&2
  exit 1
fi
TASK="${TASK_ARGS[*]}"

echo "Staged scope:"
printf ' - %s\n' "${STAGED[@]}"
echo "Workflows:"
printf ' - %s\n' "${WORKFLOWS[@]}"

# Build context list (absolute paths)
CONTEXT=()
for f in "${POLICY_CORE[@]}" "${WORKFLOWS[@]}"; do
  CONTEXT+=("$ROOT/$f")
done

# Invoke Codex CLI
# Replace `codex` with your real CLI.
npx codex \
  --context "${CONTEXT[@]}" \
  --files "${STAGED[@]}" \
  --task "$TASK"

# Tips:
# - For new files, stage intent first: git add -N path/to/newfile
# - Prefer running your codex with a dry-run flag if available
