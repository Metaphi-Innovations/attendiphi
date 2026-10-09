# Attendiphi security audit

**Scope:** repository as of **9 Oct 2026** (post remediation pass: AUD-OPS-001, AUD-SEC-005/006/008, AUD-DOC-001).  
**Mode:** living document. Client APIs and rules change; re-verify before each production deploy.  
**Live hosts:** `https://attendiphi.metaphi.in`, Firebase Hosting targets `attendiphi` / `dev`.  
**Firebase project in source:** `qr-checkin-dev` (confirm Console project for each environment).

This document replaces the 22 Sep 2026 audit, which incorrectly described auto Super Admin login, open Firestore rules, and missing router guards.

---

## 1. Executive summary

**Admin portal auth** uses Firebase Auth + Firestore `admins/{uid}` hydration, GoRouter `AuthRedirect`, and hardened `firestore.rules` for admin collections.

**Public QR check-in** remains intentionally unauthenticated. Integrity depends on:

- HMAC-signed opaque session tokens (`CHECKIN_SESSION_TOKEN_SECRET` in **release** builds)
- Session lock documents (device / phone / member)
- Client-enforced GPS, Thursday/session-date, and optional face checks
- Field allowlists and size caps on `checkIns` create

**Current readiness status:** **READY FOR REVIEW** (not PRODUCTION READY). Repo controls are in place and locally/CI-oriented checks are documented below; live backfill, rules/Hosting deploy, and production smoke tests remain unauthorized/unexecuted.

---

## 2. Controls that are in place (verified in source)

| Control | Evidence |
| --- | --- |
| No cold-start Super Admin | `AdminAuthNotifier.build()` starts unauthenticated; hydrates from `FirebaseAuth.currentUser` + `getAdminById` |
| Admin route guard (UX) | `lib/app/router/auth_redirect.dart` + `app_router.dart` `redirect` / `refreshListenable` |
| Admin login | `signInWithEmailAndPassword` then Firestore profile; inactive admins signed out |
| Hardcoded admin passwords | Guarded by `test/unit/security/no_hardcoded_admin_secrets_test.dart`; no `Admin@1234` / `SuperAdmin@2026` in `lib/` / `web/` |
| Firestore `admins` | Signed-in Attendiphi admin scopes; Super Admin vs regular admin |
| `checkIns` RUD | Attendiphi admins only; public **create** with allowlist |
| `faceTemplates` | Admin-only |
| `employees` create | Blocks shipping biometric fields on create |
| Storage | `storage.rules` deny-all; wired in `firebase.json` (AUD-SEC-005) |
| Check-in URL tokens | HMAC v1 tokens; release requires dart-define (AUD-OPS-001) |
| Password match helper | Salted SHA-256 only; no plaintext equality (AUD-SEC-006) |
| Provisioning logs | Emails redacted via `AdminAuthEmailClient.redactEmail` (AUD-SEC-008) |

**Reminder:** Flutter hiding UI is not authorization. Firestore/Storage rules are the control plane.

---

## 3. Remaining risks (current)

### SEC-A — Public member directory (AUD-SEC-002)

| | |
| --- | --- |
| **Severity** | High until rules + backfill deployed; Medium residual after (active name/phone still public) |
| **Mitigation in repo** | `employees` admin-only; `publicMembers` **active-only presence** (deactivate/delete removes projection); rules require `isActive==true` for read; client queries match; Admin SDK backfill upserts actives / deletes inactive+orphans |
| **Alternate writer** | `scripts/upload_members_from_ods.js` writes `employees` only — must follow with backfill |
| **Deploy order** | Verify live rules → dry-run → **backfill + verify `publicMembers`** → Hosting (new filtered client) → deploy restrictive `firestore.rules` (see `PRODUCTION_READINESS.md`). Hosting-before-data causes empty typeahead; rules-before-new-client breaks old unfiltered queries. Both Hosting sites share project `qr-checkin-dev` in `.firebaserc`. |
| **Residual** | Active members' name/phone remain anonymously listable via filtered query |

### SEC-B — Unauthenticated `checkIns` create

| | |
| --- | --- |
| **Severity** | Medium–High (spam / abuse) |
| **Why** | Public QR flow |
| **Mitigation today** | Field allowlist, size caps, session locks |
| **Follow-up** | App Check web, abuse monitoring |

### SEC-C — GPS / Thursday / face not fully rule-enforced

| | |
| --- | --- |
| **Severity** | Medium (integrity) |
| **Why** | Rules document client + lock helpers |
| **Follow-up** | Stronger server-side attestation if required |

### SEC-D — App Check mobile-only

| | |
| --- | --- |
| **Severity** | Medium |
| **File** | `lib/app/config/firebase_config.dart` |
| **Follow-up** | Web App Check / reCAPTCHA Enterprise if abuse grows |

### SEC-E — Legacy `functions/` / `fcm_server.js` in repo

| | |
| --- | --- |
| **Severity** | Medium if still deployed |
| **Action** | Confirm Firebase Console; archive after confirmation (AUD-DEAD-* not approved in this pass) |

### SEC-F — Check-in token secret ops

| | |
| --- | --- |
| **Severity** | Critical if release ships without define (or with a short/weak define) |
| **Mitigation** | `scripts/build_web_release.sh` (≥16 chars) + release `StateError` in `CheckInSessionToken.signingSecret` for empty or short secrets |
| **Ops** | Store the define value in CI secrets for build injection; regenerate standees after rotation |

**Client extractability (AUD-DOC-002):** On Flutter Web, `--dart-define=CHECKIN_SESSION_TOKEN_SECRET=…` is embedded in the shipped JavaScript. It is **not** a confidential server-side secret. HMAC signing still prevents casual forgery of `/checkin/<token>` URLs relative to the public bootstrap secret used in debug builds, but a determined client can recover the define from the bundle. Do not describe this value as private. Future server-issued tokens would be a separate architectural change.

#### Limitations of the client-embedded HMAC key (current design)

| Limitation | Detail |
| --- | --- |
| Not confidential on Web | Anyone who downloads the JS/WASM bundle can extract the dart-define value (strings, source maps, or debugger). |
| Shared across all standees | One build-time secret signs every venue QR; compromise forges tokens for all locations using that build. |
| No per-session revocation | Valid until TTL/`sessionDate` rules in the client token format; server cannot invalidate a single leaked URL without rotating the global secret and reprinting QR codes. |
| Client-enforced claims | Location binding and expiry are only as strong as the extracted key + client parsers; Firestore rules do **not** verify the HMAC. |
| Rotation cost | Changing the secret invalidates outstanding printed QR URLs until they are regenerated and redeployed. |

Preserve QR URL compatibility until a separate migration is approved. Do **not** redesign session security in-app without that approval.

#### Minimum requirements for server-issued tokens (future; not implemented)

**Smallest safe design:** a Cloud Function (or callable) mints short-lived signed tokens using a server-only secret; the Flutter/Web client never receives the signing key. Check-in submission (or lock create) verifies the token server-side before accepting writes. Client-only HMAC validation is not enough once a key is in the Web bundle.

1. **Minting:** Only a trusted backend (Cloud Function / callable / Admin SDK) creates tokens; the signing key never ships in the Flutter/Web client.
2. **Claims:** Token must bind at least `locationId`, `sessionDate` (or absolute `exp`), and a unique `jti` (or nonce) for replay control.
3. **Verification:** Check-in create path must verify signature server-side (Function or App Check + callable) before accepting locks/submissions; client-only HMAC checks are insufficient once the key is public.
4. **Revocation:** Support deny-list or short TTL + rotation without requiring every historical URL to share one eternal secret.
5. **Migration / QR compatibility:** Printed standee URLs today embed client-HMAC path tokens. A cutover needs dual-accept (old HMAC + new server tokens) for a defined window, then reprint/redeploy QR codes. Until that migration is approved, preserve current URL shape and do not change token architecture in-app.

---

## 4. Authentication model (current)

1. User submits email/password on `/` (`AdminLoginScreen`).
2. Firebase Auth validates credentials.
3. App loads `admins/{uid}`; must exist and `isActive != false`.
4. GoRouter allows admin shell paths only when `isAuthenticated`.
5. Password reset uses Firebase oob + Flutter `/admin-reset-password` + Supabase email Edge Function.
6. `AdminUser.matchesPassword` is **not** used for portal login (Firebase Auth is source of truth). It only verifies salted `passwordHash` for metadata/tests.

---

## 5. Data classification (client)

| Data | Storage | Notes |
| --- | --- | --- |
| Admin credentials | Firebase Auth | Never ship plaintext passwords in Firestore (`toMap` omits `plainPassword`) |
| Member name/phone | `publicMembers` public read | **Active only** (doc presence); inactive omitted/deleted; full profile on admin-only `employees` |
| Face templates | `faceTemplates` admin-only | Prefer over embedding on `employees` |
| Substitute photo | `checkIns.photoBase64` | Size-capped; not Firebase Storage |
| Session tokens | URL path | HMAC; dart-define in release (≥16 chars). **Web bundle is extractable** — not a server secret |

---

## 6. Firebase Storage

- Package `firebase_storage` is **not** a Flutter dependency.
- Photos use Firestore `photoBase64`.
- `storage.rules` denies all reads/writes so enabling Storage in Console does not open a public bucket.
- Deploy: `firebase deploy --only storage` when Storage is enabled on the project.

---

## 7. Logging policy

- Prefer `AppLogger` (no sensitive phone/photo/token dumps).
- Admin Auth provisioning logs use redacted emails (`j***@domain`).
- Do not log primary Auth UIDs tied to Super Admin spillover beyond generic warnings.

---

## 8. External verification checklist

- [ ] Deployed `firestore.rules` match repo (incl. `substitutePhone`).
- [ ] `storage.rules` deployed if Storage enabled.
- [ ] Production Hosting build used `CHECKIN_SESSION_TOKEN_SECRET`.
- [ ] No legacy Cloud Functions still privileged on the project.
- [ ] Supabase Edge Function CORS and secrets scoped correctly.
- [ ] Old web bundles without token secret / with historical admin secrets are replaced.

---

## 9. Related docs

- `PRODUCTION_READINESS.md` — scorecard, deploy sequence, rollback
- `DEAD_CODE_AUDIT.md` — leftover inventory
- `README.md` — production build with dart-define

---

## 10. Final verification (9 Oct 2026 pass)

### Project / hosting (from config — not guessed)

| Source | Value |
| --- | --- |
| `.firebaserc` default | `qr-checkin-dev` |
| Hosting target `attendiphi` | site `attendiphi-by-metaphi` |
| Hosting target `dev` | site `qr-checkin-dev` |
| `DefaultFirebaseOptions` projectId | `qr-checkin-dev` |

### Atomic writers (repo search)

| Path | Writes `employees` / `publicMembers`? |
| --- | --- |
| `EmployeeRemoteDataSourceImpl` | **Yes** — batched create/update/toggle/delete (+ faceTemplates on delete) |
| `scripts/upload_members_from_ods.js` | `employees` only — **gap**; documented; run backfill after |
| `functions/index.js` | Reads `employees` only (no publicMembers writer found) |
| Admin UI | Uses repository → remote data source only |

### HMAC / session token

- Release requires `CHECKIN_SESSION_TOKEN_SECRET` (≥16); `kReleaseMode` throws if missing.
- `scripts/build_web_release.sh` refuses empty/short secrets; does not print the secret value.
- Bootstrap secret used only for debug/profile without define — **not** for release.
- **Web limitation:** dart-define is extractable from the JS bundle; not a confidential server boundary. Server-issued tokens remain a separate approved migration (`§3 SEC-F`).

### Checks executed in this pass

| Check | Result |
| --- | --- |
| `dart format` (touched files this pass) | Pass |
| `node --test` backfill + ODS sync helpers | **12 pass** (mock; no live Firestore) |
| `cd test/rules && npm test` with session `JAVA_HOME`=Homebrew OpenJDK **25** | **Pass** (`RULES_EXIT=0`, emulator cleaned up) |
| `flutter analyze` | No issues |
| Focused projection/lookup/token/check-in form | **41 pass** |
| `flutter test` | **332 pass** |
| Ephemeral `./scripts/build_web_release.sh` | **Pass** (secret not logged) |
| Live backfill dry-run vs Firebase | **Not run** (requires authorization) |
| GitHub Actions CI | Workflow ready; not executed (no push) |

Live Firebase mutations were **not** performed.

### Authorization still required

1. Live `backfill_public_members.js` against the approved project  
2. `firebase deploy --only firestore:rules` (and storage if needed)  
3. Production `CHECKIN_SESSION_TOKEN_SECRET` injection + Hosting deploy  
4. Post-deploy smoke tests  
