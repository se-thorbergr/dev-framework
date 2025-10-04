#!/usr/bin/env bats

load_helper() {
  LIB_PATH="${BATS_TEST_DIRNAME}/../../lib/fs.sh"
  if [[ ! -f "$LIB_PATH" ]]; then
    echo "LibFs library not found at $LIB_PATH" >&2
    return 1
  fi
  # shellcheck source=/dev/null
  source "$LIB_PATH"
}

setup() {
  load_helper || skip "LibFs shell library not present"
}

compact_plan() {
  lib_fs_init_python || {
    echo "python interpreter not available" >&2
    return 1
  }
  "${LIB_FS_PYTHON_CMD[@]}" - <<'PY' "$@"
import json, sys
plan = {"actions": [], "conflicts": []}
for arg in sys.argv[1:]:
    piece = json.loads(arg)
    plan["actions"].extend(piece.get("actions", []))
    plan["conflicts"].extend(piece.get("conflicts", []))
print(json.dumps(plan, ensure_ascii=True))
PY
}

@test "planning emits actions without mutating the filesystem" {
  tmp_dir="$BATS_TEST_TMPDIR/plan"
  mkdir -p "$tmp_dir"
  dir_path="$tmp_dir/data"
  file_path="$dir_path/note.txt"

  plan_dir=$(fs_plan_ensure_dir "$dir_path") || skip "plan helper missing"
  plan_file=$(fs_plan_ensure_file "$file_path" "hello world" "create") || skip "file plan helper missing"
  plan_json=$(compact_plan "$plan_dir" "$plan_file")

  [[ ! -d "$dir_path" ]]
  [[ ! -f "$file_path" ]]

  validation=$(fs_plan_validate --plan-json "$plan_json")
  echo "validation: $validation"
  is_valid=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("isValid"))' <<<"$validation")
  [[ "$is_valid" == "True" ]]

  rendered=$(fs_plan_render "$plan_json" "plan:")
  echo "$rendered"
  [[ "$rendered" == *"write"* ]]
}

@test "if-changed includes diff metadata" {
  tmp_dir="$BATS_TEST_TMPDIR/diff"
  mkdir -p "$tmp_dir"
  file_path="$tmp_dir/config.ini"
  printf 'old value' >"$file_path"

  plan_json=$(fs_plan_ensure_file "$file_path" "new value" "if-changed")
  echo "plan: $plan_json"

  diff_present=$(python3 -c 'import json,sys; plan=json.loads(sys.stdin.read()); actions=plan.get("actions", []);
if actions:
    diff=actions[0].get("diff"); print("yes" if diff and diff.get("oldHash") and diff.get("newHash") else "no")
else:
    print("no")' <<<"$plan_json")
  [[ "$diff_present" == "yes" ]]
}

@test "protected paths are rejected" {
  tmp_dir="$BATS_TEST_TMPDIR/protected"
  mkdir -p "$tmp_dir"
  plan_json=$(fs_plan_ensure_file "$tmp_dir/Project.mdk.ini" "unsafe" "create")
  validation=$(fs_plan_validate --plan-json "$plan_json")
  echo "$validation"
  is_valid=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("isValid"))' <<<"$validation")
  [[ "$is_valid" == "False" ]]
}

@test "local overrides are permitted" {
  tmp_dir="$BATS_TEST_TMPDIR/local"
  mkdir -p "$tmp_dir"
  plan_json=$(fs_plan_ensure_file "$tmp_dir/Project.mdk.local.ini" "safe" "create")
  validation=$(fs_plan_validate --plan-json "$plan_json")
  is_valid=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("isValid"))' <<<"$validation")
  [[ "$is_valid" == "True" ]]
}

@test "se-config base file is protected" {
  tmp_dir="$BATS_TEST_TMPDIR/se-base"
  mkdir -p "$tmp_dir"
  plan_json=$(fs_plan_ensure_file "$tmp_dir/se-config.ini" "auto" "create")
  validation=$(fs_plan_validate --plan-json "$plan_json")
  is_valid=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("isValid"))' <<<"$validation")
  [[ "$is_valid" == "False" ]]
}

@test "se-config local override permitted" {
  tmp_dir="$BATS_TEST_TMPDIR/se-local"
  mkdir -p "$tmp_dir"
  plan_json=$(fs_plan_ensure_file "$tmp_dir/se-config.local.ini" "binarypath=C:/Steam" "create")
  validation=$(fs_plan_validate --plan-json "$plan_json")
  is_valid=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("isValid"))' <<<"$validation")
  [[ "$is_valid" == "True" ]]
}
