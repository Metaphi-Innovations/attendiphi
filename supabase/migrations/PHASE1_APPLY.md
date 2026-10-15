# Phase P1 — Storage photos, admin RLS, rate limits

**Project:** `fzghxzybyygslfjyfewu`  
**Requires:** P0 applied (`20261015110000_p0_rls_lockdown_submit_rpc.sql`)

## 1. Run migration

Dashboard → SQL Editor → paste and run:

`20261015120000_p1_storage_admin_rls_rate_limits.sql`

## 2. Redeploy Edge Function

```bash
supabase functions deploy send-attendiphi-email --project-ref fzghxzybyygslfjyfewu
```

Password-reset rate limits now call `bump_email_rate_limit` (persisted).

## 3. Deploy Flutter web

```bash
./scripts/build_web_release.sh
```

Optional: `--dart-define=SENTRY_DSN=…` when ready for crash reporting.

## 4. Smoke

```bash
# Staging / project with anon key:
./scripts/smoke_thursday_checkin.sh
```

Manual:

- Substitute selfie uploads to Storage (`check-in-photos/{session}/{id}.jpg`)
- Admin substitutes UI loads photo on demand (signed URL)
- Anon `GET /admins?select=password_hash` → denied / empty
- Non-superadmin with `assigned_location_ids` cannot read other locations’ check-ins
- Release: `/checkin/location_x?date=…` → invalid session screen
