#!/usr/bin/env bash
# dev-framework shared tooling library (MIT License)
# Provides common CLI parsing, logging, summary, and CI helpers for Bash tooling.
# Behaviour adheres to docs/spec/tooling/SharedLibrary.md and ToolingGeneral.md.

if [[ -n ${DEV_FRAMEWORK_TOOLING_SH_LOADED:-} ]]; then
  return 0
fi
readonly DEV_FRAMEWORK_TOOLING_SH_LOADED=1

if [[ -z ${BASH_VERSINFO:-} || ${BASH_VERSINFO[0]} -lt 4 ]]; then
  echo "[error] tooling.sh requires Bash 4 or newer" >&2
  return 1
fi

# Resolve repository paths for sibling tooling scripts.
readonly DF_TOOLING_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DF_TOOLING_ROOT="$(cd "${DF_TOOLING_LIB_DIR}/.." && pwd)"
readonly DF_VERIFY_MDK_SCRIPT="${DF_TOOLING_ROOT}/verify-mdk2-config.sh"

# Global state configured via init_logging.
DF_LOG_LEVEL="info"
DF_LOG_LEVEL_INDEX=1
DF_CI_MODE=false
DF_SUMMARY_ENABLED=false
DF_DRY_RUN=false

declare -ag DF_SUMMARY_ACTIONS=()

# -----------------------------
# Internal helpers
# -----------------------------

__df_level_index() {
  case "$1" in
    quiet) echo 0 ;;
    info) echo 1 ;;
    debug) echo 2 ;;
    warn) echo 1 ;;
    error) echo 0 ;;
    *) return 1 ;;
  esac
}

__df_set_log_level_index() {
  local maybe
  maybe="$(__df_level_index "$1")" || maybe=1
  DF_LOG_LEVEL_INDEX=$maybe
}

__df_valid_verbosity() {
  case "$1" in
    quiet|info|debug) return 0 ;;
    *) return 1 ;;
  esac
}

__df_escape_annotation() {
  local msg="$1"
  msg="${msg//%/%25}"
  msg="${msg//$'
'/%0D}"
  msg="${msg//$'
'/%0A}"
  printf '%s' "$msg"
}

__df_normalise_name() {
  local name="$1"
  name="${name##*-}"
  name="${name//[^A-Za-z0-9_]/_}"
  printf '%s' "$name"
}

# -----------------------------
# Public API
# -----------------------------

# parse_common_args <result_assoc> <remaining_array> [<extra_defs_assoc> [<extra_values_assoc>]] -- <argv>
# result keys: dry_run, verbose, summary, help, ci, errors, unknown
parse_common_args() {
  if (($# < 3)); then
    echo "[error] parse_common_args requires at least result, remaining, and -- sentinel" >&2
    return 2
  fi

  local result_var=$1; shift
  local remaining_var=$1; shift

  local extra_defs_var=""
  local extra_values_var=""

  if [[ $1 != -- ]]; then
    extra_defs_var=$1
    shift
    if (($# == 0)); then
      echo "[error] parse_common_args expects -- before argument list" >&2
      return 2
    fi
  fi

  if [[ $1 != -- && -n $extra_defs_var ]]; then
    extra_values_var=$1
    shift
    if (($# == 0)); then
      echo "[error] parse_common_args expects -- before argument list" >&2
      return 2
    fi
  fi

  if [[ $1 != -- ]]; then
    echo "[error] parse_common_args expects -- before argument list" >&2
    return 2
  fi
  shift

  declare -gA "$result_var"
  declare -ga "$remaining_var"

  local -n __df_result=$result_var
  local -n __df_remaining=$remaining_var

  __df_result=(
    [dry_run]=false
    [verbose]=info
    [summary]=false
    [help]=false
    [ci]=false
    [errors]=''
    [unknown]=''
  )

  local __df_has_extra_defs=0
  local -n __df_extra_defs
  if [[ -n $extra_defs_var ]]; then
    __df_has_extra_defs=1
    declare -n __df_extra_defs=$extra_defs_var
  fi

  local -n __df_extra_values
  if [[ -n $extra_values_var ]]; then
    declare -gA "$extra_values_var"
    declare -n __df_extra_values=$extra_values_var
    __df_extra_values=()
  fi

  __df_remaining=()
  local errors=()

  while (($#)); do
    local arg="$1"
    shift

    case "$arg" in
      --)
        while (($#)); do
          __df_remaining+=("$1")
          shift
        done
        break
        ;;
      --dry-run)
        __df_result[dry_run]=true
        continue
        ;;
      --summary)
        __df_result[summary]=true
        continue
        ;;
      --help|-h|-\?)
        __df_result[help]=true
        continue
        ;;
      --ci)
        __df_result[ci]=true
        continue
        ;;
      --verbose)
        if (($# == 0)); then
          errors+=("Missing value for --verbose")
          continue
        fi
        local value="$1"
        shift
        if __df_valid_verbosity "$value"; then
          __df_result[verbose]="$value"
        else
          errors+=("Invalid verbosity level: $value")
        fi
        continue
        ;;
      --verbose=*)
        local value="${arg#*=}"
        if __df_valid_verbosity "$value"; then
          __df_result[verbose]="$value"
        else
          errors+=("Invalid verbosity level: $value")
        fi
        continue
        ;;
    esac

    local handled=0
    if (( __df_has_extra_defs )); then
      local opt_key="$arg"
      local inline_value=""
      local has_inline=0
      if [[ $opt_key == *=* ]]; then
        inline_value="${opt_key#*=}"
        opt_key="${opt_key%%=*}"
        has_inline=1
      fi

      local canonical="$opt_key"
      local descriptor
      local loops=0
      while (( loops < 10 )); do
        ((loops++))
        if [[ -z $canonical ]]; then
          break
        fi
        if [[ -n ${__df_extra_defs[$canonical]+_} ]]; then
          descriptor=${__df_extra_defs[$canonical]}
          local dtype="${descriptor%%:*}"
          local meta="${descriptor#*:}"
          if [[ $dtype == $descriptor ]]; then
            meta=""
          fi
          if [[ $dtype == alias ]]; then
            canonical="$meta"
            continue
          fi

          local key_name="$meta"
          if [[ -z $key_name ]]; then
            key_name=$(__df_normalise_name "$canonical")
          fi

          case "$dtype" in
            bool)
              if (( has_inline )); then
                errors+=("Option $opt_key does not accept a value")
              fi
              if [[ -n $extra_values_var ]]; then
                __df_extra_values[$key_name]=true
              fi
              handled=1
              ;;
            value|string)
              local opt_value
              if (( has_inline )); then
                opt_value="$inline_value"
              else
                if (($# == 0)); then
                  errors+=("Missing value for $opt_key")
                  handled=1
                  break
                fi
                opt_value="$1"
                shift
              fi
              if [[ -n $extra_values_var ]]; then
                __df_extra_values[$key_name]="$opt_value"
              fi
              handled=1
              ;;
            multi)
              local opt_value
              if (( has_inline )); then
                opt_value="$inline_value"
              else
                if (($# == 0)); then
                  errors+=("Missing value for $opt_key")
                  handled=1
                  break
                fi
                opt_value="$1"
                shift
              fi
              if [[ -n $extra_values_var ]]; then
                local existing="${__df_extra_values[$key_name]-}"
                if [[ -n $existing ]]; then
                  __df_extra_values[$key_name]="${existing}"$'
'"${opt_value}"
                else
                  __df_extra_values[$key_name]="$opt_value"
                fi
              fi
              handled=1
              ;;
            *)
              errors+=("Unknown descriptor type '$dtype' for $opt_key")
              handled=1
              ;;
          esac
          break
        fi
        break
      done
    fi

    if (( handled )); then
      continue
    fi

    if [[ $arg == -* ]]; then
      __df_result[unknown]+="$arg"$'
'
      errors+=("Unknown option: $arg")
      continue
    fi

    __df_remaining+=("$arg")
  done

  if ((${#errors[@]})); then
    __df_result[errors]=$(printf '%s
' "${errors[@]}")
    return 1
  fi

  return 0
}

# init_logging <options_assoc>
init_logging() {
  local options_var=$1
  if [[ -z $options_var ]]; then
    echo "[error] init_logging requires options associative array name" >&2
    return 2
  fi

  local -n opts_ref=$options_var

  DF_LOG_LEVEL="${opts_ref[verbose]:-info}"
  __df_set_log_level_index "$DF_LOG_LEVEL"

  DF_CI_MODE=false
  if [[ ${opts_ref[ci]:-false} == true ]]; then
    DF_CI_MODE=true
  fi

  DF_SUMMARY_ENABLED=false
  if [[ ${opts_ref[summary]:-false} == true ]]; then
    DF_SUMMARY_ENABLED=true
  fi

  DF_DRY_RUN=false
  if [[ ${opts_ref[dry_run]:-false} == true ]]; then
    DF_DRY_RUN=true
  fi

  DF_SUMMARY_ACTIONS=()

  return 0
}

# log_msg <level> <message>
log_msg() {
  local level=${1:-info}
  shift || true
  local message="$*"

  local idx
  idx=$(__df_level_index "$level") || idx=1
  if (( idx > DF_LOG_LEVEL_INDEX )); then
    return 0
  fi

  local prefix="[$level]"
  if [[ $level == error ]]; then
    if [[ $DF_CI_MODE == true ]]; then
      ci_annotation "error" "$message"
    fi
    >&2 printf '%s %s
' "$prefix" "$message"
    return 0
  fi

  if [[ $level == warn ]]; then
    if [[ $DF_CI_MODE == true ]]; then
      ci_annotation "warning" "$message"
    fi
    >&2 printf '%s %s
' "$prefix" "$message"
    return 0
  fi

  printf '%s %s
' "$prefix" "$message"
}

# register_action <description>
register_action() {
  local description="$*"
  if [[ -z $description ]]; then
    return 0
  fi
  DF_SUMMARY_ACTIONS+=("$description")
}

# emit_summary <exit_code> [<error>...]
emit_summary() {
  local exit_code=${1:-0}
  shift || true

  if [[ $DF_SUMMARY_ENABLED != true ]]; then
    return 0
  fi

  log_msg info "Summary (exit code: ${exit_code})"

  if ((${#DF_SUMMARY_ACTIONS[@]})); then
    for action in "${DF_SUMMARY_ACTIONS[@]}"; do
      log_msg info "  action: ${action}"
    done
  else
    log_msg info "  action: none recorded"
  fi

  local errors=("$@")
  if ((${#errors[@]})); then
    for err in "${errors[@]}"; do
      log_msg error "summary-error: ${err}"
    done
  fi
}

# ci_annotation <type> <message> [<key=value>...]
ci_annotation() {
  local type=$1
  shift || true
  local message=${1:-}
  shift || true

  if [[ $DF_CI_MODE != true ]]; then
    return 0
  fi

  local escaped_message
  escaped_message=$(__df_escape_annotation "$message")

  local meta_parts=()
  while (($#)); do
    if [[ $1 == *=* ]]; then
      meta_parts+=("$1")
    fi
    shift
  done

  local meta=""
  if ((${#meta_parts[@]})); then
    meta=$(IFS=','; printf '%s' "${meta_parts[*]}")
    printf '::%s %s::%s
' "$type" "$meta" "$escaped_message"
  else
    printf '::%s::%s
' "$type" "$escaped_message"
  fi
}

# validate_mdk_config [args...]
validate_mdk_config() {
  if [[ ! -f $DF_VERIFY_MDK_SCRIPT ]]; then
    log_msg debug "MDK verifier missing at ${DF_VERIFY_MDK_SCRIPT}"
    return 127
  fi

  bash "$DF_VERIFY_MDK_SCRIPT" "$@"
}
