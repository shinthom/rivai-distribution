#!/usr/bin/env bash
# render-patch-notes.sh — render a patch-notes HTML page from the template.
#
# Usage:
#   ./render-patch-notes.sh \
#     --version 0.0.2-dev \
#     --build-id 2026.05.18.001 \
#     --channel dev \
#     --released-at 2026-05-18 \
#     --notes path/to/notes.json \
#     --output portal/patch-notes/0.0.2/index.html
#
# notes.json schema:
#   {
#     "testFocus": ["...", "..."],
#     "changes":   ["...", "..."],
#     "fixes":     ["...", "..."],
#     "knownIssues": ["..."],
#     "prevVersion": "0.0.1-dev"   // optional
#   }
#
# Variables that are not provided default to empty/placeholder content.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

VERSION=""
BUILD_ID=""
CHANNEL="dev"
RELEASED_AT=""
NOTES=""
OUTPUT=""
TEMPLATE="$DIST_ROOT/Distribution/templates/patch-notes.html"
[[ -d "$DIST_ROOT/templates" ]] && TEMPLATE="$DIST_ROOT/templates/patch-notes.html"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)     VERSION="$2"; shift 2 ;;
    --build-id)    BUILD_ID="$2"; shift 2 ;;
    --channel)     CHANNEL="$2"; shift 2 ;;
    --released-at) RELEASED_AT="$2"; shift 2 ;;
    --notes)       NOTES="$2"; shift 2 ;;
    --output)      OUTPUT="$2"; shift 2 ;;
    --template)    TEMPLATE="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    *) die "unknown flag: $1" ;;
  esac
done

[[ -n "$VERSION"     ]] || die "--version required"
[[ -n "$BUILD_ID"    ]] || die "--build-id required"
[[ -n "$RELEASED_AT" ]] || die "--released-at required"
[[ -n "$OUTPUT"      ]] || die "--output required"
[[ -f "$TEMPLATE"    ]] || die "template not found: $TEMPLATE"

require_command python3

# Build HTML lists from notes.json. python3 is used purely for JSON safety;
# we don't take a runtime dependency on any library beyond stdlib.
read_notes() {
  if [[ -z "$NOTES" ]]; then
    echo '{}'
  else
    cat "$NOTES"
  fi
}

build_html_lists() {
  local json
  json=$(read_notes)
  python3 - "$VERSION" <<'PY'
import json, sys, html
version = sys.argv[1]
src = sys.stdin.read().strip() or '{}'
notes = json.loads(src)

def ul(items):
    items = [i for i in (items or []) if str(i).strip()]
    if not items:
        return '<p class="doc-section empty" style="padding:0;margin:0">Nothing yet.</p>'
    return '<ul>' + ''.join(f'<li>{html.escape(i)}</li>' for i in items) + '</ul>'

def prev_link(prev):
    if not prev:
        return '<em>None</em>'
    p = html.escape(prev)
    return f'<a href="../{p}/">{p}</a>'

print('---TEST_FOCUS---')
print(ul(notes.get('testFocus')))
print('---CHANGES---')
print(ul(notes.get('changes')))
print('---FIXES---')
print(ul(notes.get('fixes')))
print('---KNOWN_ISSUES---')
print(ul(notes.get('knownIssues')))
print('---PREV---')
print(prev_link(notes.get('prevVersion')))
PY
}

# Slice the python output into individual variables.
RAW=$(build_html_lists <<< "$(read_notes)")
extract() { awk -v key="---$1---" 'f && /^---/{exit} f{print} $0==key{f=1}' <<< "$RAW"; }

TEST_FOCUS_HTML=$(extract TEST_FOCUS)
CHANGES_HTML=$(extract CHANGES)
FIXES_HTML=$(extract FIXES)
KNOWN_ISSUES_HTML=$(extract KNOWN_ISSUES)
PREV_BUILD_HTML=$(extract PREV)

# Substitute into template. Use python for safe replacement (no sed escaping pitfalls).
RENDERED=$(python3 - <<PY
import sys
with open("$TEMPLATE", encoding="utf-8") as f:
    t = f.read()
subs = {
    "{{VERSION}}":           "$VERSION",
    "{{BUILD_ID}}":          "$BUILD_ID",
    "{{CHANNEL}}":           "$CHANNEL",
    "{{RELEASED_AT}}":       "$RELEASED_AT",
    "{{TEST_FOCUS_HTML}}":   """$TEST_FOCUS_HTML""",
    "{{CHANGES_HTML}}":      """$CHANGES_HTML""",
    "{{FIXES_HTML}}":        """$FIXES_HTML""",
    "{{KNOWN_ISSUES_HTML}}": """$KNOWN_ISSUES_HTML""",
    "{{PREV_BUILD_HTML}}":   """$PREV_BUILD_HTML""",
}
for k, v in subs.items():
    t = t.replace(k, v)
sys.stdout.write(t)
PY
)

if is_dry_run; then
  printf '[dry  ] would write %s (%d bytes)\n' "$OUTPUT" "${#RENDERED}" >&2
else
  mkdir -p "$(dirname "$OUTPUT")"
  printf '%s' "$RENDERED" > "$OUTPUT"
  log "rendered → $OUTPUT"
fi
