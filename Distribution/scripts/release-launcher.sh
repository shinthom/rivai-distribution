#!/usr/bin/env bash
# release-launcher.sh — publish launcher build(s) to R2 and refresh the launcher manifest.
#
# Idempotent: running twice with the same inputs produces the same artifacts.
# The launcher manifest is fetched from R2 (if it exists) and merged so that
# publishing one platform doesn't wipe the other's entry.
#
# Usage:
#   ./release-launcher.sh \
#     --version 0.0.2 \
#     --build-id 2026.05.18.001 \
#     --channel dev \
#     [--mac path/to/Rivai\ Launcher.app] \
#     [--win path/to/Rivai\ Launcher.exe.zip] \
#     [--dry-run]
#
# Either --mac or --win must be provided. Both can be given in a single run.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/r2.sh"

VERSION=""
BUILD_ID=""
CHANNEL="dev"
MAC_INPUT=""
WIN_INPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2 ;;
    --build-id) BUILD_ID="$2"; shift 2 ;;
    --channel)  CHANNEL="$2"; shift 2 ;;
    --mac)      MAC_INPUT="$2"; shift 2 ;;
    --win)      WIN_INPUT="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    *) die "unknown flag: $1" ;;
  esac
done

[[ -n "$VERSION"  ]] || die "--version required"
[[ -n "$BUILD_ID" ]] || die "--build-id required"
[[ -n "$MAC_INPUT" || -n "$WIN_INPUT" ]] || die "at least one of --mac/--win required"

require_command wrangler shasum python3

RELEASED_AT=$(iso_now)

# Workspace for prepared zips.
STAGE_DIR="$DIST_ROOT/Distribution/staging/launcher/$VERSION"
mkdir -p "$STAGE_DIR"

prepare_mac_zip() {
  local input="$1" out="$STAGE_DIR/rivai-launcher_${VERSION}_mac_arm64.zip"
  if [[ -d "$input" && "$input" == *.app ]]; then
    log "ditto compress: $input → $(basename "$out")"
    if is_dry_run; then
      printf '[dry  ] ditto -c -k --sequesterRsrc --keepParent %q %q\n' "$input" "$out" >&2
    else
      rm -f "$out"
      ditto -c -k --sequesterRsrc --keepParent "$input" "$out"
    fi
  elif [[ -f "$input" && "$input" == *.zip ]]; then
    log "using existing zip: $input"
    cp "$input" "$out"
  else
    die "--mac expects a .app directory or a .zip file: $input"
  fi
  echo "$out"
}

prepare_win_zip() {
  local input="$1" out="$STAGE_DIR/rivai-launcher_${VERSION}_win64_x64.zip"
  if [[ -f "$input" && "$input" == *.zip ]]; then
    log "using existing zip: $input"
    cp "$input" "$out"
  else
    die "--win expects a .zip file: $input"
  fi
  echo "$out"
}

upload_and_describe() {
  local platform="$1" zip="$2"
  local key="builds/${CHANNEL}/launcher/${platform}/$(basename "$zip")"
  local sha size url
  sha=$(compute_sha256 "$zip")
  size=$(file_size_bytes "$zip")
  url=$(r2_public_url "$key")
  r2_put_object "$key" "$zip" "application/zip"
  printf '%s\n%s\n%s\n%s\n' "$url" "$sha" "$size" "Rivai Launcher.app"
}

MAC_ENTRY=""
WIN_ENTRY=""

if [[ -n "$MAC_INPUT" ]]; then
  zip=$(prepare_mac_zip "$MAC_INPUT")
  if is_dry_run; then
    MAC_ENTRY=$(printf 'PLACEHOLDER_URL\n0000000000000000000000000000000000000000000000000000000000000000\n0\nRivai Launcher.app\n')
  else
    MAC_ENTRY=$(upload_and_describe "mac" "$zip")
  fi
fi

if [[ -n "$WIN_INPUT" ]]; then
  zip=$(prepare_win_zip "$WIN_INPUT")
  if is_dry_run; then
    WIN_ENTRY=$(printf 'PLACEHOLDER_URL\n0000000000000000000000000000000000000000000000000000000000000000\n0\nRivai Launcher.exe\n')
  else
    WIN_ENTRY=$(upload_and_describe "win64" "$zip")
  fi
fi

# ---- Merge with existing launcher manifest -----------------------------
EXISTING_JSON=$(curl -fsSL "$(r2_public_url "manifest/launcher/${CHANNEL}.json")" 2>/dev/null || echo '{}')

NEW_JSON=$(python3 - <<PY
import json, sys, os
existing = json.loads(${EXISTING_JSON@Q})
m = {
    "project":       "Rivai",
    "channel":       ${CHANNEL@Q},
    "latestVersion": ${VERSION@Q},
    "buildId":       ${BUILD_ID@Q},
    "releasedAt":    ${RELEASED_AT@Q},
    "launcher":      existing.get("launcher", {}),
}

def entry_block(block):
    if not block:
        return None
    lines = block.strip().split("\n")
    return {
        "arch": "arm64" if "mac" in os.environ.get("PLATFORM_KEY","") else "x64",
        "downloadUrl": lines[0],
        "sha256":      lines[1],
        "sizeBytes":   int(lines[2]),
        "executable":  lines[3],
    }

mac_entry = ${MAC_ENTRY@Q}
win_entry = ${WIN_ENTRY@Q}

if mac_entry.strip():
    lines = mac_entry.strip().split("\n")
    m["launcher"]["mac"] = {
        "arch": "arm64",
        "downloadUrl": lines[0],
        "sha256":      lines[1],
        "sizeBytes":   int(lines[2]),
        "executable":  lines[3],
    }
if win_entry.strip():
    lines = win_entry.strip().split("\n")
    m["launcher"]["win64"] = {
        "arch": "x64",
        "downloadUrl": lines[0],
        "sha256":      lines[1],
        "sizeBytes":   int(lines[2]),
        "executable":  lines[3],
    }

print(json.dumps(m, indent=2, ensure_ascii=False))
PY
)

OUT="$STAGE_DIR/launcher-dev.json"
if is_dry_run; then
  printf '[dry  ] would upload launcher manifest:\n%s\n' "$NEW_JSON" >&2
else
  printf '%s\n' "$NEW_JSON" > "$OUT"
  r2_put_json "manifest/launcher/${CHANNEL}.json" "$OUT"
  log "launcher manifest updated"
fi

log "done."
