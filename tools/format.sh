#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMAT_PS1="$SCRIPT_DIR/format.ps1"

if [[ ! -f "$FORMAT_PS1" ]]; then
	echo "format.ps1 helper not found (expected at $FORMAT_PS1)" >&2
	exit 1
fi

if ! command -v pwsh >/dev/null 2>&1; then
	echo "PowerShell 7+ (pwsh) is required to run tools/format.sh" >&2
	exit 1
fi

exec pwsh -NoLogo -NoProfile -File "$FORMAT_PS1" "$@"
