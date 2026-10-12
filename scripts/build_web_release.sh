#!/usr/bin/env bash
# Production web release build for Attendiphi.
# Injects CHECKIN_SESSION_TOKEN_SECRET so QR session tokens are signed with a
# stable Hosting key (not only the public bootstrap fallback).
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
  if [[ -f "$SECRET_FILE" ]]; then
    # Trim whitespace/newlines from file contents
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

echo "Building Flutter web release with CHECKIN_SESSION_TOKEN_SECRET (${#CHECKIN_SESSION_TOKEN_SECRET} chars)…"
flutter build web --release --base-href / \
  --dart-define="CHECKIN_SESSION_TOKEN_SECRET=${CHECKIN_SESSION_TOKEN_SECRET}"

echo "Build complete: build/web"
echo "Deploy with: firebase deploy --only hosting:attendiphi"
echo "Keep .secrets/checkin_session_token_secret stable across deploys; rotating it invalidates printed standees."
