#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_PS1="$SCRIPT_DIR/lint.ps1"

if [[ ! -f "$LINT_PS1" ]]; then
	echo "lint.ps1 helper not found (expected at $LINT_PS1)" >&2
	exit 1
fi

if ! command -v pwsh >/dev/null 2>&1; then
	echo "PowerShell 7+ (pwsh) is required to run tools/lint.sh" >&2
	exit 1
fi

exec pwsh -NoLogo -NoProfile -File "$LINT_PS1" "$@"
