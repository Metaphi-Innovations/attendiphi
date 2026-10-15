# Attendiphi — three-stage workflow

CEO / team process: **local → staging site → production**. Never skip a stage.

| Stage | Git | Backend | App host | How you run / ship |
|---|---|---|---|---|
| **1. Local** | any feature branch | **Docker Supabase** on your machine | `localhost` (Chrome) | `./scripts/run_web_local.sh` |
| **2. Staging** | `staging` branch | Cloud **attendiphi-test** | **https://attendiphi_staging.metaphi.in** | Push → verify → `./scripts/build_web_staging.sh` → give zip to devops |
| **3. Production** | `main` branch | Cloud **Attendiphi** (live) | **https://attendiphi.metaphi.in** | Merge → `./scripts/build_web_release.sh` → give zip to devops |

```
Local Docker  →  staging branch + staging site  →  main + production site
   (you)              (you + devops)                    (you + devops)
```

---

## Stage 1 — Local (Docker Supabase)

Prerequisites: Docker Desktop running, [Supabase CLI](https://supabase.com/docs/guides/cli).

```bash
# Start local API / DB / Auth / Storage
supabase start

# Apply migrations (first time / after schema changes)
supabase db reset   # or: supabase migration up

# Optional: seed demo data against local (service_role from `supabase status`)
# export SUPABASE_URL=http://127.0.0.1:54321
# export SUPABASE_SERVICE_ROLE_KEY='…from supabase status…'
# node scripts/seed_attendiphi_staging.js   # only if script allows local host

# Run Flutter against local
./scripts/run_web_local.sh
```

- Entrypoint: `lib/main_dev.dart` (`Environment.development`)
- Default API: `http://127.0.0.1:54321`
- Keys: from `supabase status` (or `docs/local.env.example` → `~/.attendiphi/local.env`)
- Set `app_secrets.CHECKIN_SESSION_TOKEN_SECRET` on local DB to match
  `CHECKIN_SESSION_TOKEN_SECRET` used by the script (default `local-dev-secret-16`).

**Do not** use production keys locally.

---

## Stage 2 — Staging (cloud + staging website)

When local looks good:

```bash
git checkout staging
git merge your-feature-branch   # or cherry-pick / PR into staging
flutter test
git push origin staging
```

Optional smoke against cloud test DB without building a zip:

```bash
./scripts/run_web_staging.sh
```

When ready for the **staging website**:

```bash
export CHECKIN_SESSION_TOKEN_SECRET='…'   # must match attendiphi-test app_secrets
export SUPABASE_URL_STAGING='https://ofieqhdkvofsjnpxkmee.supabase.co'
export SUPABASE_ANON_KEY_STAGING='<STAGING_ANON_KEY>'
./scripts/build_web_staging.sh
```

Hand **`build/web-staging.zip`** to devops → deploy to **attendiphi_staging.metaphi.in**  
(same nginx SPA rules as production — see [DEVOPS_WEB_DEPLOY.md](./DEVOPS_WEB_DEPLOY.md)).

**Important:** Do **not** use plain `flutter build web --release` for staging.
That uses `main.dart` release → **production** backend. Always use
`./scripts/build_web_staging.sh` (entrypoint `lib/main_staging.dart`).

---

## Stage 3 — Production (live)

Only after staging site is verified:

```bash
git checkout main
git pull origin main
git merge staging
git push origin main

export CHECKIN_SESSION_TOKEN_SECRET='…'   # must match live app_secrets
export SUPABASE_URL='https://fzghxzybyygslfjyfewu.supabase.co'
export SUPABASE_ANON_KEY='<PRODUCTION_ANON_KEY>'
./scripts/build_web_release.sh
```

Hand **`build/web.zip`** to devops → deploy to **attendiphi.metaphi.in**.

---

## Backend map

| Stage | Supabase | Ref / host |
|---|---|---|
| Local | Docker | `http://127.0.0.1:54321` |
| Staging | Attendiphi-test | `ofieqhdkvofsjnpxkmee` |
| Production | Attendiphi | `fzghxzybyygslfjyfewu` |

Never put **service_role** in Flutter or git.

---

## Entrypoints (Flutter)

| File | Environment | Used by |
|---|---|---|
| `lib/main_dev.dart` | development → local Docker | `run_web_local.sh` |
| `lib/main_staging.dart` | staging → attendiphi-test | `run_web_staging.sh`, `build_web_staging.sh` |
| `lib/main_prod.dart` / release `main.dart` | production | `build_web_release.sh` |
| `lib/main.dart` (debug) | development (local) | bare `flutter run` |

---

## Team rules

1. Feature work: prove on **local Docker** first.
2. Push to **`staging`** only when local is good; verify cloud staging + staging site.
3. Merge to **`main`** only when **attendiphi_staging.metaphi.in** is good.
4. Migrations: apply local → attendiphi-test → production (same order).
5. Staging zip ≠ production zip (different entrypoint + keys + secret).
