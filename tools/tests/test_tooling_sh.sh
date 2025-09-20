#!/usr/bin/env bash
# dev-framework Bash shared tooling tests
# Exercises docs/spec/tooling/SharedLibrary.md validation requirements.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_PATH="${SCRIPT_DIR}/../lib/tooling.sh"

if [[ ! -f $LIB_PATH ]]; then
  echo "[error] tooling library missing at $LIB_PATH" >&2
  exit 1
fi

# shellcheck source=../lib/tooling.sh
source "$LIB_PATH"

failures=0
runs=0

assert_eq() {
  local expected=$1
  local actual=$2
  local message=${3:-}
  if [[ "$expected" != "$actual" ]]; then
    printf 'assert_eq failed: expected %s, got %s. %s
' "$expected" "$actual" "$message" >&2
    return 1
  fi
}

assert_contains() {
  local needle=$1
  local haystack=$2
  local message=${3:-}
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'assert_contains failed: missing "%s". %s
' "$needle" "$message" >&2
    return 1
  fi
}

reset_logging_state() {
  declare -Ag df_opts=()
  df_opts[dry_run]=false
  df_opts[verbose]=info
  df_opts[summary]=false
  df_opts[ci]=false
  init_logging df_opts
}

run_test() {
  local name=$1
  shift || true
  ((runs+=1))
  if "$@"; then
    printf 'PASS %s
' "$name"
  else
    printf 'FAIL %s
' "$name" >&2
    ((failures+=1))
  fi
}

# -----------------------------
# Unit tests
# -----------------------------

test_parse_shared_options() {
  unset -v opts rest || true
  parse_common_args opts rest -- --dry-run --verbose debug --summary --ci positional
  assert_eq true "${opts[dry_run]}" "dry-run flag"
  assert_eq debug "${opts[verbose]}" "verbose level"
  assert_eq true "${opts[summary]}" "summary flag"
  assert_eq true "${opts[ci]}" "ci flag"
  assert_eq positional "${rest[0]}" "positional argument"
}

run_test "parse shared options" test_parse_shared_options

test_parse_with_descriptors() {
  declare -A extra_defs=()
  extra_defs[--config]='value:config_path'
  extra_defs[-c]='alias:--config'
  extra_defs[--flag]='bool:flag_toggle'
  extra_defs[--list]='multi:list_items'

  unset -v opts rest values || true
  declare -A values

  parse_common_args opts rest extra_defs values -- --config foo --flag -c bar --list item1 --list=item2 positional1 positional2
  assert_eq bar "${values[config_path]}" "config value"
  assert_eq true "${values[flag_toggle]}" "flag captured"
  assert_contains "item1" "${values[list_items]}" "list captured first"
  assert_contains "item2" "${values[list_items]}" "list captured second"
  assert_eq positional1 "${rest[0]}"
  assert_eq positional2 "${rest[1]}"
}

run_test "parse extra descriptors" test_parse_with_descriptors

check_validate_mdk_config_success() {
  validate_mdk_config --config "${REPO_ROOT}/se-config.ini"
}

run_test "validate mdk config success" check_validate_mdk_config_success

check_validate_mdk_config_failure() {
  local tmp
  tmp=$(mktemp)
  printf 'type=programmableblock
' > "$tmp"
  if validate_mdk_config --config "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

run_test "validate mdk config failure" check_validate_mdk_config_failure

check_parse_errors() {
  declare -A extra_defs=()
  extra_defs[--needs]='value:needs_value'

  unset -v opts rest || true
  if parse_common_args opts rest extra_defs -- --needs; then
    return 1
  fi
  [[ -n ${opts[errors]} ]]
}

run_test "parse error reporting" check_parse_errors

check_logging_prefixes() {
  reset_logging_state
  local output
  output=$( {
    log_msg info "hello world"
  } 2>&1 )
  assert_contains "[info] hello world" "$output" "info prefix"
}

run_test "log prefixes" check_logging_prefixes

check_error_logging_to_stderr() {
  reset_logging_state
  local stderr
  stderr=$( {
    log_msg error "boom"
  } 2>&1 >/dev/null ) || true
  assert_contains "[error] boom" "$stderr" "error to stderr"
}

run_test "log error routing" check_error_logging_to_stderr

check_summary_output() {
  reset_logging_state
  df_opts[summary]=true
  init_logging df_opts
  register_action "first action"
  local out
  out=$( {
    emit_summary 0
  } 2>&1 )
  assert_contains "Summary (exit code: 0)" "$out"
  assert_contains "action: first action" "$out"
}

run_test "summary emission" check_summary_output

check_ci_annotation() {
  reset_logging_state
  df_opts[ci]=true
  init_logging df_opts
  local out
  out=$(ci_annotation error "line break" line=10 col=2)
  assert_eq '::error line=10,col=2::line break' "$out"
}

run_test "ci annotation" check_ci_annotation

check_log_warn_annotation() {
  reset_logging_state
  df_opts[ci]=true
  init_logging df_opts
  local output
  output=$( {
    log_msg warn "careful"
  } 2>&1 )
  assert_contains '::warning' "$output"
  assert_contains 'careful' "$output"
}

run_test "warn emits annotation" check_log_warn_annotation

# -----------------------------
# Integration test
# -----------------------------

run_integration() {
  local fixture="$SCRIPT_DIR/fixtures/bash_sample_tool.sh"
  local output
  output=$("$fixture" --dry-run --verbose debug --summary --name demo positional 2>&1)
  assert_contains "[info] starting sample" "$output"
  assert_contains "Summary (exit code: 0)" "$output"
  assert_contains "action: parsed positional" "$output"
  assert_contains "name=demo" "$output"
}

run_test "integration sample tool" run_integration

if ((failures)); then
  printf '
Bash tooling tests: %d/%d failed
' "$failures" "$runs" >&2
  exit 1
fi

printf '
Bash tooling tests: %d passed
' "$runs"
