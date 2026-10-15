# Phase P2 — Quality / ops polish

No new Postgres migration required for P2 (welcome invite is Edge-only).

## Deploy

```bash
# 1) Redeploy Edge (invite link welcome mail; no plaintext passwords)
supabase functions deploy send-attendiphi-email --project-ref fzghxzybyygslfjyfewu

# 2) Web release (fails in CI without CHECKIN_SESSION_TOKEN_SECRET ≥16)
export CHECKIN_SESSION_TOKEN_SECRET='…'   # ≥16; match app_secrets
export SUPABASE_URL='https://fzghxzybyygslfjyfewu.supabase.co'
export SUPABASE_ANON_KEY='…'              # publishable anon
./scripts/build_web_release.sh
```

## Client entrypoints

| Entry | Env | Notes |
|-------|-----|--------|
| `lib/main_dev.dart` | development | Warns if using prod Supabase host |
| `lib/main_staging.dart` | staging | Prefer `SUPABASE_URL_STAGING` / `SUPABASE_ANON_KEY_STAGING` |
| `lib/main_prod.dart` / `main.dart` | production | Use release dart-defines from build script |

## Acceptance

- Android launcher label shows **Attendiphi**
- Welcome email has “Set your password” link, no `Password:` line
- Release web: `index.html` meta URL/key match `--dart-define` values
- Legacy liveness never blocks check-in
