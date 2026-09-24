# Attendiphi dead-code and unused-asset audit

**Mode:** inventory only. Nothing was deleted.  
**Rule:** a file is unused only if imports, routes, Hosting, Firebase, and dynamic loads were traced.

Classification: **ACTIVE** | **LEGACY** | **UNUSED** | **DUPLICATE** | **DEAD** | **UNKNOWN**

---

## 1. Repository inventory (major)

| Path | Role |
| --- | --- |
| `lib/` | Flutter application (admin, check-in, QR, employee, location, biometrics, email) |
| `web/` | Flutter web shell: `index.html`, face-api, `face_verifier.js`, `ort.min.js`, icons |
| `test/` | Unit/widget tests (~42 Dart files) |
| `functions/` | **Legacy** Firebase Cloud Functions (SMTP, FCM triggers, face HTTP). **Not** in `firebase.json` |
| `supabase/functions/send-attendiphi-email/` | **Active** Edge Function (welcome + password reset) |
| `assets/images/` | Logo **ACTIVE** |
| `assets/models/mobilefacenet.tflite` | Native embedder **ACTIVE** on IO; unused on web |
| `firebase.json` | Hosting `attendiphi` + `dev`, Firestore rules/indexes. No functions, no storage |
| `.firebaserc` | Project `qr-checkin-dev`, hosting targets `attendiphi-by-metaphi` / `qr-checkin-dev` |
| `firestore.rules` | **ACTIVE** (insecure; see SECURITY_AUDIT.md) |
| `firestore.indexes.json` | **ACTIVE** (`checkIns` phone+timestamp) |
| `storage.rules` | **MISSING** |
| `pubspec.yaml` / `pubspec.lock` | Flutter deps |
| `analysis_options.yaml` | Lints |
| `README.md`, `docs/` | Docs |
| `fcm_server.js` | Local Admin SDK listener **LEGACY/UNKNOWN** |
| `face-recognition-service/` | Python FastAPI matcher **UNKNOWN** (not imported by Flutter) |
| `android/`, `ios/`, `macos/` | Mobile shells |
| `.github/` | **Absent** — no CI |
| `package.json` (root) | **Absent**; `functions/package.json` only |

---

## 2. Duplicate implementations

| Concern | Copies | Status |
| --- | --- | --- |
| Email send | Flutter HTTP → Supabase+SMTP; legacy `functions/index.js` SMTP stub; retired Gmail/Resend docs | **ACTIVE** = Supabase SMTP. **LEGACY** = Functions/Gmail |
| Password reset | Flutter+Edge Function+Firebase oob; `functions` `requestAdminPasswordReset` / `completeAdminPasswordReset`; deny-all `admin_password_resets` collection | **ACTIVE** = Edge Function. **LEGACY** = Functions + unused collections |
| Admin create | `AdminRemoteDataSource.createAdmin` + `AdminAuthEmailClient.provisionAuthUser` | **ACTIVE** |
| Face verify | Web SFace WASM (`CloudFaceRecognitionService` + `web/face_verifier.js`); native TFLite (`face_embedding_service_io.dart`); Python service; `functions.matchMemberFace` | **ACTIVE** = client WASM (web) + TFLite (mobile). **LEGACY/UNKNOWN** = Python + Functions |
| Firebase init | `lib/app/config/firebase_config.dart` | **ACTIVE** |
| Supabase init | **None** in `main.dart` (intentional HTTP) | **ACTIVE** |
| Device id | cookies + localStorage + SharedPreferences | **ACTIVE** (layered fallbacks, not dead) |
| Auth | Hardcoded Super Admin + Firestore hash + Firebase Auth session | **ACTIVE** (insecure composition) |

---

## 3. Dead-code candidates (do not delete yet)

### A. High confidence leftover (safe to clean **after** security fixes)

| Candidate | Evidence | Class |
| --- | --- | --- |
| `functions/` (`index.js`, `package.json`, lockfile) | Not referenced by `firebase.json`; Flutter does not call `sendAdminCredentials` / `matchMemberFace` | LEGACY |
| `fcm_server.js` | Node script; requires local `serviceAccountKey.json`; not part of Hosting/Edge | LEGACY |
| `docs/gmail-api-welcome-email.md` | States Gmail is retired | LEGACY doc |
| `pubspec` `pdf` | No `package:pdf/` import in `lib/` or `test/` | UNUSED dependency |
| `pubspec` `integration_test` | No `integration_test/` directory | UNUSED dependency |
| `superAdminAutoLogin()` | Defined; **no** call sites outside its file | DEAD method (keep until Super Admin redesign) |
| Hardcoded `Admin@1234` / `admin@qrcheckin.com` aliases | Only used in `signIn` | SECURITY leftover, not “unused” |

### B. Unknown — do not remove without Console / product confirmation

| Candidate | Why unknown |
| --- | --- |
| `face-recognition-service/` | Full Python app; Flutter Hosting does not call it. May still run elsewhere. README claims `faceTemplates` server store. |
| `functions` **if still deployed** on `qr-checkin-dev` | Source leftover ≠ deleted in GCP |
| `assets/models/mobilefacenet.tflite` | Used by IO embedder; unused on web but required for Android/iOS builds |
| `web/ort.min.js` + `web/face-api/**` | Loaded for web face pipeline — **ACTIVE** |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | Generated |

### C. Files that look old but are ACTIVE

| File | Trace |
| --- | --- |
| `lib/core/biometrics/cloud_face_recognition_service.dart` | Named “cloud”; implementation is client WASM; provided in `biometrics_provider.dart` |
| `lib/core/utils/cookie_helper*.dart` | Used by `device_checkin_service.dart` |
| `lib/core/widgets/gpay_success_animation.dart` | Imported by `checkin_result_screen.dart` |
| `lib/features/admin/presentation/widgets/admin_inspection_banner.dart` | Used by `admin_shell_layout.dart` + tests |
| `lib/services/attendiphi_email_service.dart` | Welcome + password reset HTTP |
| `admin_mail_dispatch` rules | Create-only drafts; may be unused by current UI — **UNKNOWN** |

### D. Generated / should not be treated as product source

| Path | Note |
| --- | --- |
| `android/build/reports/problems/problems-report.html` | Gradle report; appeared in git status |
| `build/` | gitignored |
| `.firebase/` | gitignored |

---

## 4. Dart file usage (lib)

All major feature screens are routed from `app_router.dart`. Stub/web split files (`*_web.dart` / `*_stub.dart`) are conditional imports — **ACTIVE**.

No orphaned screen was found that is neither routed nor imported.

---

## 5. Unused dependency classification (`pubspec.yaml`)

| Package | Class | Evidence |
| --- | --- | --- |
| flutter, flutter_web_plugins | REQUIRED | app |
| firebase_core, cloud_firestore, firebase_auth | REQUIRED | |
| firebase_app_check | REQUIRED (mobile only; skipped on web) | `firebase_config.dart` |
| firebase_crashlytics | REQUIRED (mobile) | |
| firebase_messaging | REQUIRED | notifications |
| flutter_local_notifications | REQUIRED | `firebase_notification_service.dart` |
| flutter_riverpod, go_router | REQUIRED | |
| geolocator, permission_handler | REQUIRED | location |
| mobile_scanner, qr_flutter | REQUIRED | |
| image_picker, flutter_image_compress, image, camera | REQUIRED | |
| uuid, intl, crypto, http | REQUIRED | |
| google_fonts | REQUIRED | theme |
| shared_preferences | REQUIRED | bootstrap + device check-in |
| google_mlkit_face_detection, tflite_flutter | REQUIRED on IO; web uses JS | |
| **pdf** | **UNUSED** | no import |
| flutter_test, flutter_lints, mocktail | REQUIRED dev | |
| **integration_test** | **UNUSED** | no tests dir |

`functions/package.json`: firebase-admin / firebase-functions — **LEGACY** unless Functions remain deployed.

`supabase/.../deno.json`: `jose` — **REQUIRED**.

---

## 6. Debug / development artifacts

| Item | Safe in production? |
| --- | --- |
| `AppLogger` + `kDebugMode` | Yes |
| `debugLogDiagnostics: kDebugMode` on GoRouter | Yes |
| `debugPrint` reCAPTCHA / auth provision | Debug-only |
| Edge `console.log` without secrets | Yes |
| Test session date `2026-09-03` in **production** check-in Dart | **No** — client bypass (see SECURITY_AUDIT SEC-013) |
| `EnvironmentConfig.production` in `main()` | Intended |
| App Check debug providers | Off in production config; App Check not used on web anyway |
| Hardcoded Super Admin | **No** |

---

## 7. Do not remove / required

- `lib/**` feature modules currently routed
- `web/index.html`, face-api weights, `face_verifier.js`, `ort.min.js`
- `supabase/functions/send-attendiphi-email`
- `firestore.rules` (must be **fixed**, not deleted)
- `firebase.json` Hosting rewrites (SPA)
- `assets/images/attendiphi_logo.png`
- Flutter test suite under `test/`

---

## 8. Suggested cleanup order (after security)

1. Confirm Firebase Console has no Functions; then archive `functions/` and `fcm_server.js`.  
2. Confirm Python face service is not in production; then archive `face-recognition-service/`.  
3. Remove unused `pdf` and `integration_test` deps.  
4. Delete `docs/gmail-api-welcome-email.md` or keep as historical pointer.  
5. Remove `superAdminAutoLogin` with the hardcoded Super Admin redesign.  
6. Stop committing `android/build/reports/**`.
