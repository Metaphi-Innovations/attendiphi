# Devops: deploy Attendiphi web to `attendiphi.metaphi.in`

## Build artifact

From the repo (developer machine):

```bash
export CHECKIN_SESSION_TOKEN_SECRET='…'   # ≥16 chars; MUST match app_secrets
export SUPABASE_URL='https://fzghxzybyygslfjyfewu.supabase.co'
export SUPABASE_ANON_KEY='…'              # publishable anon only
./scripts/build_web_release.sh
```

In **CI**, the script fails closed if `CHECKIN_SESSION_TOKEN_SECRET` is missing
or shorter than 16 characters (no auto-generate).

Produces:

- `build/web/` — Flutter web release
- `build/web.zip` — zip of `build/web` for transfer

The build rewrites `web/index.html` supabase meta tags from the same
`SUPABASE_URL` / `SUPABASE_ANON_KEY` passed as `--dart-define` (no drift).

Hand **`build/web.zip`** to devops. Do **not** deploy Firebase Hosting.

### Pre-deploy checklist (P0–P2)

- [ ] SQL: `20261015110000_p0_…` + `20261015120000_p1_…` applied
- [ ] `app_secrets.CHECKIN_SESSION_TOKEN_SECRET` matches web build secret (≥16)
- [ ] Edge: `send-attendiphi-email` redeployed (invite-link welcome; rate limits)
- [ ] Storage bucket `check-in-photos` exists
- [ ] Opaque standee QR only (legacy `/checkin/<locationId>?date=` rejected in release)
- [ ] Welcome email: “Set your password” link, no plaintext password
- [ ] Optional: `SENTRY_DSN` dart-define when crash reporting is approved
- [ ] Staging builds prefer `main_staging.dart` + `SUPABASE_URL_STAGING` when available

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
