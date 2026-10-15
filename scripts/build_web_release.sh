#!/usr/bin/env bash
# Production web release for Attendiphi (Supabase-only client).
# Injects CHECKIN_SESSION_TOKEN_SECRET + SUPABASE_URL/ANON_KEY into Dart and
# rewrites web/index.html meta tags from the same values (no drift).
# Output: build/web + build/web.zip for devops → https://attendiphi.metaphi.in
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SECRETS_DIR="$ROOT/.secrets"
SECRET_FILE="$SECRETS_DIR/checkin_session_token_secret"

resolve_secret() {
  if [[ -n "${CHECKIN_SESSION_TOKEN_SECRET:-}" ]]; then
    printf '%s' "$CHECKIN_SESSION_TOKEN_SECRET"
    return
  fi
  # CI / release trains must supply the secret via env — never invent or
  # silently reuse a local .secrets file in automated pipelines.
  if [[ "${CI:-}" == "true" || "${ATTENDIPHI_REQUIRE_SECRET:-}" == "1" ]]; then
    echo "error: CHECKIN_SESSION_TOKEN_SECRET missing (CI/require mode)." >&2
    echo "Export CHECKIN_SESSION_TOKEN_SECRET (≥16 chars) in the pipeline." >&2
    exit 1
  fi
  if [[ -f "$SECRET_FILE" ]]; then
    tr -d '\r\n' <"$SECRET_FILE"
    return
  fi
  mkdir -p "$SECRETS_DIR"
  local generated
  generated="$(openssl rand -hex 32)"
  printf '%s\n' "$generated" >"$SECRET_FILE"
  chmod 600 "$SECRET_FILE" 2>/dev/null || true
  echo "Created $SECRET_FILE (gitignored). Reuse this file for future deploys so printed QR standees keep verifying." >&2
  printf '%s' "$generated"
}

CHECKIN_SESSION_TOKEN_SECRET="$(resolve_secret)"
export CHECKIN_SESSION_TOKEN_SECRET

if [[ -z "$CHECKIN_SESSION_TOKEN_SECRET" ]]; then
  echo "error: CHECKIN_SESSION_TOKEN_SECRET is empty." >&2
  exit 1
fi

if [[ "${#CHECKIN_SESSION_TOKEN_SECRET}" -lt 16 ]]; then
  echo "error: CHECKIN_SESSION_TOKEN_SECRET must be at least 16 characters." >&2
  exit 1
fi

# Single source for Supabase client config (Dart dart-define + index.html meta).
SUPABASE_URL="${SUPABASE_URL:-https://fzghxzybyygslfjyfewu.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_sxoF5zOkdBhDJOm3EH6PjA_uSswNowX}"
export SUPABASE_URL SUPABASE_ANON_KEY

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "error: SUPABASE_URL and SUPABASE_ANON_KEY are required." >&2
  exit 1
fi

INDEX_HTML="$ROOT/web/index.html"
if [[ -f "$INDEX_HTML" ]]; then
  # Rewrite meta tags in-place from the same env used for dart-define.
  python3 - <<PY
from pathlib import Path
path = Path("$INDEX_HTML")
text = path.read_text()
url = """$SUPABASE_URL"""
key = """$SUPABASE_ANON_KEY"""
import re
text = re.sub(
    r'(<meta name="supabase-url" content=")[^"]*(">)',
    r'\g<1>' + url + r'\g<2>',
    text,
    count=1,
)
text = re.sub(
    r'(<meta name="supabase-anon-key" content=")[^"]*(">)',
    r'\g<1>' + key + r'\g<2>',
    text,
    count=1,
)
path.write_text(text)
print(f"Synced web/index.html supabase meta → {url}")
PY
fi

echo "Building Flutter web release…"
echo "  CHECKIN_SESSION_TOKEN_SECRET (${#CHECKIN_SESSION_TOKEN_SECRET} chars)"
echo "  SUPABASE_URL=$SUPABASE_URL"
flutter build web --release --base-href / \
  --dart-define="CHECKIN_SESSION_TOKEN_SECRET=${CHECKIN_SESSION_TOKEN_SECRET}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"

ZIP_PATH="$ROOT/build/web.zip"
rm -f "$ZIP_PATH"
(
  cd "$ROOT/build"
  zip -qr web.zip web
)
echo "Build complete: build/web"
echo "Devops package: $ZIP_PATH"
echo "Keep .secrets/checkin_session_token_secret stable across deploys; rotating it invalidates printed standees."
echo "See docs/DEVOPS_WEB_DEPLOY.md for nginx SPA notes."
