#!/usr/bin/env bash
# Stage 2 — staging web RELEASE for devops → https://attendiphi.staging.metaphi.in
#
# Uses lib/main_staging.dart + attendiphi-test keys (never production).
# Output: build/web/ + build/web-staging.zip
#
# Do NOT use plain `flutter build web --release` for staging — that hits production.
# See docs/ENVIRONMENTS.md / docs/STAGING.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STAGING_ENV="${ATTENDIPHI_STAGING_ENV:-$HOME/.attendiphi/staging.env}"
if [[ -f "$STAGING_ENV" ]]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "$STAGING_ENV"
  set +a
  echo "Loaded staging env from $STAGING_ENV"
fi

SECRETS_DIR="$ROOT/.secrets"
SECRET_FILE="$SECRETS_DIR/checkin_session_token_secret_staging"

resolve_secret() {
  if [[ -n "${CHECKIN_SESSION_TOKEN_SECRET:-}" ]]; then
    printf '%s' "$CHECKIN_SESSION_TOKEN_SECRET"
    return
  fi
  if [[ "${CI:-}" == "true" || "${ATTENDIPHI_REQUIRE_SECRET:-}" == "1" ]]; then
    echo "error: CHECKIN_SESSION_TOKEN_SECRET missing (CI/require mode)." >&2
    exit 1
  fi
  if [[ -f "$SECRET_FILE" ]]; then
    tr -d '\r\n' <"$SECRET_FILE"
    return
  fi
  # Prefer documented staging default when building for attendiphi-test.
  printf '%s' 'staging-dev-secret-16'
}

CHECKIN_SESSION_TOKEN_SECRET="$(resolve_secret)"
export CHECKIN_SESSION_TOKEN_SECRET

if [[ "${#CHECKIN_SESSION_TOKEN_SECRET}" -lt 16 ]]; then
  echo "error: CHECKIN_SESSION_TOKEN_SECRET must be at least 16 characters." >&2
  exit 1
fi

SUPABASE_URL_STAGING="${SUPABASE_URL_STAGING:-https://ofieqhdkvofsjnpxkmee.supabase.co}"
SUPABASE_ANON_KEY_STAGING="${SUPABASE_ANON_KEY_STAGING:-sb_publishable_S3HgjDPER8qwglSX1HIrLg_IyFh6X2_}"
export SUPABASE_URL_STAGING SUPABASE_ANON_KEY_STAGING

# Meta tags in index.html use the generic names; sync to staging URL/key.
SUPABASE_URL="$SUPABASE_URL_STAGING"
SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY_STAGING"
export SUPABASE_URL SUPABASE_ANON_KEY

# Refuse accidental production backend in a staging build.
case "$SUPABASE_URL_STAGING" in
  *fzghxzybyygslfjyfewu*)
    echo "error: staging build refused production Supabase host." >&2
    exit 1
    ;;
esac

if [[ ! -f lib/main_staging.dart ]]; then
  echo "error: lib/main_staging.dart missing." >&2
  exit 1
fi

INDEX_HTML="$ROOT/web/index.html"
if [[ -f "$INDEX_HTML" ]]; then
  python3 - <<PY
from pathlib import Path
import re
path = Path("$INDEX_HTML")
text = path.read_text()
url = """$SUPABASE_URL"""
key = """$SUPABASE_ANON_KEY"""
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

echo "Building Flutter web STAGING release…"
echo "  entrypoint: lib/main_staging.dart"
echo "  CHECKIN_SESSION_TOKEN_SECRET (${#CHECKIN_SESSION_TOKEN_SECRET} chars)"
echo "  SUPABASE_URL_STAGING=$SUPABASE_URL_STAGING"
echo "  → devops host: https://attendiphi.staging.metaphi.in"

flutter build web --release --base-href / \
  -t lib/main_staging.dart \
  --dart-define="CHECKIN_SESSION_TOKEN_SECRET=${CHECKIN_SESSION_TOKEN_SECRET}" \
  --dart-define="SUPABASE_URL_STAGING=${SUPABASE_URL_STAGING}" \
  --dart-define="SUPABASE_ANON_KEY_STAGING=${SUPABASE_ANON_KEY_STAGING}"

ZIP_PATH="$ROOT/build/web-staging.zip"
rm -f "$ZIP_PATH"
(
  cd "$ROOT/build"
  zip -qr web-staging.zip web
)
echo "Build complete: build/web"
echo "Devops package: $ZIP_PATH"
echo "→ https://attendiphi.staging.metaphi.in"
echo "See docs/ENVIRONMENTS.md and docs/DEVOPS_WEB_DEPLOY.md"
