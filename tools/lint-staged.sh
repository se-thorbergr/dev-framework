#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_STAGED_PS1="$SCRIPT_DIR/lint-staged.ps1"

if [[ ! -f "$LINT_STAGED_PS1" ]]; then
	echo "lint-staged.ps1 helper not found (expected at $LINT_STAGED_PS1)" >&2
	exit 1
fi

if ! command -v pwsh >/dev/null 2>&1; then
	echo "PowerShell 7+ (pwsh) is required to run tools/lint-staged.sh" >&2
	exit 1
fi

exec pwsh -NoLogo -NoProfile -File "$LINT_STAGED_PS1" "$@"
