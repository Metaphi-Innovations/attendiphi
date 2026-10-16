#!/usr/bin/env bash
# Stage 1 — run Attendiphi web against local Docker Supabase.
# Entry: lib/main_dev.dart
#
# Prerequisites:
#   docker running
#   supabase start
#   migrations applied (supabase db reset / migration up)
#
# Optional: ~/.attendiphi/local.env (see docs/local.env.example)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOCAL_ENV="${ATTENDIPHI_LOCAL_ENV:-$HOME/.attendiphi/local.env}"
if [[ -f "$LOCAL_ENV" ]]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "$LOCAL_ENV"
  set +a
  echo "Loaded local env from $LOCAL_ENV"
fi

LOCAL_URL="${SUPABASE_URL_LOCAL:-http://127.0.0.1:54321}"
LOCAL_ANON="${SUPABASE_ANON_KEY_LOCAL:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
SESSION_SECRET="${CHECKIN_SESSION_TOKEN_SECRET:-local-dev-secret-16}"

DEVICE="${1:-chrome}"

if [[ ! -f lib/main_dev.dart ]]; then
  echo "error: lib/main_dev.dart missing." >&2
  exit 1
fi

echo "Local web → $LOCAL_URL (target: lib/main_dev.dart, device: $DEVICE)"
echo "Ensure Docker Supabase is up: supabase start && supabase status"

exec flutter run -d "$DEVICE" -t lib/main_dev.dart \
  --dart-define="SUPABASE_URL_LOCAL=${LOCAL_URL}" \
  --dart-define="SUPABASE_ANON_KEY_LOCAL=${LOCAL_ANON}" \
  --dart-define="CHECKIN_SESSION_TOKEN_SECRET=${SESSION_SECRET}"
