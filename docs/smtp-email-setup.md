# Attendiphi email via Gmail SMTP (Supabase Edge Function)

**One Supabase project:** `fzghxzybyygslfjyfewu` (Attendiphi — data, Auth, and
Edge Functions). Firebase is not used.

Mail is sent by Edge Function `send-attendiphi-email` over **Gmail SMTP**
(SSL port 465). Do not put the Gmail App Password in Flutter, localStorage, or git.

## Architecture

```
Super Admin (Flutter)
  → Create Admin → public.admins
  → Send Mail
      → Supabase Auth access token
      → POST /functions/v1/send-attendiphi-email  (same project)
      → Gmail SMTP → recipient inbox

Forgot Password (Flutter)
  → POST /functions/v1/send-attendiphi-email  (anon key, no user JWT)
      → Auth Admin generate_link (recovery)
      → Gmail SMTP with Reset Password button
      → Link lands on /admin-reset-password
```

## Gmail sender

| Setting | Value |
|---------|--------|
| Host | `smtp.gmail.com` |
| Port | `465` (SSL/TLS) |
| Username | `attendiphi.metaphi@gmail.com` |
| From | `attendiphi.metaphi@gmail.com` |
| Password | **Google App Password** (secret only) |

## Secrets (Attendiphi project)

```bash
npx supabase secrets set SMTP_HOST="smtp.gmail.com" --project-ref fzghxzybyygslfjyfewu
npx supabase secrets set SMTP_PORT="465" --project-ref fzghxzybyygslfjyfewu
npx supabase secrets set SMTP_USERNAME="attendiphi.metaphi@gmail.com" --project-ref fzghxzybyygslfjyfewu
npx supabase secrets set SMTP_FROM_EMAIL="attendiphi.metaphi@gmail.com" --project-ref fzghxzybyygslfjyfewu
npx supabase secrets set SMTP_FROM_NAME="Attendiphi by Metaphi" --project-ref fzghxzybyygslfjyfewu
npx supabase secrets set SMTP_SECURE="true" --project-ref fzghxzybyygslfjyfewu
npx supabase secrets set SMTP_PASSWORD="YOUR_GMAIL_APP_PASSWORD" --project-ref fzghxzybyygslfjyfewu
```

`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are injected automatically when the
function runs on this project — no `ATTENDIPHI_DATA_*` bridge needed.

## Deploy

Log in with the Metaphi account that owns project **Attendiphi**, then:

```bash
npx supabase login
npx supabase functions deploy send-attendiphi-email --project-ref fzghxzybyygslfjyfewu --no-verify-jwt
```

Function URL:

```
https://fzghxzybyygslfjyfewu.supabase.co/functions/v1/send-attendiphi-email
```

After deploy, Edge Functions in the dashboard should list `send-attendiphi-email`.

## Test

1. Set SMTP secrets and deploy.
2. Super Admin → Create Admin → **Send Mail**.
3. Inbox from `attendiphi.metaphi@gmail.com`.
