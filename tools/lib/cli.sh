#!/usr/bin/env bash

# Shared CLI runtime library (Bash implementation)
# Provides argument parsing, logging helpers, summary aggregation, and CI-friendly utilities.

# Global state
declare -gA CLI_FLAGS=()
declare -ga CLI_UNKNOWN_ARGS=()
declare -ga CLI_SUMMARY_ITEMS=()
CLI_SEP=$'\x1f'

_cli_escape_json_string() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  input="${input//$'\r'/\\r}"
  input="${input//$'\t'/\\t}"
  printf '%s' "$input"
}

_cli_reset_state() {
  CLI_FLAGS=(
    [help]=0
    [version]=0
    [dry_run]=0
    [summary]=0
    [summary_format]='text'
    [summary_json]=''
    [log_level]='info'
    [ci]=0
  )
  CLI_UNKNOWN_ARGS=()
  CLI_SUMMARY_ITEMS=()
}

_cli_log_rank() {
  case "$1" in
    quiet) echo 0 ;;
    info) echo 1 ;;
    debug) echo 2 ;;
    *) echo 1 ;;
  esac
}

cli_init() {
  _cli_reset_state

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        CLI_FLAGS[help]=1
        ;;
      --version)
        CLI_FLAGS[version]=1
        ;;
      --dry-run)
        CLI_FLAGS[dry_run]=1
        ;;
      --summary)
        CLI_FLAGS[summary]=1
        ;;
      --summary-format)
        if [[ -n "$2" && "$2" =~ ^(text|json)$ ]]; then
          CLI_FLAGS[summary_format]="$2"
          shift
        else
          CLI_UNKNOWN_ARGS+=("$1")
          [[ -n "$2" ]] && CLI_UNKNOWN_ARGS+=("$2") && shift
        fi
        ;;
      --summary-json)
        if [[ -n "$2" ]]; then
          CLI_FLAGS[summary_json]="$2"
          shift
        else
          CLI_UNKNOWN_ARGS+=("$1")
        fi
        ;;
      --verbose)
        if [[ -n "$2" && "$2" =~ ^(quiet|info|debug)$ ]]; then
          CLI_FLAGS[log_level]="$2"
          shift
        else
          CLI_UNKNOWN_ARGS+=("$1")
          [[ -n "$2" ]] && CLI_UNKNOWN_ARGS+=("$2") && shift
        fi
        ;;
      --debug)
        CLI_FLAGS[log_level]='debug'
        ;;
      --ci)
        CLI_FLAGS[ci]=1
        ;;
      *)
        CLI_UNKNOWN_ARGS+=("$1")
        ;;
    esac
    shift || true
  done
}

log() {
  local level="$1"
  shift
  local message="$*"
  local current="${CLI_FLAGS[log_level]}"
  local level_rank=$(_cli_log_rank "$level")
  local current_rank=$(_cli_log_rank "$current")
  if (( level_rank <= current_rank )); then
    printf '[%s] %s\n' "$level" "$message"
  fi
}

summary_add() {
  local kind="$1"
  local message="$2"
  local data="$3"
  CLI_SUMMARY_ITEMS+=("${kind}${CLI_SEP}${message}${CLI_SEP}${data}")
}

summary_emit() {
  local format="${1:-${CLI_FLAGS[summary_format]}}"
  local output_path="${2:-${CLI_FLAGS[summary_json]}}"

  if [[ "$format" == "json" || -n "$output_path" ]]; then
    local items_json="[]"
    if (( ${#CLI_SUMMARY_ITEMS[@]} > 0 )); then
      local buffer=""
      for entry in "${CLI_SUMMARY_ITEMS[@]}"; do
        IFS="$CLI_SEP" read -r kind message data <<<"$entry"
        local escaped_kind="$(_cli_escape_json_string "$kind")"
        local escaped_message="$(_cli_escape_json_string "$message")"
        local item_data='null'
        if [[ -n "$data" ]]; then
          local escaped_data="$(_cli_escape_json_string "$data")"
          item_data="\"${escaped_data}\""
        fi
        buffer+="{\"kind\":\"${escaped_kind}\",\"message\":\"${escaped_message}\",\"data\":${item_data}},"
      done
      buffer="${buffer%,}"
      items_json="[${buffer}]"
    fi

    local ci_enabled=$([[ "${CLI_FLAGS[ci]}" == "1" ]] && echo true || echo false)
    local ci_provider="null"
    if [[ "$GITHUB_ACTIONS" == 'true' ]]; then
      ci_provider='"github_actions"'
    elif [[ -n "$CI" ]]; then
      ci_provider='"generic"'
    fi

    local json="{\"schema\":\"v1\",\"summary\":${items_json},\"ci\":{\"enabled\":${ci_enabled},\"provider\":${ci_provider}}}"
    if [[ -n "$output_path" ]]; then
      printf '%s' "$json" > "$output_path"
    fi
    printf '%s\n' "$json"
    return 0
  fi

  printf 'Summary:\n'
  for entry in "${CLI_SUMMARY_ITEMS[@]}"; do
    IFS="$CLI_SEP" read -r kind message _ <<<"$entry"
    printf -- '- [%s] %s\n' "$kind" "$message"
  done
}

help_emit() {
  printf 'Usage: <tool> [options] --help --version --dry-run --summary\n'
}

version_emit() {
  local version="$1"
  local commit="${2:-n/a}"
  local api_version="$3"
  printf 'version=%s commit=%s api_version=%s\n' "$version" "$commit" "$api_version"
}

ci_annotate() {
  local level="$1"
  local message="$2"
  local file="$3"
  local line="$4"
  local col="$5"

  if [[ "${CLI_FLAGS[ci]}" == "1" && "$GITHUB_ACTIONS" == 'true' ]]; then
    local annotation="::${level}"
    if [[ -n "$file" ]]; then
      annotation+=" file=${file}"
      [[ -n "$line" ]] && annotation+=" line=${line}"
      [[ -n "$col" ]] && annotation+=" col=${col}"
    fi
    annotation+="::${message}"
    printf '%s\n' "$annotation"
  else
    log info "$message"
  fi
}

error_make() {
  local code="$1"
  local message="$2"
  local area="$3"
  local escaped_message="$(_cli_escape_json_string "$message")"
  local area_json='null'
  if [[ -n \"$area\" ]]; then
    area_json=\"\\\"$(_cli_escape_json_string \"$area\")\\\"\"
  fi
  printf '{\"code\":%s,\"message\":\"%s\",\"area\":%s}\n' \"$code\" \"$escaped_message\" \"$area_json\"
}
