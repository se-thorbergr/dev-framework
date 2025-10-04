#!/usr/bin/env bash

# LibMDK2 shared library (Bash implementation)
# Provides MDK2 configuration discovery, parsing, and validation helpers.

# shellcheck disable=SC2034
LIB_MDK2_VERSION="v1"

declare -ga LIB_MDK2_PYTHON_CMD=()

mdk2_init_python() {
  if [[ ${#LIB_MDK2_PYTHON_CMD[@]} -gt 0 ]]; then
    return 0
  fi

  if [[ -n "$PYTHON" && -x $(command -v "$PYTHON" 2> /dev/null) ]]; then
    LIB_MDK2_PYTHON_CMD=("$PYTHON")
    return 0
  fi

  if command -v python3 > /dev/null 2>&1; then
    LIB_MDK2_PYTHON_CMD=(python3)
    return 0
  fi

  if command -v python > /dev/null 2>&1; then
    LIB_MDK2_PYTHON_CMD=(python)
    return 0
  fi

  if command -v py > /dev/null 2>&1; then
    LIB_MDK2_PYTHON_CMD=(py -3)
    return 0
  fi

  return 1
}

mdk2_configs() {
  local root="$1"
  shift
  local patterns=("$@")
  if [[ ${#patterns[@]} -eq 0 ]]; then
    patterns=("*.mdk.ini" "*.mdk.local.ini")
  fi

  if ! mdk2_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_MDK2_PYTHON_CMD[@]}" - "$root" "${patterns[@]}" << 'PY'
import fnmatch, json, os, sys

if len(sys.argv) < 2:
    print(json.dumps({"paths": []}, ensure_ascii=True))
    raise SystemExit(0)

root = os.path.abspath(sys.argv[1])
patterns = sys.argv[2:] or ['*.mdk.ini', '*.mdk.local.ini']
if not os.path.isdir(root):
    print(json.dumps({"paths": []}, ensure_ascii=True))
    raise SystemExit(0)

paths = []
for current, _, files in os.walk(root):
    for pattern in patterns:
        for name in fnmatch.filter(files, pattern):
            paths.append(os.path.join(current, name))

print(json.dumps({"paths": sorted(paths)}, ensure_ascii=True))
PY
}

mdk2_read() {
  local path="$1"
  if ! mdk2_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_MDK2_PYTHON_CMD[@]}" - "$path" << 'PY'
import configparser, json, os, sys

path = sys.argv[1]
if not os.path.isfile(path):
    print(json.dumps({"error": f"Config not found: {path}"}, ensure_ascii=True))
    raise SystemExit(1)

parser = configparser.ConfigParser()
parser.optionxform = lambda option: option.lower()
parser.read(path, encoding='utf-8')

sections = {}
for section in parser.sections():
    normalized = section.lower()
    sections[normalized] = {k: v.strip() for k, v in parser.items(section)}

print(json.dumps({
    "source": os.path.abspath(path),
    "data": sections
}, ensure_ascii=True))
PY
}

mdk2_project_info() {
  local project_root="$1"
  if ! mdk2_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_MDK2_PYTHON_CMD[@]}" - "$project_root" << 'PY'
import json, os, sys

project_root = os.path.abspath(sys.argv[1])
mdk_dir = os.path.join(project_root, 'MDK')
scripts_dir = os.path.join(project_root, 'Scripts')
notes = []

has_templates = os.path.isdir(mdk_dir)
if not has_templates:
    notes.append('MDK templates directory missing.')

template_version = None
version_path = os.path.join(mdk_dir, 'Templates.version.txt')
if os.path.isfile(version_path):
    with open(version_path, encoding='utf-8') as handle:
        first_line = handle.readline().strip()
        if first_line:
            template_version = first_line

scripts_path = scripts_dir if os.path.isdir(scripts_dir) else None
if scripts_path is None:
    notes.append('Scripts directory missing.')

print(json.dumps({
    'has_templates': has_templates,
    'template_version': template_version,
    'scripts_path': scripts_path,
    'notes': notes
}, ensure_ascii=True))
PY
}

mdk2_validate_config() {
  local json_payload="$1"
  if ! mdk2_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_MDK2_PYTHON_CMD[@]}" - "$json_payload" << 'PY'
import json, sys

payload = json.loads(sys.argv[1])
data = payload.get('data') or {}
mdk = data.get('mdk')
errors = []
warnings = []

allowed_types = {'programmableblock', 'mod'}
allowed_trace = {'on', 'off'}
allowed_minify = {'none', 'trim', 'stripcomments', 'lite', 'full'}

if not isinstance(mdk, dict):
    errors.append('Missing [mdk] section.')
else:
    value = mdk.get('type')
    if value is None:
        errors.append('Missing key mdk.type.')
    elif value.lower() not in allowed_types:
        errors.append(f"Invalid mdk.type value '{value}'.")

    trace = mdk.get('trace')
    if trace is not None and trace.lower() not in allowed_trace:
        warnings.append(f"Unexpected mdk.trace value '{trace}'.")

    minify = mdk.get('minify')
    if minify is not None and minify.lower() not in allowed_minify:
        warnings.append(f"Unsupported mdk.minify value '{minify}'.")

print(json.dumps({
    'is_valid': not errors,
    'errors': errors,
    'warnings': warnings
}, ensure_ascii=True))
PY
}

mdk2_validate_project() {
  local project_root="$1"
  local min_template="$2"

  if ! mdk2_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_MDK2_PYTHON_CMD[@]}" - "$project_root" "$min_template" << 'PY'
import configparser, fnmatch, json, os, sys

project_root = os.path.abspath(sys.argv[1])
min_template = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
patterns = ['*.mdk.ini', '*.mdk.local.ini']
keys_to_compare = ['type', 'trace', 'minify', 'ignores', 'donotclean', 'output', 'binarypath']
allowed_types = {'programmableblock', 'mod'}
allowed_trace = {'on', 'off'}
allowed_minify = {'none', 'trim', 'stripcomments', 'lite', 'full'}

errors = []
warnings = []

config_paths = []
if os.path.isdir(project_root):
    for current, _, files in os.walk(project_root):
        for pattern in patterns:
            for name in fnmatch.filter(files, pattern):
                config_paths.append(os.path.join(current, name))
config_paths.sort()

if not config_paths:
    errors.append('MDK-001: No MDK2 configs found.')

records = []
for path in config_paths:
    parser = configparser.ConfigParser()
    parser.optionxform = lambda option: option.lower()
    try:
        parser.read(path, encoding='utf-8')
    except Exception as exc:  # pragma: no cover
        errors.append(f"MDK-002: Failed to read {path}. {exc}")
        continue
    data = {section.lower(): {k: v.strip() for k, v in parser.items(section)} for section in parser.sections()}
    mdk = data.get('mdk')
    if mdk is None:
        errors.append(f"{path}: Missing [mdk] section.")
    else:
        type_value = mdk.get('type')
        if type_value is None:
            errors.append(f"{path}: Missing key mdk.type.")
        elif type_value.lower() not in allowed_types:
            errors.append(f"{path}: Invalid mdk.type value '{type_value}'.")

        trace_value = mdk.get('trace')
        if trace_value is not None and trace_value.lower() not in allowed_trace:
            warnings.append(f"{path}: Unexpected mdk.trace value '{trace_value}'.")

        minify_value = mdk.get('minify')
        if minify_value is not None and minify_value.lower() not in allowed_minify:
            warnings.append(f"{path}: Unsupported mdk.minify value '{minify_value}'.")
    records.append({'path': path, 'data': data})

for key in keys_to_compare:
    entries = []
    for record in records:
        mdk = record['data'].get('mdk')
        if mdk and key in mdk:
            entries.append({'path': record['path'], 'value': mdk[key]})
    if len(entries) <= 1:
        continue
    if key in {'output', 'binarypath'}:
        continue
    values = {}
    for entry in entries:
        values.setdefault(entry['value'], []).append(os.path.basename(entry['path']))
    if len(values) > 1:
        details = '; '.join(f"{', '.join(sorted(paths))} -> {value}" for value, paths in values.items())
        warnings.append(f"mdk.{key} differs between configs: {details}")

mdk_dir = os.path.join(project_root, 'MDK')
scripts_dir = os.path.join(project_root, 'Scripts')
notes = []
has_templates = os.path.isdir(mdk_dir)
if not has_templates:
    notes.append('MDK templates directory missing.')

template_version = None
version_path = os.path.join(mdk_dir, 'Templates.version.txt')
if os.path.isfile(version_path):
    with open(version_path, encoding='utf-8') as handle:
        first_line = handle.readline().strip()
        if first_line:
            template_version = first_line

scripts_path = scripts_dir if os.path.isdir(scripts_dir) else None
if scripts_path is None:
    notes.append('Scripts directory missing.')

if min_template:
    if template_version:
        def parse_version(text):
            parts = []
            for chunk in text.split('.'):
                try:
                    parts.append(int(chunk))
                except ValueError:
                    parts.append(0)
            return tuple(parts)

        try:
            actual = parse_version(template_version)
            required = parse_version(min_template)
            if actual < required:
                errors.append(f"MDK-003: Template version {template_version} below required {min_template}.")
        except Exception:
            warnings.append(f"Template version '{template_version}' could not be parsed.")
    else:
        warnings.append('Template version unavailable; minimum cannot be enforced.')

print(json.dumps({
    'is_valid': not errors,
    'errors': errors,
    'warnings': warnings,
    'info': {
        'has_templates': has_templates,
        'template_version': template_version,
        'scripts_path': scripts_path,
        'notes': notes
    },
    'config_paths': config_paths
}, ensure_ascii=True))
PY
}

mdk2_render_summary() {
  local json_payload="$1"
  if ! mdk2_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_MDK2_PYTHON_CMD[@]}" - "$json_payload" << 'PY'
import json, sys

diag = json.loads(sys.argv[1])
status = 'passed' if diag.get('is_valid') else 'failed'
errors = len(diag.get('errors') or [])
warnings = len(diag.get('warnings') or [])
print(f"mdk2 validation: {status}\nerrors: {errors}\nwarnings: {warnings}")
PY
}
