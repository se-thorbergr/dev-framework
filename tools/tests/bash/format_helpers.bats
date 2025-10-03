#!/usr/bin/env bats

ROOT_DIR="${BATS_TEST_DIRNAME}/../../.."
FORMAT_SH="$ROOT_DIR/tools/format.sh"

setup() {
  if [[ ! -x "$FORMAT_SH" ]]; then
    skip "tools/format.sh not present yet"
  fi
  if ! command -v pwsh >/dev/null 2>&1; then
    skip "pwsh not available"
  fi
}

@test "format.sh shows help" {
  run bash "$FORMAT_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ Format ]] || fail "expected help output to mention Format"
}

@test "format.sh dry-run exits with code 3 when work pending" {
  tmp_script="$BATS_TEST_TMPDIR/sample.sh"
  cat <<'EOF' >"$tmp_script"
#!/usr/bin/env bash
echo "hi"
EOF

  run bash "$FORMAT_SH" --dry-run --files "$tmp_script"
  [ "$status" -eq 3 ]
}

@test "format.sh handles markdown files in dry-run" {
  tmp_doc="$BATS_TEST_TMPDIR/sample.md"
  cat <<'EOF' >"$tmp_doc"
# heading

text
EOF

  run bash "$FORMAT_SH" --dry-run --files "$tmp_doc"
  [ "$status" -eq 3 ]
}

@test "format.sh skips when no files" {
  if git -C "$ROOT_DIR" diff --name-only --cached | grep -q .; then
    skip "staged files detected"
  fi
  run bash "$FORMAT_SH" --dry-run
  [ "$status" -eq 0 ]
}

@test "format-staged.sh exits zero with no staged files" {
  if git -C "$ROOT_DIR" diff --name-only --cached | grep -q .; then
    skip "staged files detected"
  fi
  run bash "$ROOT_DIR/tools/format-staged.sh" --dry-run
  [ "$status" -eq 0 ]
}
