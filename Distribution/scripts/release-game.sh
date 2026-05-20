#!/usr/bin/env bash
# release-game.sh — publish a game build (Mac required, Windows optional) and refresh
# the game manifest, patch notes, and portal in a single command.
#
# M0: Windows client is still TBD — pass --client-win64 only once a real build exists.
# Without it, the portal shows the Windows card as "Coming soon" and the launcher manifest
# simply omits client.win64.
#
# Usage:
#   ./release-game.sh \
#     --version 0.0.2-dev \
#     --build-id 2026.05.18.003 \
#     --channel dev \
#     --client-mac   path/to/mac.zip   \
#     [--client-win64 path/to/win64.zip] \
#     [--notes path/to/notes.json] \
#     [--skip-portal-deploy] \
#     [--dry-run]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/r2.sh"

VERSION=""
BUILD_ID=""
CHANNEL="dev"
WIN_ZIP=""
MAC_ZIP=""
NOTES=""
SKIP_PORTAL=0
SERVER_NAME=${SERVER_NAME:-"Test Server 01"}
SERVER_HOST=${SERVER_HOST:-"test.rivai.example"}
SERVER_PORT=${SERVER_PORT:-7777}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)             VERSION="$2"; shift 2 ;;
    --build-id)            BUILD_ID="$2"; shift 2 ;;
    --channel)             CHANNEL="$2"; shift 2 ;;
    --client-win64)        WIN_ZIP="$2"; shift 2 ;;
    --client-mac)          MAC_ZIP="$2"; shift 2 ;;
    --notes)               NOTES="$2"; shift 2 ;;
    --skip-portal-deploy)  SKIP_PORTAL=1; shift ;;
    --dry-run)             DRY_RUN=1; shift ;;
    *) die "unknown flag: $1" ;;
  esac
done

[[ -n "$VERSION"  ]] || die "--version required"
[[ -n "$BUILD_ID" ]] || die "--build-id required"
[[ -n "$MAC_ZIP" && -f "$MAC_ZIP" ]] || die "--client-mac must be an existing zip"
if [[ -n "$WIN_ZIP" ]]; then
  [[ -f "$WIN_ZIP" ]] || die "--client-win64 file not found: $WIN_ZIP"
fi

require_command wrangler shasum python3

PORTAL_DIR="$DIST_ROOT/Distribution/portal"
[[ -d "$DIST_ROOT/portal" ]] && PORTAL_DIR="$DIST_ROOT/portal"

RELEASED_AT=$(iso_now)
RELEASED_DATE=$(date "+%Y-%m-%d")

MAC_SHA=$(compute_sha256 "$MAC_ZIP"); MAC_SIZE=$(file_size_bytes "$MAC_ZIP")
log "mac:   $(human_size "$MAC_SIZE") $MAC_SHA"
if [[ -n "$WIN_ZIP" ]]; then
  WIN_SHA=$(compute_sha256 "$WIN_ZIP"); WIN_SIZE=$(file_size_bytes "$WIN_ZIP")
  log "win64: $(human_size "$WIN_SIZE") $WIN_SHA"
else
  log "win64: (skipped — no --client-win64; manifest will omit client.win64)"
fi

# ---- 1. Upload zips ---------------------------------------------------
MAC_KEY="builds/${CHANNEL}/client/mac/rivai_client_${VERSION}_${CHANNEL}_mac.zip"
r2_put_object "$MAC_KEY" "$MAC_ZIP" "application/zip"
MAC_URL=$(r2_public_url "$MAC_KEY")

WIN_URL=""
if [[ -n "$WIN_ZIP" ]]; then
  WIN_KEY="builds/${CHANNEL}/client/win64/rivai_client_${VERSION}_${CHANNEL}_win64.zip"
  r2_put_object "$WIN_KEY" "$WIN_ZIP" "application/zip"
  WIN_URL=$(r2_public_url "$WIN_KEY")
fi

# ---- 2. Write game manifest ------------------------------------------
STAGE_DIR="$DIST_ROOT/Distribution/staging/game/$VERSION"
mkdir -p "$STAGE_DIR"
MANIFEST_OUT="$STAGE_DIR/dev.json"
PATCH_NOTES_URL="https://rivai-portal.pages.dev/patch-notes/${VERSION}/"

WIN_URL="$WIN_URL" WIN_SHA="${WIN_SHA:-}" WIN_SIZE="${WIN_SIZE:-}" \
MAC_URL="$MAC_URL" MAC_SHA="$MAC_SHA" MAC_SIZE="$MAC_SIZE" \
VERSION="$VERSION" BUILD_ID="$BUILD_ID" CHANNEL="$CHANNEL" \
RELEASED_AT="$RELEASED_AT" SERVER_NAME="$SERVER_NAME" \
SERVER_HOST="$SERVER_HOST" SERVER_PORT="$SERVER_PORT" \
PATCH_NOTES_URL="$PATCH_NOTES_URL" \
python3 - <<'PY' > "$MANIFEST_OUT"
import json, os

client = {
    "mac": {
        "downloadUrl": os.environ["MAC_URL"],
        "sha256":      os.environ["MAC_SHA"],
        "sizeBytes":   int(os.environ["MAC_SIZE"]),
        "executable":  "Rivai.app",
        "arch":        "universal",
    }
}
if os.environ.get("WIN_URL"):
    client["win64"] = {
        "downloadUrl": os.environ["WIN_URL"],
        "sha256":      os.environ["WIN_SHA"],
        "sizeBytes":   int(os.environ["WIN_SIZE"]),
        "executable":  "Rivai.exe",
    }

print(json.dumps({
    "project":        "Rivai",
    "channel":        os.environ["CHANNEL"],
    "latestVersion":  os.environ["VERSION"],
    "buildId":        os.environ["BUILD_ID"],
    "releasedAt":     os.environ["RELEASED_AT"],
    "client":         client,
    "server": {
        "name": os.environ["SERVER_NAME"],
        "host": os.environ["SERVER_HOST"],
        "port": int(os.environ["SERVER_PORT"]),
    },
    "patchNotesUrl":  os.environ["PATCH_NOTES_URL"],
    "feedbackUrl":    "https://rivai-portal.pages.dev/feedback",
    "knownIssuesUrl": "https://rivai-portal.pages.dev/known-issues/",
}, indent=2, ensure_ascii=False))
PY

r2_put_json "manifest/${CHANNEL}.json" "$MANIFEST_OUT"

# ---- 3. Render patch notes -------------------------------------------
PATCH_DIR="$PORTAL_DIR/patch-notes/${VERSION}"
"$SCRIPT_DIR/render-patch-notes.sh" \
  --version "$VERSION" \
  --build-id "$BUILD_ID" \
  --channel "$CHANNEL" \
  --released-at "$RELEASED_DATE" \
  ${NOTES:+--notes "$NOTES"} \
  --output "$PATCH_DIR/index.html" \
  $(is_dry_run && echo --dry-run)

# ---- 4. Update patch-notes index ------------------------------------
INDEX_HTML="$PORTAL_DIR/patch-notes/index.html"
if is_dry_run; then
  printf '[dry  ] would prepend build row to %s\n' "$INDEX_HTML" >&2
else
  python3 - "$INDEX_HTML" "$VERSION" "$BUILD_ID" "$RELEASED_DATE" <<'PY'
import sys, re, pathlib
path = pathlib.Path(sys.argv[1])
version, build_id, released = sys.argv[2:5]
html = path.read_text(encoding='utf-8')
row = (
    f'        <li>\n'
    f'          <span class="build-version"><a href="./{version}/">{version}</a></span>\n'
    f'          <span class="build-id">Build {build_id}</span>\n'
    f'          <span class="build-date">{released}</span>\n'
    f'        </li>\n'
)
# Avoid duplicate rows on re-run (idempotency).
if f'href="./{version}/"' in html:
    sys.stderr.write('row already present, skipping insert\n')
else:
    html = re.sub(r'(<ul class="build-list">\s*\n)', r'\1' + row, html, count=1)
    path.write_text(html, encoding='utf-8')
    sys.stderr.write('inserted new row\n')
PY
fi

# ---- 5. Update /latest/ redirect target -----------------------------
LATEST_HTML="$PORTAL_DIR/patch-notes/latest/index.html"
if is_dry_run; then
  printf '[dry  ] would update latest redirect → ../%s/\n' "$VERSION" >&2
else
  mkdir -p "$(dirname "$LATEST_HTML")"
  cat > "$LATEST_HTML" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="refresh" content="0; url=../${VERSION}/" />
  <link rel="canonical" href="../${VERSION}/" />
  <title>Latest patch notes — redirecting…</title>
</head>
<body>
  <p>Redirecting to the latest patch notes. If you aren't redirected automatically, <a href="../${VERSION}/">click here</a>.</p>
</body>
</html>
HTML
  log "updated latest → ../${VERSION}/"
fi

# ---- 6. Portal deploy -------------------------------------------------
if [[ "$SKIP_PORTAL" == "1" ]]; then
  log "--skip-portal-deploy specified; skipping portal redeploy."
else
  if is_dry_run; then
    printf '[dry  ] wrangler pages deploy %s --project-name=rivai-portal --branch=main --commit-dirty=true\n' "$PORTAL_DIR" >&2
  else
    log "wrangler pages deploy → rivai-portal"
    (cd "$PORTAL_DIR" && wrangler pages deploy . --project-name=rivai-portal --branch=main --commit-dirty=true) | tail -10
  fi
fi

log "done."
