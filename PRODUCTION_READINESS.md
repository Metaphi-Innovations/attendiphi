# Attendiphi production readiness

**Date:** 22 Sep 2026  
**Verdict:** **Not production-ready.** Live Hosting may already serve the app; that is not the same as a secure production posture.

This file is a scorecard. Evidence: `SECURITY_AUDIT.md`, `DEAD_CODE_AUDIT.md`, and the current source tree. No application code was modified for these reports.

---

## Category scorecard

| Category | Level | Blocker? |
| --- | --- | --- |
| Unauthenticated admin UI (`/admins` and shell) | CRITICAL | YES |
| Default Super Admin in `AdminAuthNotifier.build()` | CRITICAL | YES |
| Firestore `admins` / `checkIns` mutate / devices / employee biometrics | CRITICAL | YES |
| Super Admin password in web bundle | CRITICAL | YES |
| Admin vs Super Admin in rules | HIGH | YES |
| Any Auth user writes members/locations | HIGH | YES |
| Check-in GPS/day/face/duplicates | HIGH | YES (integrity) |
| Password hashing (SHA-256 + public hashes) | HIGH | YES if `admins` stay public |
| Storage rules file missing | HIGH | YES if Storage is on |
| Welcome email contains password | HIGH | Product; rotate after send |
| Unauthenticated reset mail relay | MEDIUM | No if rate-limit + generic copy hold |
| Input validation (login/admin phone) | MEDIUM | No |
| App Check absent on web | MEDIUM | No after rules lock |
| XSS via Flutter Text | LOW | No |
| Public Firebase / Supabase publishable keys | INFO | Expected |
| SPA Hosting rewrite | INFO | Correct |
| Legacy `functions/` in repo | MEDIUM | Confirm Console |
| Unused `pdf` / `integration_test` | INFO | Cleanup later |
| Tests vs rules | HIGH | No emulator rules tests |
| CI | MEDIUM | No `.github` workflows |

---

## Must fix before production

1. **Stop authenticating strangers as Super Admin** (`admin_auth_provider.dart` `build()`).
2. **Lock Firestore:** `admins`, `checkIns` read/update/delete, `admin_devices`, `admin_notifications`, employee biometric fields, member writes limited to real admins—not `if true` / not merely `auth != null`.
3. **Remove Super Admin / `Admin@1234` secrets from the client** and rotate them. Rebuild and redeploy web so the old JS bundle is gone.
4. **Add GoRouter auth redirect** for admin shell routes (`/admins`, `/daily-attendance`, `/members`, `/visitors`, `/qr-standee`, `/attendance-overview`). Public: login, forgot, oob reset, QR check-in.
5. **Confirm Firebase Console:** no Cloud Functions still serving SMTP/face HTTP; add Storage rules if Storage exists; keep Hosting SPA rewrite.
6. **Do not treat Flutter hiding as authorization.** Rules must independently deny.

Do **not** add Cloud Functions or Blaze to fix email. Use Firestore rules + existing Supabase SMTP Edge Function + Firebase Auth.

---

## Safe to clean after security fixes

- `functions/` tree (after Console confirms nothing is deployed)
- `fcm_server.js`
- `docs/gmail-api-welcome-email.md`
- Unused pubspec: `pdf`, `integration_test`
- `face-recognition-service/` if product confirms it is not hosted
- Gradle `android/build/reports/`
- Dead `superAdminAutoLogin()` once Super Admin is redesigned

---

## Do not remove / required

- Flutter `lib/` routed features
- `web/index.html`, face-api, `face_verifier.js`, ONNX runtime for web matching
- `supabase/functions/send-attendiphi-email` (welcome + password reset)
- `firestore.rules` / indexes (fix in place)
- `firebase.json` Hosting headers + `**` → `/index.html`
- Logo and native `mobilefacenet.tflite` for IO
- `test/` suite

---

## Configuration (current)

| Item | State |
| --- | --- |
| `main()` environment | `EnvironmentConfig.production` |
| Hosting targets | `attendiphi` → `attendiphi-by-metaphi`; `dev` → `qr-checkin-dev` |
| Functions in `firebase.json` | **None** (correct for Spark intent) |
| Source maps | Hosting serves `build/web`; Dart source maps depend on build flags (not forced off in `firebase.json`) |
| CORS Edge Function | production origins + localhost, not `*` |
| Password reset landing | `/admin-reset-password` (Flutter), not `/__/auth/action` in the Resend button path |

---

## Tests

**Present:** widget/unit tests for forgot/reset UX, email HTTP payload, validators, QR, some admin UI, face math.

**Missing:** Firestore emulator rule tests; router redirect tests; test that default auth is logged out; no CI.

`flutter analyze` / `flutter test` should be run in CI after blockers are fixed. This audit did not change code and did not deploy.

---

## Recommended remediation order

See `SECURITY_AUDIT.md` section 26. Security and rules first; dead-code deletion last.
