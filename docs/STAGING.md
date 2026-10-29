# Attendiphi staging (attendiphi-test)

## Staging vs production

| | Staging | Production |
|---|---|---|
| **Entrypoint** | `lib/main_staging.dart` or local `flutter run` (`main.dart` debug → staging) | Release `main.dart` / `main_prod.dart` / `build_web_release.sh` |
| **Supabase project** | **Attendiphi-test** (`ofieqhdkvofsjnpxkmee`) | **Attendiphi** (`fzghxzybyygslfjyfewu`) |
| **Region** | `ap-northeast-2` | `ap-northeast-1` |
| **Data** | Demo / safe to break | Real members & check-ins |
| **Git (team process)** | Prefer `staging` branch | `main` → live deploy |
| **Keys** | `SUPABASE_URL_STAGING` / `SUPABASE_ANON_KEY_STAGING` | `SUPABASE_URL` / `SUPABASE_ANON_KEY` |

Never put **service_role** keys in the Flutter app or git.

## Run locally (always demo DB)

Local debug/profile defaults to **attendiphi-test** so day-to-day work never
touches live data:

```bash
flutter run -d chrome          # uses demo DB
# or explicitly:
./scripts/run_web_staging.sh
```

Smoke-check: Network / logs should show host `ofieqhdkvofsjnpxkmee.supabase.co`,
not `fzghxzybyygslfjyfewu.supabase.co`.

**Live data** only after you merge to `main` and build/deploy with
`./scripts/build_web_release.sh` (release mode → production).  
Rare intentional live local: `flutter run -t lib/main_prod.dart`.

`CHECKIN_SESSION_TOKEN_SECRET` for staging Flutter defaults to `staging-dev-secret-16`
(must match `public.app_secrets` on **test**) when using `./scripts/run_web_staging.sh`.

### Local keys (optional)

The env file is **optional**. Without it, `./scripts/run_web_staging.sh` uses
built-in attendiphi-test defaults. With it, the script loads overrides first.

```bash
mkdir -p ~/.attendiphi
cp docs/staging.env.example ~/.attendiphi/staging.env
chmod 600 ~/.attendiphi/staging.env
# edit values if needed (never commit this file)
./scripts/run_web_staging.sh
```

- Path: `~/.attendiphi/staging.env` (or set `ATTENDIPHI_STAGING_ENV` to another path)
- Template: `docs/staging.env.example` (safe to commit; placeholders only)
- Put **test** `service_role` here only for seed scripts — never in Flutter / never in git
- Do **not** put production keys in this file

## Schema + demo data on attendiphi-test (step 2)

Applied against **`--project-ref ofieqhdkvofsjnpxkmee` only** (never prod):

1. `npx supabase link --project-ref ofieqhdkvofsjnpxkmee`
2. `npx supabase db push --linked` — all versioned migrations through P0/P1
3. `app_secrets.CHECKIN_SESSION_TOKEN_SECRET` = `staging-dev-secret-16`
4. Storage bucket `check-in-photos` (private) from P1 migration
5. Edge Function:  
   `npx supabase functions deploy send-attendiphi-email --project-ref ofieqhdkvofsjnpxkmee --no-verify-jwt`
6. Demo seed: `scripts/seed_attendiphi_staging.js` (refuses prod host)

Re-apply schema later:

```bash
./scripts/apply_staging_schema.sh
```

Re-seed demo data (needs **test** service_role in env — never commit it):

```bash
export SUPABASE_URL='https://ofieqhdkvofsjnpxkmee.supabase.co'
export SUPABASE_SERVICE_ROLE_KEY='…test service_role only…'
node scripts/seed_attendiphi_staging.js
```

### Demo admin login

| Field | Value |
|---|---|
| Email | `staging.admin@example.com` |
| Password | `AttendiphiStaging1!` (override with `STAGING_ADMIN_PASSWORD`) |
| Role | `superadmin` |

Change this password after first login if the project is shared.

### Demo data included

- Location `location_x` — **Metaphi** at Excel Plaza, Ghatkopar East  
  (`19.083304, 72.913425`). Production Jade is unchanged. To upsert only the  
  pin on attendiphi-test: `scripts/upsert_staging_location_x.sql` (never run on prod).
- 6 fake members (`mem_demo_01` … `06`)
- Check-ins: member + substitute + visitor on **2026-10-15**; visitor on **2026-10-08**
- `session_attendance` rows for those Thursdays

### SMTP / welcome email on staging

Edge Function is **deployed** on test. SMTP secrets are **not** configured by default
(“email not configured on staging”). To enable invites on test, set secrets with
`--project-ref ofieqhdkvofsjnpxkmee` using a non-prod mailbox (see
[smtp-email-setup.md](./smtp-email-setup.md) — swap the project ref).

## CLI safety

- Prefer explicit `--project-ref ofieqhdkvofsjnpxkmee` for staging ops.
- After staging work, re-link prod only when you intend prod deploys:  
  `npx supabase link --project-ref fzghxzybyygslfjyfewu`
- `scripts/seed_attendiphi_staging.js` and `scripts/apply_staging_schema.sh` abort if the target is not attendiphi-test.

## Smoke checklist

- [ ] `./scripts/run_web_staging.sh` → host is `ofieqhdkvofsjnpxkmee`
- [ ] Admin sign-in with `staging.admin@example.com`
- [ ] Members list shows demo roster
- [ ] Daily Attendance for 15 Oct 2026 shows seeded member/substitute
- [ ] Visitors filter for 08 Oct 2026 shows “Demo Visitor Oct8”
- [ ] Check-in RPC `submit_public_check_in` exists (no missing-RPC 500)

## 6. Develop on staging

```bash
git checkout staging
# make changes
flutter test
flutter run -d chrome          # demo DB (default local)
# or: ./scripts/run_web_staging.sh
git add …
git commit -m "…"
git push origin staging
```

## 7. Promote to production only when staging is good

```bash
git checkout main
git pull
git merge staging          # or open a PR: staging → main
git push origin main
```

Then build/deploy production with **live** keys (never staging keys):

```bash
export SUPABASE_URL='https://fzghxzybyygslfjyfewu.supabase.co'
export SUPABASE_ANON_KEY='…live anon…'
export CHECKIN_SESSION_TOKEN_SECRET='…must match live app_secrets…'
./scripts/build_web_release.sh
# hand build/web.zip to devops → attendiphi.metaphi.in
```

See [DEVOPS_WEB_DEPLOY.md](./DEVOPS_WEB_DEPLOY.md).

## 8. Team rules

- Never run migrations against live while “just testing”
- Never commit anon/service keys into git (publishable anon in config is OK;
  **service_role** never)
- Feature work → staging first; `main` only after demo DB verification
- If a migration is needed: apply to **attendiphi-test** first, verify app, then
  apply to live, then merge/deploy
- Same code on both branches; only the Supabase URL/keys change by environment

## Production (unchanged)

Use `lib/main.dart` / `./scripts/build_web_release.sh` with live keys
([DEVOPS_WEB_DEPLOY.md](./DEVOPS_WEB_DEPLOY.md)).
