# Phase 5 — Supabase Auth for admins

**Project:** `fzghxzybyygslfjyfewu`  
**Flags:**
```bash
flutter run -d chrome \
  --dart-define=USE_SUPABASE_DATA=true \
  --dart-define=USE_SUPABASE_AUTH=true
```

Firebase Auth remains available when `USE_SUPABASE_AUTH` is unset/false.

## What Phase 5 does

- Admin login / logout / session restore via **Supabase Auth**
- Admin profile from Postgres `public.admins`
- On login, links `admins.auth_user_id` to `auth.users.id` (also matched by JWT email for RLS)
- Password change uses `supabase.auth.updateUser`
- Member / check-in **authenticated** RLS writes work once signed in

## Provision Auth users (required once)

Seeded `admins` rows do **not** create Auth users. Create one Auth user per admin email.

### Option A — Dashboard (recommended for first login)

1. Supabase → **Authentication** → **Users** → **Add user**
2. Email: e.g. `rinku.s@metaphi.in` (must match `admins.email`)
3. Set a password (share securely; or force reset on first login)
4. Confirm email if your project requires it (disable “Confirm email” for faster local testing under Auth settings)
5. Optional SQL after first login (auto-linked by the app), or manually:

```sql
update public.admins a
set auth_user_id = u.id,
    updated_at = timezone('utc', now())
from auth.users u
where lower(a.email) = lower(u.email);
```

### Option B — Service-role script

```bash
SUPABASE_SERVICE_ROLE_KEY='…' \
  node scripts/provision_supabase_admin_auth.js
```

Creates Auth users for every row in `public.admins` with a temporary password and prints them once. See script header for flags.

## Verify

1. Sign out of any Firebase session (clear site data if needed)
2. Run with both dart-defines above
3. Log in as a provisioned admin
4. Daily Attendance / Members should load; member edits should no longer fail RLS

## Status (post cutover)

Firebase Auth / Firestore are removed from the client. Admins use Supabase Auth
only. Email Edge Function verifies **Supabase** access tokens against the data
project (`ATTENDIPHI_DATA_*` secrets on `ktnhyohshdwqvvlgeynp`).
