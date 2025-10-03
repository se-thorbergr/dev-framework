#!/usr/bin/env bash

# LibConfig shared library (Bash implementation)
# Provides read-only configuration helpers, diff rendering, and schema lookups.

# shellcheck disable=SC2034
LIB_CONFIG_VERSION="v1"

declare -ga LIB_CONFIG_PYTHON_CMD=()

lib_config_init_python() {
  if [[ ${#LIB_CONFIG_PYTHON_CMD[@]} -gt 0 ]]; then
    return 0
  fi

  if [[ ${#PYTHON_CMD[@]} -gt 0 ]]; then
    LIB_CONFIG_PYTHON_CMD=("${PYTHON_CMD[@]}")
    return 0
  fi

  if [[ -n "$PYTHON" && -x $(command -v "$PYTHON" >/dev/null 2>&1) ]]; then
    LIB_CONFIG_PYTHON_CMD=("$PYTHON")
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    LIB_CONFIG_PYTHON_CMD=(python3)
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    LIB_CONFIG_PYTHON_CMD=(python)
    return 0
  fi

  if command -v py >/dev/null 2>&1; then
    LIB_CONFIG_PYTHON_CMD=(py -3)
    return 0
  fi

  return 1
}

config_diff_local() {
  local effective_json="$1"
  local desired_json="$2"

  if ! lib_config_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_CONFIG_PYTHON_CMD[@]}" - "$effective_json" "$desired_json" <<'PYCODE'
import json, sys

def normalize_section(section):
    if isinstance(section, dict):
        return section
    return {}

def stringify(value):
    if value is None:
        return ''
    return str(value)

def compute_diff(effective, desired):
    changes = []
    sections = set(effective.keys()) | set(desired.keys())
    for section in sorted(sections):
        eff_section = normalize_section(effective.get(section))
        des_section = normalize_section(desired.get(section))
        eff_keys = set(eff_section.keys())
        des_keys = set(des_section.keys())

        for key in sorted(des_keys - eff_keys):
            changes.append({
                "action": "add",
                "section": section,
                "key": key,
                "old": None,
                "new": stringify(des_section[key])
            })

        for key in sorted(eff_keys & des_keys):
            old = stringify(eff_section.get(key))
            new = stringify(des_section.get(key))
            if old != new:
                changes.append({
                    "action": "update",
                    "section": section,
                    "key": key,
                    "old": old,
                    "new": new
                })

        for key in sorted(eff_keys - des_keys):
            changes.append({
                "action": "remove",
                "section": section,
                "key": key,
                "old": stringify(eff_section.get(key)),
                "new": None
            })
    return changes

try:
    effective = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
    desired = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    diff = {"changes": compute_diff(effective, desired)}
    sys.stdout.write(json.dumps(diff, ensure_ascii=True))
except Exception as exc:
    sys.stderr.write(f"config_diff_local error: {exc}\n")
    sys.exit(1)
PYCODE
}

ini_render() {
  local diff_json="$1"

  if ! lib_config_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_CONFIG_PYTHON_CMD[@]}" - "$diff_json" <<'PYCODE'
import json, sys

def render_ini(diff):
    changes = diff.get("changes", [])
    sections = {}
    for change in changes:
        if change.get("action") not in {"add", "update"}:
            continue
        section = change.get("section") or ""
        sections.setdefault(section, []).append((change.get("key"), change.get("new", "")))

    lines = []
    for section in sorted(sections.keys()):
        if section:
            lines.append(f"[{section}]")
        for key, value in sections[section]:
            lines.append(f"{key}={value}")
    return "\n".join(lines)

try:
    diff = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
    sys.stdout.write(render_ini(diff))
except Exception as exc:
    sys.stderr.write(f"ini_render error: {exc}\n")
    sys.exit(1)
PYCODE
}

config_schema_get() {
  local name="$1"

  if ! lib_config_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_CONFIG_PYTHON_CMD[@]}" - "$name" <<'PYCODE'
import json, sys

name = (sys.argv[1] if len(sys.argv) > 1 else '').lower()

schemas = {
    'se-config.ini': {
        'name': 'se-config.ini',
        'version': 'v1',
        'sections': {
            'general': {
                'keys': ['binarypath', 'output', 'steam_path', 'game_path'],
                'required': ['binarypath', 'output']
            },
            'mdk': {
                'keys': ['output', 'binarypath'],
                'required': ['output']
            }
        }
    }
}

schema = schemas.get(name)
if schema:
    sys.stdout.write(json.dumps(schema, ensure_ascii=True))
else:
    sys.stdout.write('')
PYCODE
}

# Placeholder discovery helpers (stubs to satisfy callers)
config_sources() {
  :
}

config_read() {
  :
}

config_merge() {
  :
}

config_validate() {
  :
}

config_effective() {
  :
}
