# Attendiphi production readiness

**Date:** 9 Oct 2026 (release-order correction pass)  
**Verdict:** **READY FOR REVIEW** — not **PRODUCTION READY**. No live backfill, rules deploy, Hosting deploy, or production smoke tests have been executed in this pass.

---

## Firebase project & Hosting targets (evidence-based)

All IDs below come from repository config. Do **not** assume a separate production Firebase project exists unless Console/ops confirm one.

| Config source | Value |
| --- | --- |
| `.firebaserc` → `projects.default` | **`qr-checkin-dev`** (only project alias in repo) |
| `.firebaserc` → hosting target `attendiphi` | Firebase Hosting **site** `attendiphi-by-metaphi` |
| `.firebaserc` → hosting target `dev` | Firebase Hosting **site** `qr-checkin-dev` |
| `firebase.json` | Both targets publish `build/web` |
| `lib/firebase_options.dart` | `projectId: qr-checkin-dev` |
| README | Target `attendiphi` → `attendiphi-by-metaphi.web.app`; target `dev` → `qr-checkin-dev.web.app`; marketing URL `https://attendiphi.metaphi.in` labeled “Production Portal” |

### Critical shared-backend fact

In this repository, **both Hosting sites are mapped under the same Firebase project `qr-checkin-dev`.**  
Firestore rules, `employees`, and `publicMembers` are therefore **shared** across:

- Hosting site `attendiphi-by-metaphi` (README: production portal / `attendiphi.metaphi.in`)
- Hosting site `qr-checkin-dev` (README: dev domain)

**Unresolved (needs operator confirmation before any live step):**

1. Is `qr-checkin-dev` the only Firebase project for Attendiphi, or does Console also have a separate prod project not listed in `.firebaserc`?
2. If shared: a rules deploy or backfill against `qr-checkin-dev` affects **both** Hosting sites immediately.
3. Which site/URL is the approved cutover target for this release (`hosting:attendiphi`, `hosting:dev`, or both)?

Until those answers are explicit, treat commands below as templates bound to **whatever project `firebase use` shows**, not as automatic “production.”

---

## Category scorecard

| Category | Level | Blocker for go-live? |
| --- | --- | --- |
| Active-only `publicMembers` + atomic admin CRUD | Implemented in repo | Deploy + backfill pending |
| Firestore rules (active-only read/query) | Implemented in repo; emulator verified locally | Deploy pending |
| Storage deny-all | In repo (`storage.rules`) | Deploy if Storage enabled |
| CI (Flutter + rules Java 21) | `.github/workflows/ci.yml` (no deploy) | Push/PR to run on GitHub |
| Check-in HMAC dart-define ≥16 | Release throws + build script | Build with approved secret |
| HMAC in Web bundle | Extractable — not a server secret | Residual |
| Shared project for both Hosting sites | Documented above | Confirm before cutover |
| Live migration / Hosting | Not run | **Authorization required** |

---

## Why “Hosting → backfill → rules” is ambiguous / risky

### Compatibility matrix (repo behavior)

| Live Firestore rules | `publicMembers` data | New client (`where isActive==true`) | Old client (unfiltered list / or still on `employees`) |
| --- | --- | --- | --- |
| Old open reads | **Empty / missing** | **Empty QR typeahead** | May still work if it reads `employees` under old open rules |
| Old open reads | Populated (active docs) | Works | Works (may still see inactive leftovers if they exist as docs) |
| New rules (`isActive==true` required) | Empty | Empty typeahead | **Breaks** unfiltered `publicMembers` queries |
| New rules | Populated + filtered query | Works | Unfiltered list **fails**; direct get of inactive **denied** |

### Failure mode of “Hosting first, then backfill”

If the new Hosting bundle is shipped **before** `publicMembers` is populated:

- The new app **only** streams `publicMembers.where(isActive==true)` (see `EmployeeRemoteDataSource.streamPublicMembers`).
- An empty collection ⇒ **empty QR typeahead** even though `employees` is full.
- That is a user-visible outage, not merely a security gap.

If **new rules** are deployed **before** the new Hosting bundle:

- Any still-cached **old** client that lists `publicMembers` without `where('isActive','==',true)` fails Firestore security (query must match rules).
- That breaks old bundles still in use on either Hosting site (remember: shared project).

### Correct principle

1. **Data before dependent clients:** populate/verify `publicMembers` before relying on the new Hosting build for typeahead.  
2. **Compatible clients before restrictive rules:** ship (or dual-run) the filtered-query client before enforcing `isActive==true` reads.  
3. **Verify live rules first:** never assume Console matches this repo.

---

## Recommended safe sequence (authorized operators only)

Do **not** execute these steps without explicit approval. This pass ran **none** of the live operations.

### Phase A — Confirm environment

1. `firebase use` and record the active project ID.  
2. Confirm Hosting target → site mapping (`firebase target:apply` / Console Hosting).  
3. Confirm whether cutover is `hosting:attendiphi`, `hosting:dev`, or both.  
4. **Export / screenshot currently deployed Firestore rules** from Console (or `firebase firestore:rules get` if available in your CLI version) and compare to repo `firestore.rules`.  
5. Decide whether this Firebase project is shared by prod+dev Hosting (per `.firebaserc` it is). If shared, schedule a maintenance window affecting **both** sites.

### Phase B — Dry-run migration (no writes)

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/approved-sa.json  # do not commit
node scripts/backfill_public_members.js --dry-run
```

Inspect summary only (phones are redacted in logs): planned upserts, inactive deletes, orphan deletes. **Stop** if counts look wrong.

### Phase C — Approved live backfill + data verification

```bash
node scripts/backfill_public_members.js
```

Then verify (Console or Admin SDK; no PII in tickets):

- Count of `publicMembers` ≈ count of **active** `employees`.  
- Spot-check: inactive employee IDs have **no** `publicMembers/{id}` (or get denied under new rules later).  
- Orphans removed as intended.  
- `employees` documents unchanged by the script.

**Gate:** do not proceed to Hosting cutover until typeahead data exists.

### Phase D — Hosting (new client) while rules still allow the filtered query

1. Build with approved secret: `./scripts/build_web_release.sh`  
2. Deploy **only the approved target**, e.g. `firebase deploy --only hosting:attendiphi` (or `:dev` for a staged site).  
3. Smoke on that URL: QR typeahead lists active members; check-in still creates; admin login works.

Under **old** open `publicMembers` rules, the new filtered query works once data exists.  
Under **already-new** rules, the new client also works; old unfiltered clients do not.

### Phase E — Deploy restrictive Firestore rules

```bash
firebase deploy --only firestore:rules
# optional, if Storage enabled:
# firebase deploy --only storage
```

**Only after** Phase D Hosting smoke succeeds (or old clients are retired), because new rules deny:

- unfiltered `publicMembers` collection queries  
- `get` of docs with `isActive != true` or missing `isActive`

### Phase F — Post-deploy smoke & rollback criteria

| Check | Pass criteria | Rollback if |
| --- | --- | --- |
| Anonymous typeahead | Active names appear | Empty after Hosting → restore previous Hosting **or** fix data via backfill |
| Inactive not discoverable | Direct get of known inactive/legacy id fails; filtered query omits them | Rules wrong → redeploy last known-good rules |
| Admin CRUD | Create/update/deactivate/delete member; projection appears/disappears | App bug → Hosting rollback; data ok → keep rules |
| Check-in create | Unauth create still works under allowlist | Rules regression → rules rollback |
| Shared-site impact | Dev site still acceptable if same project | Unexpected prod impact → rules + Hosting rollback |

**Rollback actions**

| Failure | Action |
| --- | --- |
| New rules break remaining old clients | Redeploy previous `firestore.rules` from last known-good commit |
| Empty typeahead after Hosting | Prioritize backfill verification; temporarily roll Hosting to previous bundle if needed |
| Bad backfill | Re-run script (idempotent); script never writes `employees` |
| Bad Hosting build | Redeploy previous Hosting release; regenerate standees only if token secret rotated |

---

## How `publicMembers` rules enforce inactive exclusion (server-side)

Repo rule (`firestore.rules`):

```
allow read: if resource.data.isActive == true
  && resource.data.keys().hasOnly(['id','name','phone','isActive','updatedAt']);
allow create, update: if … && request.resource.data.isActive == true …;
allow delete: if isAttendiphiAdmin();
```

| Access pattern | Enforced by rules? |
| --- | --- |
| Anonymous **get** of active doc with allowlisted keys | Allowed |
| Anonymous **get** of doc with `isActive: false` | **Denied** |
| Anonymous **get** of doc **missing** `isActive` | **Denied** (`undefined == true` is false) |
| Anonymous **unfiltered** `collection('publicMembers').get()` / listen | **Denied** (query must constrain fields used in rules) |
| Anonymous query `where('isActive','==',true)` | **Allowed** for matching active docs only |
| Anonymous create/update/delete | **Denied** |
| Admin write with `isActive: false` | **Denied** (must delete projection instead) |

**Client-side** `.where('isActive'==true)` and UI `activeOnly` are **not** the security boundary; they only match the rules so queries succeed. Security is the Firestore rule evaluation above.

Until these rules are **deployed** to the live project, Console may still allow broader reads — verify Phase A before claiming protection in production.

---

## Must complete before “PRODUCTION READY”

1. Resolve unresolved project/site questions (shared `qr-checkin-dev` vs separate prod).  
2. Capture live rules baseline.  
3. Dry-run → approved live backfill → verify `publicMembers` population.  
4. Deploy approved Hosting target with new client; smoke typeahead.  
5. Deploy `firestore.rules` (and Storage if needed).  
6. Post-deploy smoke + confirm inactive direct reads fail.  
7. Build used approved `CHECKIN_SESSION_TOKEN_SECRET` (≥16); treat Web embed as extractable.

---

## Exact operator command template (approval required; order matches phases)

```bash
# A) Confirm project — do not assume production
firebase use
firebase target:apply hosting   # or inspect Console; record site IDs

# B) Dry-run (no writes)
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/approved-sa.json
node scripts/backfill_public_members.js --dry-run

# C) Live backfill — ONLY after explicit approval + dry-run review
node scripts/backfill_public_members.js
# verify publicMembers counts vs active employees before continuing

# D) Build + Hosting (approved target only)
export CHECKIN_SESSION_TOKEN_SECRET='…'   # from vault; ≥16; do not log
./scripts/build_web_release.sh
firebase deploy --only hosting:attendiphi   # or hosting:dev — operator chooses
# smoke typeahead on that URL

# E) Rules — AFTER Hosting smoke (shared project affects all sites)
firebase deploy --only firestore:rules
# smoke: filtered query works; inactive get fails; check-in create works
```

---

## Configuration summary

| Item | State |
| --- | --- |
| Default Firebase project in repo | `qr-checkin-dev` |
| Hosting target `attendiphi` | site `attendiphi-by-metaphi` |
| Hosting target `dev` | site `qr-checkin-dev` |
| Firestore backend | Shared by both sites per `.firebaserc` |
| Functions in `firebase.json` | None |
| Storage | `storage.rules` deny-all |
| Check-in token | dart-define required in release; Web-extractable |
| CI Flutter version | `3.47.6` (workflow) |

---

## Audit change-ID checklist (reconciled to code)

| ID | Status | Evidence |
| --- | --- | --- |
| AUD-OPS-001 | **Complete and verified** | `scripts/build_web_release.sh`; release `StateError` in token class |
| AUD-OPS-002 | **Complete and verified** | `minSecretLength = 16`; unit tests |
| AUD-SEC-002 | **Implemented but insufficiently tested live** | Repo rules + client + backfill/ODS sync; **deploy + live backfill pending** |
| AUD-SEC-005 | **Complete and verified** (repo) | `storage.rules` deny-all + `firebase.json`; **deploy if Storage on** |
| AUD-SEC-006 | **Complete and verified** | `matchesPassword` salted hash only; `toMap` omits `plainPassword` |
| AUD-SEC-008 | **Complete and verified** | `redactEmail`; ODS logs redact phones |
| AUD-SEC-009 | **Complete and verified** | Fixed orphaned-Auth copy (no full email echo) |
| AUD-DOC-001 | **Complete and verified** | This file + `SECURITY_AUDIT.md` + `DEAD_CODE_AUDIT.md` |
| AUD-DOC-002 | **Complete and verified** | Web HMAC extractability documented |
| AUD-CI-001 | **Complete and verified** (repo) | `.github/workflows/ci.yml`; **GitHub run not executed here** |
| AUD-LOCAL-001 | **Complete and verified** | Check-in phone/typeahead + `_validateFormNextFrame`; widget tests |
| AUD-ARCH-001 | **Partially implemented** | Hero metric, filter chip, attendance filter chips extracted; screen still large |
| AUD-ARCH-002 | **Partially implemented** | Validation helper + typeahead close helpers; form still large |
| AUD-ARCH-003 | **Complete and verified** | Shared `_validateFormNextFrame` |
| AUD-PERF-001 | **Partially implemented** | QR uses `publicMembersStreamProvider`; admin still watches full `employees` (required) |
| AUD-PERF-002 | **Partially implemented** | Public directory is minimal fields; no pagination (product tradeoff) |
| AUD-DEAD-001 | **Complete and verified** | `superAdminAutoLogin` absent from `lib/` |
| AUD-DEAD-002 | **Requires external confirmation** | `functions/` LEGACY — Console check before delete |
| AUD-DEAD-003 | **Requires external confirmation** | `fcm_server.js` LEGACY |
| AUD-DEAD-004 | **Requires external confirmation** | `face-recognition-service/` UNKNOWN |
| AUD-DEAD-005 | **Complete and verified** | `android/build/` ignored; report removed from tree |
| AUD-DEP-001 | **Requires explicit approval** | No major upgrades this pass (`google_fonts` stays on current major) |

---

## Remediation tracking

| ID | Status |
| --- | --- |
| AUD-SEC-002 | Repo + rules tests; **live backfill/rules/Hosting pending** |
| AUD-CI-001 | Workflow present; rules job Temurin 21 |
| AUD-OPS-001 / 002 | Build script + release `StateError` ≥16 |
| AUD-DOC-002 | Web extractability in `SECURITY_AUDIT.md` |
| Release-order docs | Data → Hosting → rules; shared project called out |
| ODS import | Syncs `publicMembers` in same batch as employee writes |

---

## Verification status

Local code/tests: see `SECURITY_AUDIT.md` § Final verification (re-run in reconciliation pass).  
**No deployment, live backfill, credential rotation, push, or commit in this pass.**
