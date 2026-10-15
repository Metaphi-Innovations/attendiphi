# Attendiphi security audit (Supabase)

**Scope:** repository as of **15 Oct 2026** (P0/P1 hardening).  
**Mode:** living document. Re-verify before each production deploy.  
**Live host:** `https://attendiphi.metaphi.in`  
**Supabase project:** `fzghxzybyygslfjyfewu`

> **Historical:** Earlier revisions of this file described Firebase Auth / Firestore /
> Hosting. Those paths are retired in the Flutter client. Keep `firestore.rules` /
> Firebase CI only as archived reference until fully removed from the repo.

---

## 1. Executive summary

**Admin portal** uses Supabase Auth + `public.admins` (RLS via `is_active_admin` /
`is_super_admin`), GoRouter `AuthRedirect`, and Edge Function
`send-attendiphi-email` for provision / delete / password reset.

**Public QR check-in** remains intentionally unauthenticated (anon key). Integrity
depends on:

- HMAC-signed opaque session tokens (`CHECKIN_SESSION_TOKEN_SECRET` in **release**
  builds + matching `public.app_secrets` for server verify)
- `submit_public_check_in` SECURITY DEFINER RPC (Thursday / session date / GPS /
  phone+member locks / orphan reclaim)
- Photos in Storage bucket `check-in-photos` (`photo_path` / `has_photo` only on rows)
- `public.public_members` for QR typeahead (no broad anon `members` SELECT)

**Current readiness status:** **P0+P1 implemented in source** — apply migrations +
redeploy Edge + web before treating production as hardened.

---

## 2. Controls in source (P0 / P1)

| Control | Evidence |
| --- | --- |
| No anon SELECT on `check_ins` | `20261015110000_p0_…sql` |
| Atomic public submit | `submit_public_check_in` + Flutter `SupabaseCheckInRemoteDataSource.createCheckIn` |
| Orphan lock reclaim | Inside RPC (empty/missing `check_in_id`) |
| Shared-device QR | `claimDeviceId` ignored; no device short-circuit |
| QR directory | `public.public_members` → `streamPublicMembers` |
| Release HMAC | `CheckInSessionToken` throws without dart-define; `build_web_release.sh` ≥16 |
| Legacy URL reject (release) | `resolveCheckInSession(rejectLegacy: kReleaseMode)` |
| Photos in Storage | `check-in-photos` bucket; listSelect excludes `photo_base64` |
| Admin hash columns | Column GRANT omits `password_hash`/`password_salt`; Dart `listSelect` |
| Location scope RLS | `admin_can_access_location` on `check_ins` / `locations` |
| Email rate limits | `email_rate_limits` + `bump_email_rate_limit` (service role) |
| Crash hook | `CrashReporting` + `SENTRY_DSN` dart-define; `AppLogger.redact` |

---

## 3. Residual risks

| ID | Risk | Mitigation / next |
| --- | --- | --- |
| SEC-A | Web embeds HMAC secret (minting) | Prefer server-minted standee tokens (P2+) |
| SEC-B | `session_attendance` anon SELECT | Narrow or RPC-only in a later pass |
| SEC-C | Legacy `photo_base64` rows | On-demand fetch; migrate offline |
| SEC-D | ~~Welcome email plaintext password~~ | **Done (P2):** invite/recovery link only |
| SEC-E | Sentry SDK not wired | Hook ready; add `sentry_flutter` when approved |

---

## 4. Apply / deploy checklist

1. Run `20261015110000_p0_rls_lockdown_submit_rpc.sql` (if not already)
2. Set `app_secrets.CHECKIN_SESSION_TOKEN_SECRET` (≥16, same as web build)
3. Run `20261015120000_p1_storage_admin_rls_rate_limits.sql`
4. `supabase functions deploy send-attendiphi-email`
5. `./scripts/build_web_release.sh` + host deploy
6. `./scripts/smoke_thursday_checkin.sh` against staging
7. Manual: substitute photo on-demand; anon cannot `select=password_hash`

See also: `supabase/migrations/PHASE0_APPLY.md`, `PHASE1_APPLY.md`,
`docs/DEVOPS_WEB_DEPLOY.md`.
