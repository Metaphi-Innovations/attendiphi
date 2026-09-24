# Firebase password-reset action handler

Forgot Password no longer uses Firebase `sendPasswordResetEmail`.

Flow:

1. Flutter `/forgot-password` POSTs `{ type: password_reset, email }` to the
   existing Supabase Edge Function `send-attendiphi-email`.
2. The function generates a Firebase Auth password-reset oob link with the
   Identity Toolkit Admin API (`returnOobLink: true`).
3. The hosted `/__/auth/action` URL is rewritten to:

   `https://attendiphi-by-metaphi.web.app/admin-reset-password?mode=resetPassword&oobCode=…&apiKey=…`

4. SMTP delivers the branded email. The button uses that Flutter URL.
5. `AdminForgotPasswordResetScreen` calls `verifyPasswordResetCode` then
   `confirmPasswordReset`. Firebase Auth is the password source of truth.

Required Edge Function secrets (never in Flutter or git):

- `FIREBASE_SERVICE_ACCOUNT_JSON` — Firebase Admin service account JSON for
  `qr-checkin-dev`
- SMTP secrets — see [smtp-email-setup.md](smtp-email-setup.md)

See [smtp-email-setup.md](smtp-email-setup.md).
