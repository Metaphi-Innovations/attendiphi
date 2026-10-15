# Devops: deploy Attendiphi web

Full engineer flow: [ENVIRONMENTS.md](./ENVIRONMENTS.md)  
(**local Docker → staging site → production**).

## Hosts

| Site | Zip from | Backend |
|---|---|---|
| **https://attendiphi_staging.metaphi.in** | `./scripts/build_web_staging.sh` → `build/web-staging.zip` | attendiphi-test |
| **https://attendiphi.metaphi.in** | `./scripts/build_web_release.sh` → `build/web.zip` | production Attendiphi |

Do **not** deploy Firebase Hosting. Unpack zip so `index.html` is site root.

## Staging build artifact

```bash
export CHECKIN_SESSION_TOKEN_SECRET='…'   # ≥16; MUST match attendiphi-test app_secrets
export SUPABASE_URL_STAGING='https://ofieqhdkvofsjnpxkmee.supabase.co'
export SUPABASE_ANON_KEY_STAGING='…'      # publishable anon only
./scripts/build_web_staging.sh
# → hand build/web-staging.zip to devops → attendiphi_staging.metaphi.in
```

## Production build artifact

```bash
export CHECKIN_SESSION_TOKEN_SECRET='…'   # ≥16 chars; MUST match live app_secrets
export SUPABASE_URL='https://fzghxzybyygslfjyfewu.supabase.co'
export SUPABASE_ANON_KEY='…'              # publishable anon only
./scripts/build_web_release.sh
# → hand build/web.zip to devops → attendiphi.metaphi.in
```

In **CI**, the production script fails closed if `CHECKIN_SESSION_TOKEN_SECRET` is missing
or shorter than 16 characters (no auto-generate).

Both builds rewrite `web/index.html` supabase meta tags from the same
values passed as `--dart-define` (no drift).

### Pre-deploy checklist (P0–P2)

- [ ] SQL: `20261015110000_p0_…` + `20261015120000_p1_…` applied
- [ ] `app_secrets.CHECKIN_SESSION_TOKEN_SECRET` matches web build secret (≥16)
- [ ] Edge: `send-attendiphi-email` redeployed (invite-link welcome; rate limits)
- [ ] Storage bucket `check-in-photos` exists
- [ ] Opaque standee QR only (legacy `/checkin/<locationId>?date=` rejected in release)
- [ ] Welcome email: “Set your password” link, no plaintext password
- [ ] Optional: `SENTRY_DSN` dart-define when crash reporting is approved
- [ ] Staging: `lib/main_staging.dart` + attendiphi-test (see [STAGING.md](./STAGING.md) / `./scripts/run_web_staging.sh`)

## Nginx (SPA)

Unpack so `index.html` is the site root, then:

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

Required so deep links work:

- `/daily-attendance`
- `/checkin/<token>`
- `/admin-reset-password`

## Backend

Client talks only to Supabase project **`fzghxzybyygslfjyfewu`**
(`attendiphi.metaphi@gmail.com`). No Firebase project is required for the client.

## Email Edge Function (welcome / delete admin)

Deploy on the **same** Attendiphi project (`fzghxzybyygslfjyfewu`):

```bash
npx supabase functions deploy send-attendiphi-email \
  --project-ref fzghxzybyygslfjyfewu --no-verify-jwt
```

Set SMTP secrets on that project (see `docs/smtp-email-setup.md`).
Service role / URL are auto-injected; no Firebase and no separate email project.

Welcome emails send a **recovery / set-password link** only (P2). Temporary Auth
passwords are generated server-side and never included in the message body.

## Admin Auth users

Admins must exist in **Supabase Auth**. Prefer the welcome invite link, or use
`scripts/provision_supabase_admin_auth.js` with `SUPABASE_SERVICE_ROLE_KEY`.
