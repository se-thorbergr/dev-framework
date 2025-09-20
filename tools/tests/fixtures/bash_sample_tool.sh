#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="${SCRIPT_DIR}/../../lib/tooling.sh"

# shellcheck source=../../lib/tooling.sh
source "$LIB_PATH"

declare -A EXTRA_OPTS=()
EXTRA_OPTS[--name]='value:user_name'
EXTRA_OPTS[-n]='alias:--name'

main() {
  declare -A opts
  declare -a rest
  declare -A extra

  if ! parse_common_args opts rest EXTRA_OPTS extra -- "$@"; then
    log_msg error "Failed to parse arguments"
    emit_summary 2 "parse-error"
    return 2
  fi

  init_logging opts
  log_msg info "starting sample"

  if [[ ${opts[dry_run]} == true ]]; then
    log_msg info "dry-run enabled"
  fi

  if [[ -n ${extra[user_name]-} ]]; then
    log_msg info "name=${extra[user_name]}"
  fi

  if ((${#rest[@]})); then
    register_action "parsed ${rest[0]}"
  fi

  emit_summary 0
}

main "$@"
