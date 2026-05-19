#!/usr/bin/env bash
# r2.sh — thin wrapper around wrangler for R2 operations.
# Source after lib/common.sh.

R2_BUCKET=${R2_BUCKET:-rivai-dist}
R2_PUBLIC_BASE=${R2_PUBLIC_BASE:-https://pub-0ac7d3ef69e344e1bb87f0d1475315cb.r2.dev}

# r2_put_object KEY FILE CONTENT_TYPE [CACHE_CONTROL]
#
# Routes by file size:
#   ≤ 300 MiB  → wrangler (Cloudflare API, single PUT)
#   >  300 MiB → boto3 over R2 S3 Compatibility API (multipart) — see K01
R2_WRANGLER_LIMIT_BYTES=${R2_WRANGLER_LIMIT_BYTES:-$((300 * 1024 * 1024))}

r2_put_object() {
  local key="$1" file="$2" ct="$3" cc="${4:-}"
  local size
  size=$(file_size_bytes "$file")
  if (( size > R2_WRANGLER_LIMIT_BYTES )); then
    r2_put_object_boto3 "$key" "$file" "$ct" "$cc"
    return
  fi
  require_command wrangler
  local cmd=(wrangler r2 object put "${R2_BUCKET}/${key}" --file="$file" --content-type="$ct" --remote)
  [[ -n "$cc" ]] && cmd+=(--cache-control="$cc")
  run "R2 upload: ${R2_BUCKET}/${key} (${ct}$( [[ -n "$cc" ]] && echo ", $cc" ))" "${cmd[@]}"
}

r2_put_object_boto3() {
  local key="$1" file="$2" ct="$3" cc="${4:-}"
  local venv=${R2_BOTO3_VENV:-/tmp/r2venv}
  local creds=${R2_CREDENTIALS_FILE:-$HOME/.rivai/r2.env}
  local helper
  helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/r2_upload.py"

  [[ -f "$creds" ]] || die "R2 S3 credentials not found at $creds (see K01)"
  [[ -f "$helper" ]] || die "boto3 helper missing: $helper"

  if [[ ! -x "$venv/bin/python3" ]]; then
    log "bootstrapping boto3 venv at $venv"
    python3 -m venv "$venv"
    "$venv/bin/pip" install --quiet boto3
  fi

  log "R2 upload (boto3 multipart): ${R2_BUCKET}/${key} ($(human_size "$(file_size_bytes "$file")"), ${ct})"
  if is_dry_run; then
    printf '[dry  ] python3 r2_upload.py %q %q %q %q\n' "$key" "$file" "$ct" "$cc" >&2
    return
  fi
  ( set -a; source "$creds"; set +a; "$venv/bin/python3" "$helper" "$key" "$file" "$ct" ${cc:+"$cc"} )
}

# r2_put_json KEY FILE  — convenience for manifest-like JSON with short cache
r2_put_json() {
  r2_put_object "$1" "$2" "application/json" "public, max-age=60, must-revalidate"
}

# r2_public_url KEY
r2_public_url() {
  echo "${R2_PUBLIC_BASE}/$1"
}
