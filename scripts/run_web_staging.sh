#!/usr/bin/env bash
# Run Attendiphi web against Supabase attendiphi-test (staging).
# Entry: lib/main_staging.dart — does not use production defaults.
#
# Optional machine-only overrides:
#   ~/.attendiphi/staging.env  (or ATTENDIPHI_STAGING_ENV=/path/to/file)
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

STAGING_URL="${SUPABASE_URL_STAGING:-https://ofieqhdkvofsjnpxkmee.supabase.co}"
STAGING_ANON="${SUPABASE_ANON_KEY_STAGING:-sb_publishable_S3HgjDPER8qwglSX1HIrLg_IyFh6X2_}"
SESSION_SECRET="${CHECKIN_SESSION_TOKEN_SECRET:-staging-dev-secret-16}"

DEVICE="${1:-chrome}"

echo "Staging web → $STAGING_URL (target: lib/main_staging.dart, device: $DEVICE)"

exec flutter run -d "$DEVICE" -t lib/main_staging.dart \
  --dart-define="SUPABASE_URL_STAGING=${STAGING_URL}" \
  --dart-define="SUPABASE_ANON_KEY_STAGING=${STAGING_ANON}" \
  --dart-define="CHECKIN_SESSION_TOKEN_SECRET=${SESSION_SECRET}"
