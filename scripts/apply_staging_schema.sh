#!/usr/bin/env bash
# Apply Attendiphi migrations to attendiphi-test ONLY.
# Never targets live prod (fzghxzybyygslfjyfewu).
set -euo pipefail

STAGING_REF="ofieqhdkvofsjnpxkmee"
PROD_REF="fzghxzybyygslfjyfewu"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "TARGET --project-ref=${STAGING_REF} (Attendiphi-test)"
echo "ABORT if anything would use ${PROD_REF}"

npx supabase link --project-ref "$STAGING_REF"
LINKED="$(cat supabase/.temp/project-ref 2>/dev/null || true)"
if [[ "$LINKED" != "$STAGING_REF" ]]; then
  echo "error: linked project is '$LINKED', expected $STAGING_REF" >&2
  exit 1
fi

npx supabase db push --linked
echo "Migrations applied to ${STAGING_REF}."
echo "Next: set app_secrets + seed (see docs/STAGING.md)."
