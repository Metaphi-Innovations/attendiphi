# Attendiphi email via Gmail SMTP (Supabase Edge Function)

Firebase Auth + Firestore remain the source of truth for admins. Supabase is
used only as an Edge Function that sends mail over **Gmail SMTP** (SSL port
465). Do not put the Gmail App Password in Flutter, Firestore, localStorage,
or git.

Resend is not used.

## Architecture (actual code path)

```
Super Admin (Flutter)
  → Create Admin
      → Firebase Auth user (secondary app attendiphiAdminProvision)
      → Firestore admins/{uid}
  → Send Mail (credentials dialog)
      → Firebase ID token
      → POST Supabase Edge Function send-attendiphi-email
      → Gmail SMTP (smtp.gmail.com:465 TLS)
      → Recipient inbox
```

Admin create stays in Flutter. The Edge Function handles operations requiring
elevated Firebase credentials or private transport:
- Sends email (welcome or password reset) via Gmail SMTP
- Deletes administrators from Firebase Authentication via Google Identity Toolkit
  when a Super Admin deletes an admin profile, preventing orphaned Auth accounts.

## Gmail sender

| Setting | Value |
|---------|--------|
| Host | `smtp.gmail.com` |
| Port | `465` (SSL/TLS) |
| Username | `attendiphi.metaphi@gmail.com` |
| From email | `attendiphi.metaphi@gmail.com` |
| From name | `Attendiphi by Metaphi` |
| Password | **Google App Password** (secret only) |

## Supabase secrets

Set non-password values (safe to run as-is):

```bash
npx supabase secrets set SMTP_HOST="smtp.gmail.com" --project-ref ktnhyohshdwqvvlgeynp
npx supabase secrets set SMTP_PORT="465" --project-ref ktnhyohshdwqvvlgeynp
npx supabase secrets set SMTP_USERNAME="attendiphi.metaphi@gmail.com" --project-ref ktnhyohshdwqvvlgeynp
npx supabase secrets set SMTP_FROM_EMAIL="attendiphi.metaphi@gmail.com" --project-ref ktnhyohshdwqvvlgeynp
npx supabase secrets set SMTP_FROM_NAME="Attendiphi by Metaphi" --project-ref ktnhyohshdwqvvlgeynp
npx supabase secrets set SMTP_SECURE="true" --project-ref ktnhyohshdwqvvlgeynp
```

Set the App Password yourself (do not commit the real value):

```bash
npx supabase secrets set SMTP_PASSWORD="YOUR_GMAIL_APP_PASSWORD" --project-ref ktnhyohshdwqvvlgeynp
```

Password-reset link generation still needs Firebase Admin JSON
(**required for Forgot Password**; welcome/Send Mail only needs SMTP):

```bash
# Download from Firebase Console → Project settings → Service accounts →
# Generate new private key. Keep the file out of git.
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat ./service-account.json)" --project-ref ktnhyohshdwqvvlgeynp
```

If this secret is empty or invalid, Forgot Password returns HTTP **500** before
Gmail SMTP runs (`reason=link_generation detail=missing_service_account`).
Admin **Send Mail** can still succeed because it does not use this secret.

Optional cleanup of obsolete Resend secrets:

```bash
npx supabase secrets unset RESEND_API_KEY --project-ref ktnhyohshdwqvvlgeynp
npx supabase secrets unset ATTENDIPHI_FROM_EMAIL --project-ref ktnhyohshdwqvvlgeynp
```

## Create a Gmail App Password

1. Use the Google account `attendiphi.metaphi@gmail.com`.
2. Turn on [2-Step Verification](https://myaccount.google.com/signinoptions/two-step-verification).
3. Open [App passwords](https://myaccount.google.com/apppasswords).
4. Create an app password (e.g. “Attendiphi SMTP”).
5. Copy the 16-character password into `SMTP_PASSWORD` via the secrets command above.
6. Do **not** use the normal Gmail login password.

## Deploy

```bash
npx supabase functions deploy send-attendiphi-email --project-ref ktnhyohshdwqvvlgeynp --no-verify-jwt
```

Function URL:

```
https://ktnhyohshdwqvvlgeynp.supabase.co/functions/v1/send-attendiphi-email
```

## Implementation

- Library: Deno `denomailer` (compatible with Supabase Edge Functions)
- Code: `supabase/functions/send-attendiphi-email/smtp.ts`
- Entry: `supabase/functions/send-attendiphi-email/index.ts`
- Flutter never sees SMTP secrets; it only POSTs with a Firebase ID token
  (welcome) or anon key (password reset)

## Failure cases

| Case | Result |
|------|--------|
| Missing SMTP secrets | `500`, `emailSent: false` |
| Bad App Password | `502`, auth failed message |
| Gmail unreachable / timeout | `502` |
| Invalid recipient | `400` |
| Duplicate admin | Blocked in Flutter before mail |
| Create OK, SMTP fail | Admin kept; dialog shows error |

## Test

1. Set secrets (including `SMTP_PASSWORD`) and deploy.
2. Super Admin → Create Admin → confirm Auth + Firestore.
3. Click **Send Mail** → inbox from `attendiphi.metaphi@gmail.com`.
4. Wrong App Password → clear failure; admin still listed.
5. Forgot Password → same Gmail SMTP path.
