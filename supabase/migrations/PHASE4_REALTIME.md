# Phase 4 — Enable Realtime (optional)

Admin dashboards prefer **Realtime** for `check_ins` / `members` /
`session_attendance`, with a slow REST poll only as fallback/reconcile.
Run this so `postgres_changes` events are published.

**File:** `20261014124500_enable_realtime.sql`

1. Supabase Dashboard → project **fzghxzybyygslfjyfewu** → **SQL Editor**
2. Paste and run `20261014124500_enable_realtime.sql`
3. Confirm under **Database → Publications → supabase_realtime** that `check_ins`, `members`, and `session_attendance` are listed
