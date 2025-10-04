#!/usr/bin/env bash

# LibFs shared library (Bash implementation)
# Provides filesystem planning helpers; callers own any execution of plans.

LIB_FS_VERSION="v1"

declare -ga LIB_FS_PYTHON_CMD=()
declare -ga LIB_FS_PROTECTED_PATTERNS=("*.mdk.ini" "se-config.ini")

lib_fs_init_python() {
  if [[ ${#LIB_FS_PYTHON_CMD[@]} -gt 0 ]]; then
    return 0
  fi

  if [[ -n "$PYTHON" && -x $(command -v "$PYTHON" 2>/dev/null) ]]; then
    LIB_FS_PYTHON_CMD=("$PYTHON")
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    LIB_FS_PYTHON_CMD=(python3)
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    LIB_FS_PYTHON_CMD=(python)
    return 0
  fi

  if command -v py >/dev/null 2>&1; then
    LIB_FS_PYTHON_CMD=(py -3)
    return 0
  fi

  return 1
}

fs_normalize() {
  local path="$1"
  if ! lib_fs_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi
  "${LIB_FS_PYTHON_CMD[@]}" - "$path" <<'PY'
import os, sys
print(os.path.abspath(sys.argv[1]))
PY
}

fs_plan_ensure_dir() {
  local path="$1"
  if ! lib_fs_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi
  "${LIB_FS_PYTHON_CMD[@]}" - "$path" <<'PY'
import json, os, sys
path = os.path.abspath(sys.argv[1])
actions = []
if not os.path.isdir(path):
    actions.append({"op": "mkdir", "path": path})
print(json.dumps({"actions": actions, "conflicts": []}, ensure_ascii=True))
PY
}

fs_plan_ensure_file() {
  local path="$1"
  local content="$2"
  local mode="${3:-create}"
  if ! lib_fs_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi
  "${LIB_FS_PYTHON_CMD[@]}" - "$path" "$content" "$mode" <<'PY'
import json, os, sys, hashlib
path = os.path.abspath(sys.argv[1])
content = sys.argv[2]
mode = sys.argv[3]
actions = []
conflicts = []
encoding = 'utf-8'
desired_hash = hashlib.sha256(content.encode(encoding)).hexdigest()
exists = os.path.isfile(path)
existing_hash = None
if exists:
    with open(path, 'rb') as fh:
        existing_hash = hashlib.sha256(fh.read()).hexdigest()

def build_action(include_diff):
    action = {
        "op": "write",
        "path": path,
        "content": content,
        "mode": mode,
        "encoding": encoding,
        "hash": desired_hash,
        "hashAlgorithm": "sha256",
    }
    if include_diff and existing_hash and existing_hash != desired_hash:
        action["diff"] = {
            "oldHash": existing_hash,
            "newHash": desired_hash,
            "hashAlgorithm": "sha256",
        }
    return action

if mode == 'create':
    if exists:
        conflicts.append({"op": "write", "path": path, "reason": "File exists; use overwrite or if-changed."})
    else:
        actions.append(build_action(False))
elif mode == 'overwrite':
    actions.append(build_action(True))
elif mode == 'if-changed':
    if exists:
        if existing_hash != desired_hash:
            actions.append(build_action(True))
    else:
        actions.append(build_action(False))
else:
    raise SystemExit(f"Unsupported mode: {mode}")
print(json.dumps({"actions": actions, "conflicts": conflicts}, ensure_ascii=True))
PY
}

fs_plan_validate() {
  local plan_json=""
  local -a protected_patterns=()
  if [[ ${#LIB_FS_PROTECTED_PATTERNS[@]} -gt 0 ]]; then
    protected_patterns=(${LIB_FS_PROTECTED_PATTERNS[@]})
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --plan-json)
        plan_json="$2"
        shift 2
        ;;
      --protected-pattern)
        protected_patterns+=("$2")
        shift 2
        ;;
      *)
        echo "Unknown argument: $1" >&2
        return 1
        ;;
    esac
  done
  if [[ -z "$plan_json" ]]; then
    echo "plan-json argument is required" >&2
    return 1
  fi
  if ! lib_fs_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_FS_PYTHON_CMD[@]}" - "$plan_json" "${protected_patterns[@]}" <<'PY'
import fnmatch, json, os, sys

plan = json.loads(sys.argv[1])
protected_patterns = sys.argv[2:]

def is_protected(path: str) -> bool:
    if not path:
        return False
    normalized = os.path.abspath(path)
    basename = os.path.basename(normalized)
    lower = normalized.lower()
    if lower.endswith('.local.ini'):
        return False
    for pattern in protected_patterns:
        if not pattern:
            continue
        if fnmatch.fnmatch(normalized, pattern) or fnmatch.fnmatch(basename, pattern):
            return True
    return False

errors = []
warnings = []
valid_ops = {'mkdir', 'write', 'copy', 'move'}

conflicts = plan.get('conflicts', [])
if conflicts:
    errors.append('Plan contains conflicts; refusing to validate')

for action in plan.get('actions', []):
    op = action.get('op')
    if op not in valid_ops:
        errors.append(f"Unsupported action op '{op}'")
        continue

    if op == 'write':
        path = action.get('path')
        if not path:
            errors.append('Write action missing path')
        elif is_protected(path):
            errors.append(f'Write action targets protected path: {path}')
    elif op in {'copy', 'move'}:
        dest = action.get('destination')
        if not action.get('source') or not dest:
            errors.append(f"{op} action missing source or destination")
        elif is_protected(dest):
            errors.append(f"{op} action targets protected destination: {dest}")

result = {
    'isValid': not errors,
    'errors': errors,
    'warnings': warnings,
}
print(json.dumps(result, ensure_ascii=True))
PY
}

fs_plan_render() {
  local plan_json="$1"
  local header="$2"
  if [[ -z "$plan_json" ]]; then
    echo "plan-json argument is required" >&2
    return 1
  fi
  if ! lib_fs_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi
  "${LIB_FS_PYTHON_CMD[@]}" - "$plan_json" "$header" <<'PY'
import json, sys

plan = json.loads(sys.argv[1])
header = sys.argv[2]
lines = []
if header:
    lines.append(header)

for action in plan.get('actions', []):
    op = action.get('op')
    if op == 'mkdir':
        lines.append(f"mkdir -> {action.get('path')}")
    elif op == 'write':
        mode = action.get('mode', 'create')
        lines.append(f"write({mode}) -> {action.get('path')}")
    elif op == 'copy':
        lines.append(f"copy -> {action.get('source')} -> {action.get('destination')}")
    elif op == 'move':
        lines.append(f"move -> {action.get('source')} -> {action.get('destination')}")

for conflict in plan.get('conflicts', []):
    lines.append(f"conflict -> {conflict}")

print("\n".join(lines))
PY
}
