#!/usr/bin/env bash
# dev-framework setup tooling (MIT License)
# Implements environment bootstrap per docs/spec/tooling/SetupTooling.md
# Relies on shared CLI contract from docs/spec/tooling/ToolingGeneral.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_PATH="${TOOLS_ROOT}/lib/tooling.sh"

if [[ ! -f "$LIB_PATH" ]]; then
  echo "[error] shared tooling library not found at $LIB_PATH" >&2
  exit 1
fi

# shellcheck source=lib/tooling.sh
source "$LIB_PATH"

print_usage() {
  cat <<'USAGE'
Usage: setup.sh [shared options] [setup options]

Shared options:
  --dry-run            Show actions without executing changes
  --verbose <level>    Set verbosity (quiet|info|debug)
  --summary            Print run summary at exit
  --ci                 Enable CI-friendly output
  --help               Show this help

Setup-specific options:
  --config <path>      Config file to manage (default se-config.local.ini if present)
  --auto-install       Attempt package installs without prompting
  --notes-only         Emit diagnostics only (implies dry-run, disables installs)
  --binary-path <path> Override Space Engineers Bin64 path
  --steam-path <path>  Helper Steam root to locate Space Engineers
  --game-path <path>   Helper Space Engineers game directory
  --sln <path>         Override solution path (default dev-framework.sln)
  --setup-codex        Force Codex bootstrap
  --skip-codex         Skip Codex bootstrap
  --name <value>       Project name context used for defaults
USAGE
}

declare -A EXTRA_ARGS=(
  [--config]='value:config_path'
  [-c]='alias:--config'
  [--auto-install]='bool:auto_install'
  [--notes-only]='bool:notes_only'
  [--binary-path]='value:binary_path'
  [--steam-path]='value:steam_path'
  [--game-path]='value:game_path'
  [--sln]='value:sln_path'
  [--setup-codex]='bool:setup_codex'
  [--skip-codex]='bool:skip_codex'
  [--name]='value:project_name'
  [-n]='alias:--name'
)

resolve_path() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo ""
    return 0
  fi
  if [[ "$input" = /* ]]; then
    echo "$input"
  else
    echo "${REPO_ROOT}/${input}"
  fi
}

read_ini_value() {
  local file="$1"
  local section="$2"
  local key="$3"
  python - "$file" "$section" "$key" <<'PY'
import configparser, sys
path, section, key = sys.argv[1:4]
config = configparser.ConfigParser()
config.optionxform = str
config.read(path, encoding='utf-8')
try:
    value = config.get(section, key)
except Exception:
    sys.exit(1)
value = value.strip()
if not value:
    sys.exit(1)
print(value)
PY
}

set_ini_value() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  python - "$file" "$section" "$key" "$value" <<'PY'
import configparser, sys
path, section, key, value = sys.argv[1:5]
config = configparser.ConfigParser()
config.optionxform = str
config.read(path, encoding='utf-8')
if not config.has_section(section):
    config.add_section(section)
config.set(section, key, value)
with open(path, 'w', encoding='utf-8') as fh:
    config.write(fh)
PY
}

ensure_directory() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    return 0
  fi
  if [[ $DF_DRY_RUN == true ]]; then
    log_msg info "Would create directory $dir"
    register_action "ensure dir (dry-run) $dir"
    return 0
  fi
  mkdir -p "$dir"
  register_action "created directory $dir"
}

write_default_config() {
  local target="$1"
  ensure_directory "$(dirname "$target")"
  if [[ $DF_DRY_RUN == true ]]; then
    log_msg info "Would create config template at $target"
    register_action "ensure config (dry-run) $target"
    return 0
  fi
  cat >"$target" <<'CFG'
[Paths]
steam_path =
game_path =

[mdk]
type=programmableblock
trace=off
minify=none
ignores=obj/**/*,MDK/**/*,**/*.debug.cs
binarypath=auto
CFG
  register_action "created config $target"
}

derive_binary_from_helpers() {
  local game_path="$1"
  local steam_path="$2"
  if [[ -n "$game_path" ]]; then
    local candidate="$game_path"
    if [[ -d "$candidate/Bin64" ]]; then
      echo "$candidate/Bin64"
      return 0
    fi
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  fi
  if [[ -n "$steam_path" ]]; then
    local candidate="${steam_path%/}/steamapps/common/SpaceEngineers/Bin64"
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  fi
  return 1
}

check_command_version() {
  local title="$1"
  shift
  local bin="$1"
  shift || true
  if command -v "$bin" >/dev/null 2>&1; then
    local version
    version=$("$bin" "$@" 2>/dev/null | head -n 1 || true)
    log_msg info "$title detected ${version:+($version)}"
    register_action "$title available"
    return 0
  fi
  log_msg warn "$title not found on PATH"
  register_action "$title missing"
  return 1
}

summarize_and_exit() {
  local code=$1
  emit_summary "$code"
  exit "$code"
}

main() {
  declare -A options
  declare -a remaining
  declare -A extras

  if ! parse_common_args options remaining EXTRA_ARGS extras -- "$@"; then
    log_msg error "Failed to parse arguments"
    if [[ -n ${options[errors]:-} ]]; then
      log_msg error "${options[errors]}"
    fi
    exit 2
  fi

  if [[ ${options[help]} == true ]]; then
    print_usage
    exit 0
  fi

  if [[ ${extras[notes_only]:-false} == true ]]; then
    options[dry_run]=true
  fi

  init_logging options

  local notes_only=${extras[notes_only]:-false}
  local auto_install=${extras[auto_install]:-false}
  local setup_codex=${extras[setup_codex]:-false}
  local skip_codex=${extras[skip_codex]:-false}

  if [[ $setup_codex == true && $skip_codex == true ]]; then
    log_msg error "Cannot set both --setup-codex and --skip-codex"
    summarize_and_exit 2
  fi

  local config_path
  if [[ -n ${extras[config_path]:-} ]]; then
    config_path=$(resolve_path "${extras[config_path]}")
  elif [[ -f "${REPO_ROOT}/se-config.local.ini" ]]; then
    config_path="${REPO_ROOT}/se-config.local.ini"
  else
    config_path="${REPO_ROOT}/se-config.ini"
  fi

  log_msg info "Using config file: ${config_path}"

  if [[ ! -f "$config_path" ]]; then
    write_default_config "$config_path"
  fi

  if ! validate_mdk_config --config "$config_path" >/dev/null 2>&1; then
    log_msg error "Configuration validation failed for ${config_path}"
    summarize_and_exit 1
  fi
  register_action "validated config"

  local binary_path_override=${extras[binary_path]:-}
  local binary_path=""
  if [[ -n "$binary_path_override" ]]; then
    binary_path="$binary_path_override"
    log_msg info "Binary path overridden via CLI: $binary_path"
  else
    local existing
    existing=$(read_ini_value "$config_path" mdk binarypath || true)
    if [[ -n "$existing" && "$existing" != "auto" ]]; then
      binary_path="$existing"
      log_msg debug "Binary path from config: $binary_path"
    else
      binary_path=$(derive_binary_from_helpers "${extras[game_path]:-}" "${extras[steam_path]:-}" || true)
      if [[ -n "$binary_path" ]]; then
        log_msg info "Derived binary path: $binary_path"
      fi
    fi
  fi

  if [[ -n "$binary_path" ]]; then
    if [[ -d "$binary_path" ]]; then
      log_msg info "Resolved Space Engineers binary path: $binary_path"
      if [[ $DF_DRY_RUN == true ]]; then
        log_msg info "Dry-run: would record binary path in ${config_path}"
        register_action "binary path (dry-run)"
      else
        local global_config="${REPO_ROOT}/se-config.ini"
        if [[ "$(realpath "$config_path")" == "$(realpath "$global_config")" ]]; then
          log_msg info "Config is global template; skipping binary path write"
        else
          set_ini_value "$config_path" mdk binarypath "$binary_path"
          register_action "updated binary path"
        fi
      fi
    else
      log_msg warn "Binary path does not exist: $binary_path"
    fi
  else
    log_msg warn "Unable to determine Space Engineers binary path"
  fi

  if [[ -n ${extras[steam_path]:-} ]]; then
    if [[ $DF_DRY_RUN == true ]]; then
      log_msg info "Dry-run: would set steam_path to ${extras[steam_path]}"
    else
      set_ini_value "$config_path" Paths steam_path "${extras[steam_path]}"
    fi
    register_action "recorded steam path"
  fi

  if [[ -n ${extras[game_path]:-} ]]; then
    if [[ $DF_DRY_RUN == true ]]; then
      log_msg info "Dry-run: would set game_path to ${extras[game_path]}"
    else
      set_ini_value "$config_path" Paths game_path "${extras[game_path]}"
    fi
    register_action "recorded game path"
  fi

  local sln_path
  if [[ -n ${extras[sln_path]:-} ]]; then
    sln_path=$(resolve_path "${extras[sln_path]}")
  else
    sln_path="${REPO_ROOT}/dev-framework.sln"
  fi

  if [[ -f "$sln_path" ]]; then
    log_msg info "Solution file present at $sln_path"
  else
    if [[ $DF_DRY_RUN == true ]]; then
      log_msg info "Dry-run: would create solution at $sln_path"
    else
      log_msg warn "Solution file missing at $sln_path (manual creation required)"
    fi
    register_action "solution check"
  fi

  check_command_version "dotnet" dotnet --version || true
  check_command_version "PowerShell 7" pwsh --version || true
  check_command_version "Node.js" node --version || true
  check_command_version "npm" npm --version || true

  if [[ $auto_install == true ]]; then
    log_msg warn "Auto-install requested but not implemented; please install dependencies manually"
  fi

  if [[ $skip_codex == true ]]; then
    log_msg info "Codex setup skipped per flag"
    register_action "codex skipped"
  elif [[ $setup_codex == true ]]; then
    if command -v npm >/dev/null 2>&1; then
      if [[ $DF_DRY_RUN == true || $notes_only == true ]]; then
        log_msg info "Dry-run: would run npm install for Codex CLI"
      else
        log_msg info "Codex bootstrap not automated yet; run 'npm install' manually"
      fi
    else
      log_msg warn "npm not available; cannot bootstrap Codex"
    fi
    register_action "codex setup"
  else
    log_msg info "Codex setup skipped (default behavior)"
    register_action "codex default skip"
  fi

  summarize_and_exit 0
}

main "$@"
