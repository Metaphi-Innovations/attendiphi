# Phase 4 — Enable Realtime (optional)

Admin dashboards prefer **Realtime** for `check_ins` / `members` /
`session_attendance` / `face_templates`, with a slow REST reconcile poll
(≈5 min) plus reconcile-on-resubscribe / tab-visible as the safety net.
Identical snapshots are not re-emitted (avoids idle UI rebuilds).
Run this so `postgres_changes` events are published.
Also apply `20261019150000_realtime_face_templates.sql` on staging/prod.

**File:** `20261014124500_enable_realtime.sql`

1. Supabase Dashboard → project **fzghxzybyygslfjyfewu** → **SQL Editor**
2. Paste and run `20261014124500_enable_realtime.sql`
3. Confirm under **Database → Publications → supabase_realtime** that `check_ins`, `members`, and `session_attendance` are listed
