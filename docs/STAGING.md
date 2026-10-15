# Attendiphi staging (attendiphi-test)

**Three-stage workflow (source of truth):** [ENVIRONMENTS.md](./ENVIRONMENTS.md)

1. **Local** — Docker Supabase + `./scripts/run_web_local.sh`
2. **Staging** — `staging` branch + cloud test + site **attendiphi_staging.metaphi.in**
3. **Production** — `main` + **attendiphi.metaphi.in**

## Staging vs production (cloud)

| | Staging | Production |
|---|---|---|
| **Entrypoint** | `lib/main_staging.dart` / `build_web_staging.sh` | `main.dart` release / `build_web_release.sh` |
| **Supabase project** | **Attendiphi-test** (`ofieqhdkvofsjnpxkmee`) | **Attendiphi** (`fzghxzybyygslfjyfewu`) |
| **Website** | `attendiphi_staging.metaphi.in` | `attendiphi.metaphi.in` |
| **Region** | `ap-northeast-2` | `ap-northeast-1` |
| **Data** | Demo / safe to break | Real members & check-ins |
| **Git** | `staging` branch | `main` |
| **Keys** | `SUPABASE_URL_STAGING` / `SUPABASE_ANON_KEY_STAGING` | `SUPABASE_URL` / `SUPABASE_ANON_KEY` |

Never put **service_role** keys in the Flutter app or git.

## Stage 1 — Local Docker (before staging)

```bash
supabase start
supabase db reset   # apply migrations
./scripts/run_web_local.sh
```

See [ENVIRONMENTS.md](./ENVIRONMENTS.md) and `docs/local.env.example`.

## Stage 2 — Cloud staging (attendiphi-test)

Smoke against cloud test DB (no zip):

```bash
./scripts/run_web_staging.sh
```

Smoke-check: Network / logs should show host `ofieqhdkvofsjnpxkmee.supabase.co`,
not `fzghxzybyygslfjyfewu.supabase.co`.

Staging **website** zip for devops:

```bash
./scripts/build_web_staging.sh
# → build/web-staging.zip → attendiphi_staging.metaphi.in
```

**Live production** only after staging site is good: merge to `main` and
`./scripts/build_web_release.sh` → `attendiphi.metaphi.in`.  
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

- Location `location_x` (Jade)
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

## 6. Develop (local → staging branch)

```bash
# Stage 1 — prove on Docker
supabase start && supabase db reset
./scripts/run_web_local.sh

# Stage 2 — push to staging branch + optional cloud smoke
git checkout staging
flutter test
./scripts/run_web_staging.sh    # cloud attendiphi-test
git add …
git commit -m "…"
git push origin staging

# Staging website for devops
./scripts/build_web_staging.sh
# hand build/web-staging.zip → attendiphi_staging.metaphi.in
```

## 7. Promote to production only when staging *site* is good

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

See [ENVIRONMENTS.md](./ENVIRONMENTS.md) and [DEVOPS_WEB_DEPLOY.md](./DEVOPS_WEB_DEPLOY.md).

## 8. Team rules

- Never run migrations against live while “just testing”
- Never commit anon/service keys into git (publishable anon in config is OK;
  **service_role** never)
- Feature work → **local Docker** first → `staging` branch + staging site → then `main`
- Migrations: local → **attendiphi-test** → live (same order)
- Same code on branches; only the Supabase URL/keys (and build script) change by stage
- Never use plain `flutter build web --release` for the staging site — use
  `./scripts/build_web_staging.sh`

## Production (unchanged)

Use `lib/main.dart` / `./scripts/build_web_release.sh` with live keys
([DEVOPS_WEB_DEPLOY.md](./DEVOPS_WEB_DEPLOY.md)).
