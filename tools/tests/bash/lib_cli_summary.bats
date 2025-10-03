#!/usr/bin/env bats

load_helper() {
  LIB_PATH="${BATS_TEST_DIRNAME}/../../lib/cli.sh"
  if [[ ! -f "$LIB_PATH" ]]; then
    echo "LibCli library not found at $LIB_PATH" >&2
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
}

@test "cli_init parses summary flags and emits schema v1 JSON" {
  cli_init --summary --summary-format json --ci

  [[ "${CLI_FLAGS[summary]}" == "1" ]]
  [[ "${CLI_FLAGS[summary_format]}" == "json" ]]
  [[ "${CLI_FLAGS[ci]}" == "1" ]]

  summary_add info "first item"
  summary_add warning "second item"

  run summary_emit json
  [ "$status" -eq 0 ]
  json_output="$output"

  find_python || skip "Python interpreter required"

  schema=$("${PYTHON_CMD[@]}" -c 'import json, sys; data = json.loads(sys.stdin.read()); print(data.get("schema"))' <<<"$json_output")
  [[ "$schema" == "v1" ]]

  ci_value=$("${PYTHON_CMD[@]}" -c 'import json, sys; data = json.loads(sys.stdin.read()); print(str(data.get("ci", {}).get("enabled", False)).lower())' <<<"$json_output")
  [[ "$ci_value" == "true" ]]
}

@test "version_emit includes api_version" {
  load_helper
  run version_emit "1.2.3" "abc123" "2025.10"
  [ "$status" -eq 0 ]
  [[ "$output" == *"api_version"* ]]
  [[ "$output" == *"2025.10"* ]]
}
