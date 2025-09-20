#!/usr/bin/env bash
# dev-framework setup tests (MIT License)
# Validates setup tooling per docs/spec/tooling/SetupTooling.md
# Tests for tools/setup.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SETUP_SCRIPT="${REPO_ROOT}/tools/setup.sh"

if [[ ! -x $SETUP_SCRIPT ]]; then
  echo "[error] setup script missing at $SETUP_SCRIPT" >&2
  exit 1
fi

failures=0
runs=0

assert_contains() {
  local needle=$1
  local haystack=$2
  local message=${3:-}
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'assert_contains failed: missing "%s" %s\n' "$needle" "$message" >&2
    return 1
  fi
}

create_valid_config() {
  local path=$1
  cat >"$path" <<'CFG'
[mdk]
type=programmableblock
trace=off
minify=none
ignores=obj/**/*,MDK/**/*,**/*.debug.cs
binarypath=auto
CFG
}

create_invalid_config() {
  local path=$1
  cat >"$path" <<'CFG'
[mdk]
type=programmableblock
CFG
}

run_test() {
  local name=$1
  shift || true
  ((runs++))
  set +e
  "$@"
  local status=$?
  set -e
  if ((status == 0)); then
    printf 'PASS %s\n' "$name"
  else
    printf 'FAIL %s\n' "$name" >&2
    ((failures++))
  fi
}

test_notes_only_success() {
  local cfg game tmpdir output
  cfg=$(mktemp)
  game=$(mktemp -d)
  mkdir -p "$game/Bin64"
  create_valid_config "$cfg"
  output=$("$SETUP_SCRIPT" --notes-only --config "$cfg" --game-path "$game" 2>&1)
  assert_contains "Using config file" "$output" "config message"
  assert_contains "Resolved Space Engineers binary path" "$output" "binary path resolution"
  rm -rf "$cfg" "$game"
}

run_test "setup notes-only success" test_notes_only_success

test_invalid_config_failure() {
  local cfg output status
  cfg=$(mktemp)
  create_invalid_config "$cfg"
  set +e
  output=$("$SETUP_SCRIPT" --notes-only --config "$cfg" 2>&1)
  status=$?
  set -e
  rm -f "$cfg"
  if [[ $status -eq 0 ]]; then
    printf '%s\n' "$output" >&2
    return 1
  fi
  assert_contains "Configuration validation failed" "$output" "expected validation failure"
}

run_test "setup invalid config fails" test_invalid_config_failure

test_conflicting_codex_flags() {
  local cfg status
  cfg=$(mktemp)
  create_valid_config "$cfg"
  set +e
  "$SETUP_SCRIPT" --notes-only --config "$cfg" --setup-codex --skip-codex >/dev/null 2>&1
  status=$?
  set -e
  rm -f "$cfg"
  [[ $status -ne 0 ]]
}

run_test "setup conflicting codex flags" test_conflicting_codex_flags

if ((failures)); then
  printf '\nsetup.sh tests: %d/%d failed\n' "$failures" "$runs" >&2
  exit 1
fi

printf '\nsetup.sh tests: %d passed\n' "$runs"
