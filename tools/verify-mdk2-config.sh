#!/usr/bin/env bash
# dev-framework MDK config verifier (MIT License)
# Implements config validation per docs/spec/tooling/SharedLibrary.md


set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_CONFIG="${REPO_ROOT}/se-config.ini"

print_help() {
  cat <<'EOF'
Usage: verify-mdk2-config.sh [--config <path>] [config ...]

Validate that the specified MDK2 configuration files contain the required
[mdk] section and keys (type, trace, minify, ignores).
If no configuration is provided, the repository se-config.ini is used.
EOF
}

parse_args() {
  configs=()
  while (($#)); do
    case "$1" in
      -h|--help)
        print_help
        exit 0
        ;;
      -c|--config)
        if (($# == 1)); then
          echo "[error] --config requires a path" >&2
          exit 2
        fi
        configs+=("$2")
        shift 2
        ;;
      --)
        shift
        while (($#)); do
          configs+=("$1")
          shift
        done
        ;;
      -* )
        echo "[error] unknown option: $1" >&2
        exit 2
        ;;
      *)
        configs+=("$1")
        shift
        ;;
    esac
  done

  if ((${#configs[@]} == 0)); then
    configs+=("$DEFAULT_CONFIG")
  fi
}

check_config() {
  local path="$1"
  local resolved
  if [[ -f "$path" ]]; then
    resolved="$path"
  elif [[ -f "${SCRIPT_DIR}/$path" ]]; then
    resolved="${SCRIPT_DIR}/$path"
  else
    echo "[error] config not found: $path" >&2
    return 2
  fi

  local status=0

  if ! grep -Eq '^\s*\[mdk\]' "$resolved"; then
    echo "[error] missing [mdk] section in $resolved" >&2
    status=3
  fi

  for key in type trace minify ignores; do
    if ! grep -Eq "^\s*${key}\s*=" "$resolved"; then
      echo "[error] missing ${key}= in $resolved" >&2
      status=3
    fi
  done

  if [[ $status -ne 0 ]]; then
    return $status
  fi

  echo "[info] verified $resolved"
  return 0
}

main() {
  parse_args "$@"

  local overall=0
  for cfg in "${configs[@]}"; do
    if ! check_config "$cfg"; then
      overall=1
    fi
  done

  return $overall
}

main "$@"
