#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/test_tooling_sh.sh"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoLogo -NoProfile -File "$SCRIPT_DIR/Test-DevFrameworkTooling.ps1"
else
  echo "[warn] pwsh not found; skipping PowerShell tooling tests" >&2
fi
