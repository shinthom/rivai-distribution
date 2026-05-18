#!/usr/bin/env bash
# common.sh — shared helpers for Rivai release scripts.
#
# All scripts in this directory should:
#   1) source lib/common.sh first (sets safe shell options)
#   2) call parse_common_flags "$@" to extract --dry-run
#   3) use log/warn/die/run for all side effects so --dry-run works

set -euo pipefail

DRY_RUN=${DRY_RUN:-0}
DIST_ROOT=${DIST_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.."}
# DIST_ROOT defaults to Distribution/ (the parent of scripts/)

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
log()  { printf '%s %s\n' "$(color '36' '[info ]')" "$*" >&2; }
warn() { printf '%s %s\n' "$(color '33' '[warn ]')" "$*" >&2; }
die()  { printf '%s %s\n' "$(color '31' '[error]')" "$*" >&2; exit 1; }

require_command() {
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
  done
}

# parse_common_flags removes recognized flags from $@ and exports DRY_RUN.
# Usage:  eval "set -- $(parse_common_flags "$@")"
parse_common_flags() {
  local rest=()
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=1 ;;
      *) rest+=("$arg") ;;
    esac
  done
  # Print remaining args, quoted, so caller can `eval "set -- $(...)"`.
  printf ' %q' "${rest[@]:-}"
}

is_dry_run() { [[ "$DRY_RUN" == "1" ]]; }

# run "<description>" cmd args...  — logs and either runs or skips based on DRY_RUN
run() {
  local desc="$1"; shift
  if is_dry_run; then
    printf '%s %s\n  > %s\n' "$(color '35' '[dry  ]')" "$desc" "$*" >&2
  else
    log "$desc"
    "$@"
  fi
}

compute_sha256() {
  local file="$1"
  shasum -a 256 "$file" | awk '{print $1}'
}

file_size_bytes() {
  local file="$1"
  if stat -f%z "$file" >/dev/null 2>&1; then
    stat -f%z "$file"   # macOS
  else
    stat -c%s "$file"   # Linux
  fi
}

human_size() {
  local b="$1"
  awk -v b="$b" 'BEGIN{
    if (b >= 1e9)      printf "%.2f GB", b/1e9
    else if (b >= 1e6) printf "%.1f MB", b/1e6
    else if (b >= 1e3) printf "%.0f KB", b/1e3
    else               printf "%d B", b
  }'
}

iso_now() { date "+%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'; }
