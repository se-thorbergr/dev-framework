#!/usr/bin/env bats

ROOT_DIR="${BATS_TEST_DIRNAME}/../../.."
LINT_SH="$ROOT_DIR/tools/lint.sh"

setup() {
  if [[ ! -x "$LINT_SH" ]]; then
    skip "tools/lint.sh not present yet"
  fi
  if ! command -v pwsh >/dev/null 2>&1; then
    skip "pwsh not available"
  fi
}

@test "lint.sh shows help" {
  run bash "$LINT_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ Lint ]] || fail "expected help output to mention Lint"
}

@test "lint.sh dry-run exits with code 3 when targets exist" {
  tmp_script="$BATS_TEST_TMPDIR/sample.sh"
  cat <<'EOF' >"$tmp_script"
#!/usr/bin/env bash
echo "hi"
EOF

  run bash "$LINT_SH" --dry-run --files "$tmp_script"
  [ "$status" -eq 3 ]
}

@test "lint.sh handles markdown files in dry-run" {
  tmp_doc="$BATS_TEST_TMPDIR/sample.md"
  cat <<'EOF' >"$tmp_doc"
# heading

text
EOF

  run bash "$LINT_SH" --dry-run --files "$tmp_doc"
  [ "$status" -eq 3 ]
}

@test "lint.sh handles missing files as failure" {
  run bash "$LINT_SH" --files "$BATS_TEST_TMPDIR/missing.sh"
  [ "$status" -eq 1 ]
}

@test "lint-staged.sh exits zero with no staged files" {
  if git -C "$ROOT_DIR" diff --name-only --cached | grep -q .; then
    skip "staged files detected"
  fi
  run bash "$ROOT_DIR/tools/lint-staged.sh" --dry-run
  [ "$status" -eq 0 ]
}

@test "lint.sh warns but succeeds when only unsupported files provided" {
  unsupported="$ROOT_DIR/tools/puppeteer/headless.json"
  [ -f "$unsupported" ]

  run bash "$LINT_SH" --dry-run --files "$unsupported"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Unsupported file type" ]]
}
