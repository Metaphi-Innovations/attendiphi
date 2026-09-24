# Attendiphi security audit

**Scope:** current repository as inspected on 22 Sep 2026.  
**Mode:** read-only. No application code was changed for this audit.  
**Live hosts in docs:** `https://attendiphi-by-metaphi.web.app`, `https://attendiphi.metaphi.in`.  
**Firebase project in source:** `qr-checkin-dev`.

This document is evidence-based. A control is called secure only if the implementation was inspected.

---

## 1. Executive summary

The Flutter web shell loading on any Hosting URL is expected (`firebase.json` SPA rewrite). **Showing Admin UI and Admin data to a logged-out visitor is not.**

The current tree still has all of the following at once:

1. `AdminAuthNotifier.build()` starts every visitor as **authenticated Super Admin**.
2. GoRouter has **no login redirect**. `/admins` and every other admin shell route are reachable by URL.
3. Firestore `admins`, `checkIns` (read/update/delete), `admin_devices`, and `admin_notifications` are **`allow … if true`**.
4. Super Admin email/password (and a second password alias) are **hardcoded in the web bundle**.
5. Member **face embeddings** live on publicly readable `employees` documents.
6. Check-in day, GPS, face match, and duplicate rules are **Flutter-only**. Firestore create on `checkIns` only checks three string types.

**The application is not production-ready** until the critical findings below are fixed. Client route guards are UX only. Firestore/Storage rules are the real control plane. There is **no `storage.rules` file** in the repo.

Firebase Cloud Functions in `functions/` are **not** listed in `firebase.json`. They are leftover source. If they are still deployed on `qr-checkin-dev`, they are out of the intended Spark architecture and should be confirmed in Firebase Console (this audit cannot see live GCP).

---

## 2. CRITICAL findings

### SEC-001 — Cold start authenticates every visitor as Super Admin

| | |
| --- | --- |
| **Severity** | CRITICAL |
| **File** | `lib/features/admin/presentation/providers/admin_auth_provider.dart` |
| **Area** | `AdminAuthNotifier.build()` lines 130–137 |
| **Problem** | `isAuthenticated: true` and `currentAdmin: SuperAdminConfig.user` on every app start. `FirebaseAuth.currentUser` is stored and unused for authorization. No `authStateChanges` listener. |
| **Why it matters** | Deep links skip login. `visibleAdminsProvider` treats the visitor as Super Admin and returns **all** admin documents. `AdminShellLayout` labels the user Super Admin. |
| **Attack** | Open `https://attendiphi-by-metaphi.web.app/admins` while logged out. |
| **Fix** | `build()` must start `isAuthenticated: false`, `currentAdmin: null`. Restore session only from a verified login (Firestore admin +/or Firebase Auth), never from a hardcoded Super Admin object. |
| **Production blocker** | YES |

### SEC-002 — No GoRouter auth guard on admin routes

| | |
| --- | --- |
| **Severity** | CRITICAL |
| **File** | `lib/app/router/app_router.dart` |
| **Area** | `redirect` lines 87–89; StatefulShell branches for `/daily-attendance`, `/attendance-overview`, `/visitors`, `/members`, `/qr-standee`, `/admins` |
| **Problem** | The only redirect is Firebase `mode=resetPassword` + `oobCode` → `/admin-reset-password`. No `refreshListenable`, no `isAuthenticated` check. `AdminShellLayout` does not gate on login. |
| **Why it matters** | Hiding nav buttons is not a control. Direct URLs load protected screens. |
| **Attack** | `GET /admins`, `/members`, `/visitors`, `/daily-attendance` in a logged-out browser. |
| **Fix** | Public allowlist: `/`, `/forgot-password`, `/admin-reset-password` (with oob), check-in routes. All admin shell paths redirect to `/` unless authenticated. Treat this as UX; still lock Firestore. |
| **Production blocker** | YES |

### SEC-003 — Firestore `admins` world-readable and world-writable

| | |
| --- | --- |
| **Severity** | CRITICAL |
| **File** | `firestore.rules` |
| **Area** | lines 19–22 `match /admins/{adminId} { allow read, write: if true; }` |
| **Problem** | Comment says “Protected at app level”. That is false. Any browser with the Firebase web config can list, create, update, delete admins, including `passwordHash` / `passwordSalt` / leftover `plainPassword`. |
| **Attack** | Firestore REST/`get()` the collection; overwrite `role` / `isActive`; insert a Super Admin; delete all admins. |
| **Fix** | Deny unauthenticated access. Restrict writes. Super Admin vs Admin must be encoded with `request.auth` (email/uid), not Flutter. Disallow client changes to `role` except Super Admin. |
| **Production blocker** | YES |

### SEC-004 — Super Admin password in the client bundle

| | |
| --- | --- |
| **Severity** | CRITICAL |
| **File** | `lib/features/admin/presentation/providers/admin_auth_provider.dart` |
| **Area** | `SuperAdminConfig` lines 17–20; `signIn` lines 148–152 |
| **Problem** | `email = superadmin@metaphi.com`, `password = SuperAdmin@2026`. Login also accepts username `superadmin` / `admin@qrcheckin.com` and password `Admin@1234`. `superAdminAutoLogin()` exists (currently unreferenced from UI). |
| **Attack** | Download `main.dart.js` / search the bundle. Log in as Super Admin from anywhere. Combined with SEC-001, the UI already assumes this identity. |
| **Fix** | Remove secrets from source. Super Admin must be a Firebase Auth user (or equivalent) with a password that is not in git. Delete `Admin@1234` alias. |
| **Production blocker** | YES |

### SEC-005 — Attendance records publicly readable, updatable, deletable

| | |
| --- | --- |
| **Severity** | CRITICAL |
| **File** | `firestore.rules` |
| **Area** | `checkIns` lines 12–17 |
| **Problem** | `create` only requires `userName`, `userPhone`, `locationId` strings. `allow read, update, delete: if true`. |
| **Attack** | Dump all attendance (names, phones, emails, GPS, `photoBase64`). Forge check-ins. Flip `faceVerified`. Delete history. Bypass Thursday/GPS/duplicate/face because those checks are not in rules. |
| **Fix** | Keep anonymous **create** if QR check-in must stay public, but constrain fields (no client `faceVerified`, size limits, no arbitrary update). Restrict read/update/delete to authenticated Attendiphi admins. Enforce uniqueness/day in rules or accept residual fraud. |
| **Production blocker** | YES |

### SEC-006 — Biometric templates readable by anyone via `employees`

| | |
| --- | --- |
| **Severity** | CRITICAL |
| **File** | `firestore.rules` lines 30–33; `lib/features/employee/domain/entities/employee.dart` |
| **Problem** | `allow read: if true`. Documents include `faceEmbedding` / `faceTemplates`. Rules comments admit this. `/faceTemplates/{id}` is correctly `allow read, write: if false`, but production matching still uses employee docs (client WASM `CloudFaceRecognitionService`). |
| **Attack** | Download the member roster and embeddings; spoof check-in `memberId` + `faceVerified` (rules do not check them). |
| **Fix** | Stop putting embeddings on public employee docs. Match only via a trusted server or keep templates in `faceTemplates` (Admin SDK / Edge Function). Do not enable Cloud Functions/Blaze solely for this if Spark is required—use the existing Supabase function or accept that **true** biometric secrecy is incompatible with public client matching. |
| **Production blocker** | YES (PII + biometrics) |

### SEC-007 — `admin_devices` and `admin_notifications` fully open

| | |
| --- | --- |
| **Severity** | CRITICAL |
| **File** | `firestore.rules` lines 40–48 |
| **Problem** | FCM tokens and admin notification payloads are world read/write. |
| **Attack** | Steal push tokens; send arbitrary FCM if a sender is configured; spam/wipe notifications. |
| **Fix** | `request.auth != null` at minimum; preferably token owner + admin-only reads. |
| **Production blocker** | YES |

---

## 3. HIGH findings

### SEC-008 — Any Firebase-authenticated user can write `locations` and `employees`

`firestore.rules`: `allow write: if request.auth != null` / `allow create, update, delete: if request.auth != null`. Login attaches a Firebase session for mail. Any Auth user (including a provisioned admin, or any other Auth user in the project) can rewrite member records, embeddings, location geofences. No role check. **Production blocker: YES** for member/location integrity.

### SEC-009 — Admin vs Super Admin is Flutter-only

`visibleAdminsProvider` filters by `createdBy`. `createAdmin` defaults `AdminRole.admin` in UI. Firestore allows any client to set `role: superadmin`. An Admin can create/update Super Admin documents via SDK. **Production blocker: YES** for RBAC.

### SEC-010 — SHA-256 password hashes on publicly readable admin docs

`AdminPasswordHasher` is `sha256("$salt:$password")`. With SEC-003, hashes are public. Not bcrypt/scrypt/Argon2. Offline cracking is realistic. Firebase Auth is supposed to be source of truth for reset, but login still compares Firestore hashes (`matchesPassword`, including **legacy plaintext** equality).

### SEC-011 — Welcome / Send Mail emails the temporary password

`supabase/functions/send-attendiphi-email/index.ts` `welcomeHtml` / `welcomeText` include `Password:`. Authenticated admin required (Firebase JWT + admin lookup). Client `html` is ignored (good). Recipient is attacker-chosen if a stolen admin session exists. Product risk, not a secret leak of Resend.

### SEC-012 — Unauthenticated password-reset Edge Function is a mail relay

`password_reset` skips Firebase JWT (required for locked-out users). Mitigations: CORS allowlist, email regex, in-memory rate limit (5/email/15m, 20/IP/15m), generic success, no oob in response. Residual: anyone on an allowed origin can trigger Resend + Identity Toolkit for **existing Auth users**. Cold starts reset rate limits. **Does not block production** if SEC-001–007 are fixed, but needs monitoring and a durable rate store if abuse appears.

### SEC-013 — Check-in integrity is client-side

`SubmitCheckIn` and `CheckInRemoteDataSourceImpl` enforce Thursday, QR date, duplicates, GPS via Flutter. Rules do not. Hardcoded test session `2026-09-03` still bypasses Thursday in Dart (`submit_check_in.dart` ~97–128). A malicious client can POST a check-in for any day/location/member.

### SEC-014 — No Storage rules in the repository

No `storage.rules` file. If Storage is enabled on `qr-checkin-dev`, default/open rules may apply. Photo fields today are often `photoBase64` in Firestore (also public via SEC-005). Confirm Console.

### SEC-015 — Legacy Cloud Functions source includes SMTP and `CORS *` face matcher

`functions/index.js`: `sendAdminCredentials`, password-reset HTTPS, `matchMemberFace` with `Access-Control-Allow-Origin: '*'`. Not in `firebase.json`. **If still deployed**, they are HIGH/CRITICAL independently of this Hosting app. Verify and delete in Console without adding Blaze.

### SEC-016 — Local FCM daemon expects a service account on disk

`fcm_server.js` `require('./serviceAccountKey.json')`. Filename is gitignored. If the JSON is present on a laptop, it is a full Admin credential. Do not commit or host it.

---

## 4. MEDIUM findings

| ID | Problem |
| --- | --- |
| SEC-017 | Login email/password validators are non-empty only (`admin_login_screen.dart`). |
| SEC-018 | Admin create phone validator is non-empty only; not `Validators.validatePhone`. |
| SEC-019 | `sessionPassword` kept in `AdminAuthState` for Send Mail (memory only; XSS/devtools). |
| SEC-020 | App Check is **not** activated on web (`firebase_config.dart` 71–86). Abuse of public Firestore is unconstrained by App Check. |
| SEC-021 | `locations` `allow read: if true` — venue GPS/address public (needed for QR; still maps venues). |
| SEC-022 | In-memory Edge Function rate limits. |
| SEC-023 | Password reset HTML button URL is the oob landing URL (correct); text part omits the URL (text-only clients cannot reset). |
| SEC-024 | `mustResetPassword` first-login screen `/admin-reset-password` without oob is unguarded like other admin routes; combined with SEC-001 it is Super Admin context. |
| SEC-025 | README claims “Viewer” role and “enterprise-grade” fraud prevention; code has Super Admin + Admin only; fraud checks are client-side. |
| SEC-026 | `android/build/reports/problems/problems-report.html` is a generated artifact (seen modified in git status). Should not be treated as a product file. |

---

## 5. LOW / INFO

| ID | Problem |
| --- | --- |
| SEC-027 | Firebase Web API keys in `lib/firebase_options.dart` / `google-services.json` are **public by design**. Not secrets. Protect with Auth domain + App Check + rules. |
| SEC-028 | Supabase `sb_publishable_…` in `supabase_email_config.dart` and `web/index.html` is a publishable gateway key. Not SMTP password / service role. |
| SEC-029 | `debugPrint` / `console.log` in Edge Function omit tokens/URLs (inspected). Flutter `AppLogger` is `kDebugMode`. |
| SEC-030 | Hosting Cache-Control no-store on JS is good for not caching old Super Admin passwords in CDN after a fix—until the bundle is rebuilt and redeployed. |
| SEC-031 | `oobCode` in the reset URL is required by Firebase; treat as a capability URL (https, short TTL). |

---

## 6. Authentication audit

| Question | Answer |
| --- | --- |
| A. Unauthenticated UI? | **Yes.** No route guard + SEC-001. `/admins` and admin shell render. `/` still shows the login form (no auto-skip), but auth state is already Super Admin. |
| B. Unauthenticated Firestore? | **Yes** for `admins`, `checkIns` (read/update/delete), `employees` (read), `locations` (read), `admin_devices`, `admin_notifications`. |
| C. Normal user → Super Admin UI? | Any visitor **is** Super Admin in Flutter state (SEC-001). Even after a real Admin login, rules do not stop writing `role`. |
| D. Impersonate another admin? | Read their hash (public `admins`) or overwrite their document. Send Mail uses the **logged-in** Firebase token for welcome mail, but data plane is open. |
| E. Disabled user? | Flutter `isActive` check on login. Rules do not. Disabled admin can still use the SDK if they have hashes/Auth. Deleted Firestore admin can still use Firebase Auth if the Auth user remains. |
| F. Route guards correct? | **No.** |
| G. Guards vs security? | Even a perfect redirect is UX. Real security is rules (currently failing). |

**Login:** Firestore `getAdminByEmail` + `matchesPassword` (hash or plaintext), or hardcoded Super Admin. Then `attachFirebaseAuthSession` for email.

**Logout:** `signOut` sets `isAuthenticated: false` and Firebase `signOut`. Refresh re-runs `build()` → Super Admin again (SEC-001).

**Forgot password:** Flutter → Edge Function `password_reset` → Identity Toolkit oob link → Resend → `/admin-reset-password` → `verifyPasswordResetCode` / `confirmPasswordReset`. No `sendPasswordResetEmail` in `lib/`.

**Session persistence:** Admin auth is in-memory Riverpod. Firebase Auth persistence may keep `currentUser`, but `build()` ignores it for role and forces Super Admin.

**Email verification:** not used.

Routes inspected in router (no `/login`, `/dashboard`, `/settings`, `/check-in` as named paths):

| URL | Intended | Guard |
| --- | --- | --- |
| `/` | Login | Public |
| `/forgot-password` | Forgot | Public |
| `/admin-reset-password` | Reset UI | Public (correct for oob; also loads first-login reset without auth) |
| `/admins` | Super Admin directory | **None** |
| `/daily-attendance` | Admin dashboard | **None** |
| `/members` | Members | **None** |
| `/checkin/:locationId` | Public QR check-in | Public (intentional) |
| `/scanner` | QR scanner | Public |

---

## 7. Authorization audit

Decision path today: **Riverpod `currentAdmin.role` after a client login that is bypassed at startup.**

No Firebase custom claims in Flutter. `functions/index.js` mentions `decoded.adminRole` (legacy Functions).

Sensitive operations:

| Operation | Flutter | Firestore |
| --- | --- | --- |
| List admins | Filtered if `isSuperAdmin` else `createdBy` | Full list for everyone |
| Create admin | UI defaults Admin role | Anyone can `set` any role |
| Delete admin | UI | Anyone |
| Change own role | Not in UI | Anyone via SDK |
| Send welcome mail | `isAuthenticated` + Firebase ID token + Edge Function admin check | N/A |
| Request password reset | Email format | N/A (function) |
| Confirm password reset | Firebase Auth APIs | Hash sync best-effort; `plainPassword` deleted |
| Edit members | Admin screens | Any `request.auth` or even none for **reads** |
| Check-in | Client validators | Open create + open mutate |

Privilege escalation: **yes**, via SEC-001, SEC-003, SEC-009.

---

## 8. Firestore rules audit

| Path | Read | Create | Update | Delete | Issue | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| `locations/{id}` | anyone | `auth != null` | `auth != null` | `auth != null` | Geofence public; any Auth user can move the venue | HIGH |
| `checkIns/{id}` | anyone | if 3 string fields | anyone | anyone | Full attendance leak + forgery | CRITICAL |
| `admins/{id}` | anyone | anyone | anyone | anyone | Authz + password hashes | CRITICAL |
| `employees/{id}` | anyone | `auth != null` | `auth != null` | `auth != null` | PII + embeddings | CRITICAL |
| `faceTemplates/{id}` | deny | deny | deny | deny | Correct; unused by current web matcher | INFO |
| `admin_devices/{id}` | anyone | anyone | anyone | anyone | FCM tokens | CRITICAL |
| `admin_notifications/{id}` | anyone | anyone | anyone | anyone | Open | CRITICAL |
| `admin_mail_dispatch/{id}` | deny | limited draft, no password fields | deny | deny | Reasonable | INFO |
| `mail/{id}` | deny | deny | deny | deny | Correct | INFO |
| `admin_password_resets/{id}` | deny | deny | deny | deny | Correct; unused by new Resend flow | INFO |
| `admin_password_reset_rate/{id}` | deny | deny | deny | deny | Correct; unused (rate limit is in Deno memory) | INFO |
| other collections | default deny | | | | Unlisted paths denied | INFO |

No `request.auth.uid` ownership, no `role` on token, no immutable `role`/`email` fields, no field-level admin restrictions.

---

## 9. Storage rules audit

**No `storage.rules` in the repository.** `firebase.json` does not reference Storage rules. `pubspec.yaml` has no `firebase_storage` package. Photos are primarily Firestore `photoBase64` / `photoUrl` strings.

**Finding:** cannot claim Storage is secure. If the Firebase project has Storage enabled with default open rules, that is a separate Console issue (SEC-014).

---

## 10. Input validation audit

Client validation is UX. Rules do not re-validate names/phones on `admins`/`employees`/`checkIns` beyond three check-in strings.

| Screen | Field | Type | Required | Validation | Quality | Concern | Recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Admin login | Email | text | yes | non-empty | weak | no email syntax | `Validators.validateEmail` |
| Admin login | Password | password | yes | non-empty | weak | no min length | policy on change; login may stay generic |
| Forgot password | Email | email | yes | `validateEmail` | good | — | keep |
| Reset password | New / confirm | password | yes | hasher policy + match | good | — | keep |
| First-login reset | same | password | yes | hasher policy | good | unguarded route | guard without oob |
| Create admin | Name | text | yes | non-empty | weak | no max length | `validateName` |
| Create admin | Phone | phone | yes | non-empty | weak | not 10-digit IN | `validatePhone` |
| Create admin | Email | email | yes | present (inspect form) | medium | duplicate checked in Dart only | rules unique email |
| Create admin | Password | generated | yes | hasher on complete | good | emailed plaintext | invite/reset link |
| Members | Name | text | yes | min 2 | medium | no unicode policy | optional `validateName` |
| Members | Phone | phone | varies | inspect form | medium | — | `validatePhone` |
| Check-in | Name/phone | text | yes | `Validators.*` | good | not in rules | rules or accept fraud |
| Check-in | Visitor email/company/category/inviter | mixed | yes in usecase | present | good | not in rules | same |
| Check-in | Notes/category | free text | some | required non-empty | no max | large docs | max length in rules |
| Visitors admin | search/filters | text | no | none | n/a | Flutter text, not HTML | max length UX |
| Dashboard | search | text | no | none | n/a | — | optional |
| QR | locationId in URL | query | yes | parse QR usecase | medium | guessable IDs | IDs are not secrets |

Flutter `Text` widgets do not interpret HTML. XSS via form fields into Canvas/Text is low. `HtmlElementView` is camera only.

---

## 11. Password security audit

| Search | Result |
| --- | --- |
| `plainPassword` | Entity field; `toMap()` omits it; `updateAdmin` `FieldValue.delete()`; `fromFirestore` still reads if present; `matchesPassword` still accepts plaintext; Send Mail may use in-memory `plainPassword` if set |
| `passwordHash` / salt | Stored on `admins`; SHA-256 | 
| Super Admin secret | Hardcoded (SEC-004) |
| Welcome email | Temporary password in HTML/text |
| Reset tokens | Firebase oob only; not stored in Firestore/Supabase by new flow |
| Logged passwords | Welcome function does not log password; `admin_auth_email.dart` debugPrints recipient not password |
| `sessionPassword` | In RAM for Send Mail |
| URLs | oobCode in reset URL (Firebase design); passwords not in query |
| Browser storage | Device fingerprint / last check-in id in cookies/localStorage (`CookieHelper`), not admin passwords |

Firebase Auth is source of truth **after** `confirmPasswordReset`. Day-to-day Admin login still uses Firestore hashes unless Super Admin master.

---

## 12. Secret exposure audit

| Item | Location | Class |
| --- | --- | --- |
| Firebase Web `apiKey` AIza… | `lib/firebase_options.dart`, Android/iOS plist/json | PUBLIC |
| Super Admin password | `SuperAdminConfig` | **PRIVATE — exposed** |
| `Admin@1234` | `signIn` | **PRIVATE — exposed** |
| Supabase publishable `sb_publishable_…` | Dart + `web/index.html` | PUBLIC (gateway) |
| `SMTP_*` secrets | Edge Function `Deno.env` only | OK if not in git |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | intended as Supabase secret | OK if not in git |
| `serviceAccountKey.json` | gitignored; `fcm_server.js` requires it | OK if absent from git |
| `.env*` | gitignored | OK |
| Functions hardcoded `FIREBASE_WEB_API_KEY` fallback AIza… | `functions/index.js` | PUBLIC web key, leftover |

No `SUPABASE_SERVICE_ROLE` found in Flutter/web.

---

## 13. Supabase Edge Function audit

Single function: `send-attendiphi-email`. `verify_jwt = false` (Firebase tokens, not Supabase Auth).

| Operation | Auth | Notes |
| --- | --- | --- |
| `admin_welcome` | Bearer Firebase ID token, JWKS iss/aud/exp, email+uid, Firestore admin or `SUPER_ADMIN_EMAILS` | Ignores client `html`/`from`. Requires password for template. CORS allowlist. |
| `password_reset` | None | Validates email; rate limit; Identity Toolkit admin oob; rewrites to `/admin-reset-password`; Resend; generic 200; no user-not-found |

**Abuse:** stolen admin session → arbitrary welcome recipient + password in email. Unauthenticated → reset mail to existing Auth users (no existence leak). Sender not client-controlled. Errors are generic. Logs: status/resend id, not oob URLs.

**Missing:** durable rate limit; CAPTCHA; App Check on the function.

---

## 14. Email security

- Welcome: authorized admin, templated HTML, password still in body (product).
- Reset: branded HTML, button only, generic Flutter copy.
- No Gmail API in active Flutter path (docs say retired).
- Header injection: `to` is a validated email string, not concatenated SMTP headers.

---

## 15. XSS / web security

- No `innerHTML` of user data in Dart.
- `web/face_verifier.js`, `face-api.min.js`, `ort.min.js` are static scripts.
- `HtmlElementView` for getUserMedia camera.
- `localStorage`/`sessionStorage`/`document.cookie`: device id and last check-in id (`device_checkin_service.dart`), not Firebase ID tokens (Firebase Auth uses its own persistence).
- Query `oobCode` is sensitive; HTTPS Hosting.
- Flutter web can still leak Super Admin password via JS bundle (SEC-004).

---

## 16. Check-in / QR / face

| Control | Enforced where | Bypass |
| --- | --- | --- |
| QR locationId | Flutter parse + load location | Guess `locationId`; locations are public |
| Thursday / session date | Flutter | Write `checkIns` directly |
| GPS radius | Flutter `ValidateUserProximity` | Omit/lie; rules do not check lat/lng |
| Face match | Client SFace WASM vs public embeddings | Skip camera; set `memberId`/`faceVerified` |
| Duplicate phone/device | Flutter queries + cookies | Different device id; or update existing docs (`delete`/`update` if true) |
| Substitute photo | Flutter required | Not in rules |
| Device id | cookie/localStorage | Trivial to clear |

`CloudFaceRecognitionService` is **not** a cloud API despite the name. `functions.matchMemberFace` is unused by `lib/`. Python `face-recognition-service` is not wired into Flutter Hosting.

---

## 23–24. Tests (summary)

Present: unit/widget coverage for validators, QR parse, email HTTP shape, password reset UX, some admin screens, face matching math, check-in form.

Missing: security tests for rules (Firebase emulator), tests that `build()` is unauthenticated, tests that GoRouter redirects `/admins`, tests that unauthenticated clients cannot `get` `admins` (would fail today), no CI (`.github/` absent).

---

## 25. Exact production blockers

SEC-001, SEC-002, SEC-003, SEC-004, SEC-005, SEC-006, SEC-007, SEC-008, SEC-009.

Until those are fixed, **do not treat the app as production-safe**, even if Hosting is already live.

---

## 26. Remediation order

1. Firestore rules: lock `admins`, `checkIns` mutate/read, `employees` embeddings, devices, notifications.  
2. Stop default Super Admin in `build()`.  
3. Remove hardcoded Super Admin / `Admin@1234` from the client; rotate those passwords.  
4. GoRouter public allowlist + `refreshListenable`.  
5. Confirm Firebase Console: no leftover Functions; Storage rules; Auth authorized domains.  
6. Move biometrics off public employee reads.  
7. Tighten welcome-mail (no password in email) as a follow-up.  
8. Dead-code cleanup only after 1–6.
