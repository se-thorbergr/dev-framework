#!/usr/bin/env bats

load_helper() {
  LIB_PATH="${BATS_TEST_DIRNAME}/../../lib/mdk2.sh"
  if [[ ! -f "$LIB_PATH" ]]; then
    echo "LibMDK2 library not found at $LIB_PATH" >&2
    return 1
  fi
  # shellcheck source=/dev/null
  source "$LIB_PATH"
}

setup() {
  load_helper || skip "LibMDK2 shell library not present"
}

@test "mdk2_configs returns sorted paths" {
  tmp_dir="$BATS_TEST_TMPDIR/configs"
  mkdir -p "$tmp_dir"
  printf '[mdk]\ntype=programmableblock\n' >"$tmp_dir/Alpha.mdk.ini"
  printf '[mdk]\noutput=auto\n' >"$tmp_dir/Alpha.mdk.local.ini"

  run mdk2_configs "$tmp_dir"
  [ "$status" -eq 0 ]
first=$(python3 - "$output" <<'PY'
import json, sys
paths = json.loads(sys.argv[1]).get('paths', [])
print(paths[0] if len(paths) > 0 else '')
PY
)
second=$(python3 - "$output" <<'PY'
import json, sys
paths = json.loads(sys.argv[1]).get('paths', [])
print(paths[1] if len(paths) > 1 else '')
PY
)
  [[ "$first" == "$tmp_dir/Alpha.mdk.ini" ]]
  [[ "$second" == "$tmp_dir/Alpha.mdk.local.ini" ]]
}

@test "mdk2_read parses ini data" {
  tmp_dir="$BATS_TEST_TMPDIR/read"
  mkdir -p "$tmp_dir"
  printf '[mdk]\nminify=trim\ntrace=off\n' >"$tmp_dir/Beta.mdk.ini"

  run mdk2_read "$tmp_dir/Beta.mdk.ini"
  [ "$status" -eq 0 ]
  minify=$(python3 - "$output" <<'PY'
import json, sys
print(json.loads(sys.argv[1])['data']['mdk']['minify'])
PY
)
  [[ "$minify" == "trim" ]]
}

@test "mdk2_validate_config detects missing section" {
  run mdk2_validate_config '{"data": {"other": {"key": "value"}}}'
  [ "$status" -eq 0 ]
  is_valid=$(python3 - "$output" <<'PY'
import json, sys
print(json.loads(sys.argv[1]).get('is_valid'))
PY
)
  [[ "$is_valid" == "False" ]]
}

@test "mdk2_validate_project returns diagnostics" {
  tmp_dir="$BATS_TEST_TMPDIR/project"
  mkdir -p "$tmp_dir/MDK" "$tmp_dir/Scripts"
  printf '[mdk]\ntype=programmableblock\ntrace=off\nminify=none\n' >"$tmp_dir/Project.mdk.ini"
  printf '[mdk]\ntype=mod\noutput=auto\n' >"$tmp_dir/Project.mdk.local.ini"
  printf '2.2.31' >"$tmp_dir/MDK/Templates.version.txt"

  run mdk2_validate_project "$tmp_dir" "2.2.0"
  [ "$status" -eq 0 ]
  is_valid=$(python3 - "$output" <<'PY'
import json, sys
print(json.loads(sys.argv[1]).get('is_valid'))
PY
)
  [[ "$is_valid" == "True" ]]
}

@test "mdk2_render_summary reports counts" {
  diag='{"is_valid": false, "errors": ["MDK-001"], "warnings": ["conflict"]}'
  run mdk2_render_summary "$diag"
  [ "$status" -eq 0 ]
  [[ "$output" == *"errors: 1"* ]]
}
