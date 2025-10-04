#!/usr/bin/env bash

# LibDotnetProj shared library (Bash implementation)
# Provides read/inspect/plan helpers for MSBuild project files.

# shellcheck disable=SC2034
LIB_DOTNETPROJ_VERSION="v1"

declare -ga LIB_DOTNETPROJ_PYTHON_CMD=()

dotproj_init_python() {
  if [[ ${#LIB_DOTNETPROJ_PYTHON_CMD[@]} -gt 0 ]]; then
    return 0
  fi

  if [[ -n "$PYTHON" && -x $(command -v "$PYTHON" 2> /dev/null) ]]; then
    LIB_DOTNETPROJ_PYTHON_CMD=("$PYTHON")
    return 0
  fi

  if command -v python3 > /dev/null 2>&1; then
    LIB_DOTNETPROJ_PYTHON_CMD=(python3)
    return 0
  fi

  if command -v python > /dev/null 2>&1; then
    LIB_DOTNETPROJ_PYTHON_CMD=(python)
    return 0
  fi

  if command -v py > /dev/null 2>&1; then
    LIB_DOTNETPROJ_PYTHON_CMD=(py -3)
    return 0
  fi

  return 1
}

dotproj_read() {
  local path="$1"
  if ! dotproj_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_DOTNETPROJ_PYTHON_CMD[@]}" - "$path" << 'PY'
import json, os, sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
if not os.path.isfile(path):
    print(json.dumps({'error': f'Project not found: {path}'}, ensure_ascii=True))
    raise SystemExit(1)

with open(path, encoding='utf-8') as handle:
    xml_text = handle.read()

try:
    root = ET.fromstring(xml_text)
except ET.ParseError:
    print(json.dumps({'error': f'Invalid project XML: {path}'}, ensure_ascii=True))
    raise SystemExit(1)

kind = {
    '.csproj': 'csproj',
    '.shproj': 'shproj',
    '.projitems': 'projitems'
}.get(os.path.splitext(path)[1].lower(), 'unknown')

properties = {}
for property_group in root.findall('PropertyGroup'):
    for child in list(property_group):
        if child.tag not in properties:
            properties[child.tag] = (child.text or '').strip()

items = []
for item_group in root.findall('ItemGroup'):
    for child in list(item_group):
        metadata = {meta.tag: (meta.text or '').strip() for meta in list(child)}
        items.append({
            'item': child.tag,
            'include': child.attrib.get('Include'),
            'metadata': metadata
        })

imports = []
for imp in root.findall('Import'):
    imports.append({
        'project': imp.attrib.get('Project'),
        'label': imp.attrib.get('Label'),
        'condition': imp.attrib.get('Condition')
    })

model = {
    'path': os.path.abspath(path),
    'kind': kind,
    'properties': properties,
    'items': items,
    'imports': imports
}

print(json.dumps({'kind': kind, 'xml': xml_text, 'model': model}, ensure_ascii=True))
PY
}

dotproj_validate_pbscript() {
  local model_json="$1"
  if ! dotproj_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_DOTNETPROJ_PYTHON_CMD[@]}" - "$model_json" << 'PY'
import json, sys

model = json.loads(sys.argv[1])
errors = []
warnings = []

if model.get('kind') != 'csproj':
    errors.append('PB Script projects must be csproj files.')

properties = model.get('properties') or {}
if 'TargetFramework' not in properties:
    errors.append('TargetFramework property missing.')

print(json.dumps({'is_valid': not errors, 'errors': errors, 'warnings': warnings}, ensure_ascii=True))
PY
}

dotproj_validate_mixin() {
  echo '{"is_valid": true, "errors": [], "warnings": []}'
}

dotproj_plan_import_shared() {
  local model_json="$1"
  local projitems_path="$2"
  if ! dotproj_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_DOTNETPROJ_PYTHON_CMD[@]}" - "$model_json" "$projitems_path" << 'PY'
import json, sys

model = json.loads(sys.argv[1])
projitems_path = sys.argv[2]
imports = model.get('imports') or []
existing = [imp for imp in imports if (imp.get('project') == projitems_path and (imp.get('label') or 'Shared') == 'Shared')]

actions = []
if not existing:
    actions.append({'op': 'ensure-import', 'project': projitems_path, 'label': 'Shared', 'before': None})

print(json.dumps({'actions': actions, 'conflicts': []}, ensure_ascii=True))
PY
}

dotproj_plan_add_item() {
  local model_json="$1"
  local item="$2"
  local include="$3"
  local metadata_json="$4"
  if ! dotproj_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_DOTNETPROJ_PYTHON_CMD[@]}" - "$model_json" "$item" "$include" "$metadata_json" << 'PY'
import json, sys

model = json.loads(sys.argv[1])
model = model.get('model', model)
item = sys.argv[2]
include = sys.argv[3]
metadata_json = sys.argv[4]
metadata = json.loads(metadata_json) if metadata_json else {}

items = model.get('items') or []
exists = any(entry.get('item') == item and entry.get('include') == include for entry in items)

actions = []
if not exists:
    actions.append({'op': 'ensure-item', 'item': item, 'include': include, 'metadata': metadata})

print(json.dumps({'actions': actions, 'conflicts': []}, ensure_ascii=True))
PY
}

dotproj_plan_set_property() {
  local model_json="$1"
  local name="$2"
  local value="$3"
  if ! dotproj_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_DOTNETPROJ_PYTHON_CMD[@]}" - "$model_json" "$name" "$value" << 'PY'
import json, sys

model = json.loads(sys.argv[1])
model = model.get('model', model)
name = sys.argv[2]
value = sys.argv[3]
properties = model.get('properties') or {}

actions = []
if properties.get(name) != value:
    actions.append({'op': 'ensure-property', 'name': name, 'value': value})

print(json.dumps({'actions': actions, 'conflicts': []}, ensure_ascii=True))
PY
}

dotproj_plan_remove() {
  local selector="$1"
  echo "{\"actions\":[{\"op\":\"remove\",\"selector\":\"$selector\"}],\"conflicts\":[]}" | tr -d '\n'
}

dotproj_plan_validate() {
  local actions_json="$1"
  if ! dotproj_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_DOTNETPROJ_PYTHON_CMD[@]}" - "$actions_json" << 'PY'
import json, sys

actions = json.loads(sys.argv[1]).get('actions', [])
errors = []
warnings = []

imports = {}
for action in actions:
    if action.get('op') == 'ensure-import' and action.get('project'):
        imports.setdefault(action['project'], set()).add(action.get('label') or '')

for project, labels in imports.items():
    if len(labels) > 1:
        errors.append(f"Conflicting ensure-import actions for project '{project}'.")

print(json.dumps({'is_valid': not errors, 'errors': errors, 'warnings': warnings}, ensure_ascii=True))
PY
}

dotproj_plan_render() {
  local actions_json="$1"
  local header="$2"
  if ! dotproj_init_python; then
    echo "python interpreter not available" >&2
    return 1
  fi

  "${LIB_DOTNETPROJ_PYTHON_CMD[@]}" - "$actions_json" "$header" << 'PY'
import json, sys

actions = json.loads(sys.argv[1]).get('actions', [])
header = sys.argv[2]
lines = []
if header:
    lines.append(header)

for action in actions:
    op = action.get('op')
    if op == 'ensure-import':
        lines.append(f"ensure-import -> {action.get('project')} [Label={action.get('label')}]")
    elif op == 'ensure-property':
        lines.append(f"ensure-property -> {action.get('name')}={action.get('value')}")
    elif op == 'ensure-item':
        lines.append(f"ensure-item -> {action.get('item')} Include={action.get('include')}")
    elif op == 'remove':
        lines.append(f"remove -> {action.get('selector')}")
    else:
        lines.append(op or 'unknown')

print('\n'.join(lines))
PY
}
