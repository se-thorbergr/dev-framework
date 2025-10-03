#!/usr/bin/env bats

load_helper() {
  LIB_PATH="${BATS_TEST_DIRNAME}/../../lib/config.sh"
  if [[ ! -f "$LIB_PATH" ]]; then
    echo "LibConfig library not found at $LIB_PATH" >&2
    return 1
  fi
  # shellcheck source=/dev/null
  source "$LIB_PATH"
}

find_python() {
  if [[ -n "$PYTHON" && -x $(command -v "$PYTHON" 2>/dev/null) ]]; then
    PYTHON_CMD=("$PYTHON")
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=(python3)
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    PYTHON_CMD=(python)
    return 0
  fi

  if command -v py >/dev/null 2>&1; then
    PYTHON_CMD=(py -3)
    return 0
  fi

  echo "Python interpreter not found" >&2
  return 1
}

setup() {
  load_helper
  find_python || skip "Python interpreter required"
}

@test "config_diff_local emits per-key actions" {
  effective='{"general":{"keep":"1","obsolete":"old","change":"initial"}}'
  desired='{"general":{"keep":"1","change":"updated","newkey":"2"}}'

  run config_diff_local "$effective" "$desired"
  [ "$status" -eq 0 ]
  diff_json="$output"

  remove_action=$("${PYTHON_CMD[@]}" -c 'import json,sys; data=json.loads(sys.stdin.read()); removed=[c for c in data.get("changes",[]) if c.get("action")=="remove" and c.get("section")=="general" and c.get("key")=="obsolete"]; print(len(removed))' <<<"$diff_json")
  [[ "$remove_action" == "1" ]]

  add_action=$("${PYTHON_CMD[@]}" -c 'import json,sys; data=json.loads(sys.stdin.read()); added=[c for c in data.get("changes",[]) if c.get("action")=="add" and c.get("key")=="newkey" and c.get("new")=="2"]; print(len(added))' <<<"$diff_json")
  [[ "$add_action" == "1" ]]

  update_action=$("${PYTHON_CMD[@]}" -c 'import json,sys; data=json.loads(sys.stdin.read()); updated=[c for c in data.get("changes",[]) if c.get("action")=="update" and c.get("key")=="change" and c.get("old")=="initial" and c.get("new")=="updated"]; print(len(updated))' <<<"$diff_json")
  [[ "$update_action" == "1" ]]

  run ini_render "$diff_json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[general]"* ]]
  [[ "$output" == *"newkey=2"* ]]
  [[ "$output" == *"change=updated"* ]]
  [[ "$output" != *"obsolete"* ]]
}

@test "config_schema_get returns built-in schemas" {
  run config_schema_get "se-config.ini"
  [ "$status" -eq 0 ]
  schema_json="$output"
  name=$("${PYTHON_CMD[@]}" -c 'import json,sys; data=json.loads(sys.stdin.read()); print(data.get("name"))' <<<"$schema_json")
  [[ "$name" == "se-config.ini" ]]

  has_binarypath=$("${PYTHON_CMD[@]}" -c 'import json,sys; data=json.loads(sys.stdin.read()); sections=data.get("sections",{}); general=sections.get("general",{}); print("binarypath" in general.get("keys",[]))' <<<"$schema_json")
  [[ "$has_binarypath" == "True" ]]

  run config_schema_get "does-not-exist"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}
