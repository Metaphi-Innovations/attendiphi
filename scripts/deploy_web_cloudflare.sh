#!/usr/bin/env bash
# UNUSED — Attendiphi production hosting is nginx at https://attendiphi.metaphi.in
# via build/web.zip (see docs/DEVOPS_WEB_DEPLOY.md and scripts/build_web_release.sh).
#
# This script is retained only as a historical reference. Do not use for client delivery.
set -euo pipefail
echo "error: Cloudflare/Firebase Hosting deploys are out of scope." >&2
echo "Run: ./scripts/build_web_release.sh  →  send build/web.zip to devops." >&2
exit 1
