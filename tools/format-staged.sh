#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMAT_STAGED_PS1="$SCRIPT_DIR/format-staged.ps1"

if [[ ! -f "$FORMAT_STAGED_PS1" ]]; then
	echo "format-staged.ps1 helper not found (expected at $FORMAT_STAGED_PS1)" >&2
	exit 1
fi

if ! command -v pwsh >/dev/null 2>&1; then
	echo "PowerShell 7+ (pwsh) is required to run tools/format-staged.sh" >&2
	exit 1
fi

exec pwsh -NoLogo -NoProfile -File "$FORMAT_STAGED_PS1" "$@"
