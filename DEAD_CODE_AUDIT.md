# Attendiphi dead-code and unused-asset audit

**Updated:** 9 Oct 2026 (reconciliation pass)  
**Mode:** inventory. Deletion of LEGACY/UNKNOWN requires explicit change-ID approval + Console confirmation.  
**Rule:** a file is unused only if imports, routes, Hosting, Firebase, tests, and dynamic loads were traced.

Classification: **ACTIVE** | **LEGACY** | **UNUSED** | **DEAD** | **UNKNOWN**

---

## 1. Repository inventory (major)

| Path | Role | Class |
| --- | --- | --- |
| `lib/` | Flutter application | ACTIVE |
| `web/` | SPA shell, face-api, ONNX/wasm, `face_verifier.js` | ACTIVE |
| `test/` | Unit/widget tests; `test/rules/` Firestore rules tests | ACTIVE |
| `functions/` | Legacy Cloud Functions source; **not** in `firebase.json` | LEGACY |
| `supabase/functions/send-attendiphi-email/` | Welcome + password reset mail | ACTIVE |
| `assets/images/` | Branding | ACTIVE |
| `assets/models/mobilefacenet.tflite` | Native face embedder | ACTIVE (IO) |
| `firestore.rules` / `firestore.indexes.json` | Backend access + indexes | ACTIVE |
| `storage.rules` | Deny-all Storage (AUD-SEC-005) | ACTIVE |
| `firebase.json` | Hosting + Firestore + Storage rules | ACTIVE |
| `scripts/build_web_release.sh` | Production web build with token secret | ACTIVE |
| `scripts/backfill_public_members.js` | Active-only publicMembers backfill/cleanup | ACTIVE (ops) |
| `scripts/upload_members_from_ods.js` | ODS import + publicMembers sync | ACTIVE (ops) |
| `fcm_server.js` | Local Admin SDK FCM helper | LEGACY |
| `face-recognition-service/` | Python matcher | UNKNOWN |
| `android/` `ios/` `macos/` | Platform hosts | ACTIVE |
| `.github/workflows/ci.yml` | Flutter analyze/test + rules emulator (no deploy) | ACTIVE |

---

## 2. Duplicate / parallel implementations

| Concern | Active path | Leftover |
| --- | --- | --- |
| Email | Flutter → Supabase Edge Function | `functions/` SMTP stubs |
| Password reset | Firebase Auth oob + Flutter screen + Edge Function | Legacy Functions handlers |
| Face verify | Web WASM + native TFLite | Python service; Functions `matchMemberFace` |
| Admin auth | Firebase Auth + Firestore profile | `superAdminAutoLogin` **removed** (AUD-DEAD-001) |
| Check-in URLs | Opaque HMAC token + legacy dual-read | Keep both until standees migrated |

---

## 3. Dead-code candidates (do not delete without approval)

### A. High confidence leftovers — **external confirmation required**

| Candidate | Evidence | Class | ID |
| --- | --- | --- | --- |
| `functions/` | Not in `firebase.json`; Flutter does not call legacy HTTPS | LEGACY | AUD-DEAD-002 |
| `fcm_server.js` | Requires local service account; not Hosting | LEGACY | AUD-DEAD-003 |

**Manual confirmation:** Firebase Console → Functions / Cloud Scheduler / IAM for leftover callables before archive/delete.

### B. Unknown — confirm before removal

| Candidate | Why | ID |
| --- | --- | --- |
| `face-recognition-service/` | May still be hosted elsewhere | AUD-DEAD-004 |

### C. Completed

| Item | Notes |
| --- | --- |
| AUD-DEAD-001 | `superAdminAutoLogin` absent from `lib/` (verified) |
| AUD-DEAD-005 | `android/build/` gitignored; problems-report untracked/deleted in working tree |
| CI | `.github/workflows/ci.yml` present |

### D. Keep (false positives)

| Item | Why keep |
| --- | --- |
| Legacy `/checkin/location_x?date=` | Printed standees / dual-read |
| `PhotoCaptureScreen` | Routed from `app_router.dart` |
| `plainPassword` field on `AdminUser` | In-memory resend UX only; **omitted from `toMap()`** |
| Bootstrap HMAC secret constant | Debug fallback only; release forbids it |

---

## 4. Credentials on disk (do not print)

| Path | Git | Notes |
| --- | --- | --- |
| `functions/serviceAccountKey.json` | **Ignored** (`*serviceAccountKey*.json`); **not** in `git ls-files` | Present locally in this workspace; never commit; rotate if ever leaked outside git |
| Root `serviceAccountKey.json` | Same ignore pattern | Used by some ops scripts |

No `serviceAccountKey` history found in `git log --all -- '*serviceAccountKey*'`.

---

## 5. Recommended cleanup order (future approvals)

1. Confirm Console → archive `functions/` and `fcm_server.js` (AUD-DEAD-002/003).
2. Product decision on `face-recognition-service/` (AUD-DEAD-004).
3. Keep CI green; do not delete LEGACY without Console evidence.
