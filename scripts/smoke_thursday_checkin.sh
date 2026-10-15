#!/usr/bin/env bash
# Smoke-test public check-in via submit_public_check_in RPC (P0/P1).
# Uses SUPABASE_URL / SUPABASE_ANON_KEY from env when set.
set -euo pipefail

URL="${SUPABASE_URL:-https://fzghxzybyygslfjyfewu.supabase.co}"
KEY="${SUPABASE_ANON_KEY:-}"
if [[ -z "$KEY" ]]; then
  echo "error: set SUPABASE_ANON_KEY" >&2
  exit 1
fi

# Prefer a real Thursday; override with SESSION_DATE=YYYY-MM-DD
SESSION="${SESSION_DATE:-2026-10-15}"
TS="${SESSION}T08:30:00Z"
AUTH=(-H "apikey: $KEY" -H "Authorization: Bearer $KEY")
HDR=("${AUTH[@]}" -H "Content-Type: application/json" -H "Prefer: return=representation")

echo "Smoke Thursday check-in → $URL session=$SESSION (RPC)"

# public_members readable; members table should not be broadly readable
PM=$(curl -sS "$URL/rest/v1/public_members?select=id&limit=2" "${AUTH[@]}")
echo "$PM" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d,list) and len(d)>=1, d"
MID1=$(echo "$PM" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
MID2=$(echo "$PM" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[1]['id'] if len(d)>1 else d[0]['id'])")
echo "public_members: ok ($MID1 / $MID2)"

# Anon must not list check_ins
CODE=$(curl -sS -o /tmp/smoke_ci.json -w '%{http_code}' \
  "$URL/rest/v1/check_ins?select=id&limit=1" "${AUTH[@]}")
echo "anon GET check_ins → HTTP $CODE (expect 200 empty or 401/403)"
# 200 with [] is also fine under RLS deny-all select

rpc_submit() {
  local id="$1" phone="$2" name="$3" type="$4" member_id="${5:-}"
  local row
  row=$(python3 - <<PY
import json
row = {
  "id": "$id",
  "type": "$type",
  "location_id": "location_x",
  "location_name": "Jade",
  "user_name": "$name",
  "user_phone": "$phone",
  "user_latitude": 19.0829,
  "user_longitude": 72.9129,
  "gps_accuracy": 10,
  "distance_meters": 20,
  "session_date": "$SESSION",
  "timestamp": "$TS",
  "attended_at": "$TS",
  "has_photo": False,
  "device_id": "smoke-device",
}
mid = "$member_id".strip()
if mid:
  row["member_id"] = mid
print(json.dumps({
  "p_row": row,
  "p_session_date": "$SESSION",
  "p_claim_member_id": mid or None,
  "p_session_token": None,
  "p_enforce_restrictions": False,
}))
PY
)
  local tmp code
  tmp="$(mktemp)"
  code="$(curl -sS -o "$tmp" -w '%{http_code}' -X POST \
    "$URL/rest/v1/rpc/submit_public_check_in" "${HDR[@]}" -d "$row")"
  echo "  rpc $id → HTTP $code"
  if [[ "$code" != "200" ]]; then
    echo "    body: $(tr '\n' ' ' <"$tmp")" >&2
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

cleanup() {
  echo "(cleanup is admin/service-role only after P0 — leave smoke rows or delete in SQL Editor)"
}
trap cleanup EXIT

echo "member…"
rpc_submit "_smoke_member_p1" "+919111111111" "Smoke Member" "member" "$MID1"

echo "duplicate phone (expect fail)…"
if rpc_submit "_smoke_member_p1_dup" "+919111111111" "Smoke Dup" "member" "$MID1"; then
  echo "error: duplicate phone should fail" >&2
  exit 1
else
  echo "  duplicate rejected: ok"
fi

echo "Smoke P1 RPC path: ok"
