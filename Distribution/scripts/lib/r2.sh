#!/usr/bin/env bash
# r2.sh — thin wrapper around wrangler for R2 operations.
# Source after lib/common.sh.

R2_BUCKET=${R2_BUCKET:-rivai-dist}
R2_PUBLIC_BASE=${R2_PUBLIC_BASE:-https://pub-0ac7d3ef69e344e1bb87f0d1475315cb.r2.dev}

# r2_put_object KEY FILE CONTENT_TYPE [CACHE_CONTROL]
r2_put_object() {
  local key="$1" file="$2" ct="$3" cc="${4:-}"
  require_command wrangler
  local cmd=(wrangler r2 object put "${R2_BUCKET}/${key}" --file="$file" --content-type="$ct" --remote)
  [[ -n "$cc" ]] && cmd+=(--cache-control="$cc")
  run "R2 upload: ${R2_BUCKET}/${key} (${ct}$( [[ -n "$cc" ]] && echo ", $cc" ))" "${cmd[@]}"
}

# r2_put_json KEY FILE  — convenience for manifest-like JSON with short cache
r2_put_json() {
  r2_put_object "$1" "$2" "application/json" "public, max-age=60, must-revalidate"
}

# r2_public_url KEY
r2_public_url() {
  echo "${R2_PUBLIC_BASE}/$1"
}
