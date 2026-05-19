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
MAC_ARCH="arm64"
WIN_INPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2 ;;
    --build-id) BUILD_ID="$2"; shift 2 ;;
    --channel)  CHANNEL="$2"; shift 2 ;;
    --mac)      MAC_INPUT="$2"; shift 2 ;;
    --mac-arch) MAC_ARCH="$2"; shift 2 ;;
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

prepare_mac_artifact() {
  local input="$1"
  local out_zip="$STAGE_DIR/rivai-launcher_${VERSION}_mac_${MAC_ARCH}.zip"
  local out_dmg="$STAGE_DIR/rivai-launcher_${VERSION}_mac_${MAC_ARCH}.dmg"
  if [[ -d "$input" && "$input" == *.app ]]; then
    log "ditto compress: $input → $(basename "$out_zip")"
    if is_dry_run; then
      printf '[dry  ] ditto -c -k --sequesterRsrc --keepParent %q %q\n' "$input" "$out_zip" >&2
    else
      rm -f "$out_zip"
      ditto -c -k --sequesterRsrc --keepParent "$input" "$out_zip"
    fi
    echo "$out_zip"
  elif [[ -f "$input" && "$input" == *.zip ]]; then
    log "using existing zip: $input"
    cp "$input" "$out_zip"
    echo "$out_zip"
  elif [[ -f "$input" && "$input" == *.dmg ]]; then
    log "using existing dmg: $input"
    cp "$input" "$out_dmg"
    echo "$out_dmg"
  else
    die "--mac expects a .app directory, .zip file, or .dmg file: $input"
  fi
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
  local platform="$1" file="$2" executable="$3"
  local format content_type
  case "$file" in
    *.dmg) format=dmg; content_type="application/x-apple-diskimage" ;;
    *.zip) format=zip; content_type="application/zip" ;;
    *)     die "unsupported artifact extension: $file" ;;
  esac
  local key="builds/${CHANNEL}/launcher/${platform}/$(basename "$file")"
  local sha size url
  sha=$(compute_sha256 "$file")
  size=$(file_size_bytes "$file")
  url=$(r2_public_url "$key")
  r2_put_object "$key" "$file" "$content_type"
  printf '%s\n%s\n%s\n%s\n%s\n' "$url" "$sha" "$size" "$executable" "$format"
}

MAC_ENTRY=""
WIN_ENTRY=""

if [[ -n "$MAC_INPUT" ]]; then
  artifact=$(prepare_mac_artifact "$MAC_INPUT")
  if is_dry_run; then
    case "$artifact" in *.dmg) fmt=dmg ;; *) fmt=zip ;; esac
    MAC_ENTRY=$(printf 'PLACEHOLDER_URL\n0000000000000000000000000000000000000000000000000000000000000000\n0\nRivai Launcher.app\n%s\n' "$fmt")
  else
    MAC_ENTRY=$(upload_and_describe "mac" "$artifact" "Rivai Launcher.app")
  fi
fi

if [[ -n "$WIN_INPUT" ]]; then
  zip=$(prepare_win_zip "$WIN_INPUT")
  if is_dry_run; then
    WIN_ENTRY=$(printf 'PLACEHOLDER_URL\n0000000000000000000000000000000000000000000000000000000000000000\n0\nRivai Launcher.exe\nzip\n')
  else
    WIN_ENTRY=$(upload_and_describe "win64" "$zip" "Rivai Launcher.exe")
  fi
fi

# ---- Merge with existing launcher manifest -----------------------------
EXISTING_JSON=$(curl -fsSL "$(r2_public_url "manifest/launcher/${CHANNEL}.json")" 2>/dev/null || echo '{}')

# Pass everything as env vars (bash @Q quoting varies between macOS/Linux).
NEW_JSON=$(
  EXISTING_JSON="$EXISTING_JSON" \
  MAC_ENTRY="$MAC_ENTRY" \
  MAC_ARCH="$MAC_ARCH" \
  WIN_ENTRY="$WIN_ENTRY" \
  VERSION="$VERSION" \
  BUILD_ID="$BUILD_ID" \
  CHANNEL="$CHANNEL" \
  RELEASED_AT="$RELEASED_AT" \
  python3 - <<'PY'
import json, os

existing = json.loads(os.environ.get('EXISTING_JSON') or '{}')

m = {
    "project":       "Rivai",
    "channel":       os.environ['CHANNEL'],
    "latestVersion": os.environ['VERSION'],
    "buildId":       os.environ['BUILD_ID'],
    "releasedAt":    os.environ['RELEASED_AT'],
    "launcher":      existing.get("launcher", {}),
}

def parse_entry(block, arch):
    lines = block.split("\n")
    entry = {
        "arch":        arch,
        "downloadUrl": lines[0],
        "sha256":      lines[1],
        "sizeBytes":   int(lines[2]),
        "executable":  lines[3],
    }
    if len(lines) > 4 and lines[4]:
        entry["format"] = lines[4]
    return entry

mac_entry = os.environ.get('MAC_ENTRY', '').strip()
win_entry = os.environ.get('WIN_ENTRY', '').strip()

if mac_entry:
    m["launcher"]["mac"]   = parse_entry(mac_entry, os.environ.get('MAC_ARCH', 'arm64'))
if win_entry:
    m["launcher"]["win64"] = parse_entry(win_entry, "x64")

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
