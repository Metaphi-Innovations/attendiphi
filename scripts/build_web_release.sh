#!/usr/bin/env bash
# Production web release build for Attendiphi.
# Requires CHECKIN_SESSION_TOKEN_SECRET so QR session tokens are not signed
# with the public bootstrap HMAC secret baked into debug builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${CHECKIN_SESSION_TOKEN_SECRET:-}" ]]; then
  echo "error: CHECKIN_SESSION_TOKEN_SECRET is not set." >&2
  echo "Export a long random secret, then re-run:" >&2
  echo "  export CHECKIN_SESSION_TOKEN_SECRET=\"\$(openssl rand -hex 32)\"" >&2
  echo "  ./scripts/build_web_release.sh" >&2
  exit 1
fi

if [[ "${#CHECKIN_SESSION_TOKEN_SECRET}" -lt 16 ]]; then
  echo "error: CHECKIN_SESSION_TOKEN_SECRET must be at least 16 characters." >&2
  exit 1
fi

echo "Building Flutter web release with CHECKIN_SESSION_TOKEN_SECRET…"
flutter build web --release --base-href / \
  --dart-define="CHECKIN_SESSION_TOKEN_SECRET=${CHECKIN_SESSION_TOKEN_SECRET}"

echo "Build complete: build/web"
echo "Deploy with: firebase deploy --only hosting:attendiphi"
echo "Regenerate QR standees after rotating the secret."
