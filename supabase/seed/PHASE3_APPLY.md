# Phase 3 — Import backup into Supabase

**Project:** `fzghxzybyygslfjyfewu`  
**Seed SQL:** `phase3_from_backup.sql` (generated from the XLSX backup)  
**Source:** `exports/attendiphi-full-backup-2026-10-14T06-14-35-829Z.xlsx`

## Counts in seed

| Table | Rows |
|---|---|
| members | 96 |
| admins | 6 |
| check_ins | 97 |
| session_attendance | 4 |
| device_session_locks | 60 |
| phone_session_locks | 69 |
| member_session_locks | 66 |
| face_templates | 3 |
| app_config | 1 |
| admin_notifications | 8 |
| admin_mail_dispatch | 5 |

## Apply (required)

Anon key cannot insert into `members` / `admins` (RLS). Run as SQL Editor (postgres role):

1. Open Supabase Dashboard → **fzghxzybyygslfjyfewu** → **SQL Editor**
2. Open / paste **`supabase/seed/phase3_from_backup.sql`**
3. **Run**
4. Verify:

```sql
select count(*) as members from public.members;
select count(*) as check_ins from public.check_ins;
select type, count(*) from public.check_ins group by type order by 1;
select count(*) as admins from public.admins;
select email, role from public.admins order by role, email;
```

Expected ≈ **96** members, **97** check-ins, **6** admins.

## Optional: REST push with service role

```bash
SUPABASE_SERVICE_ROLE_KEY='your-service-role-key' \
  node scripts/import_backup_to_supabase.js --push
```

Never commit the service-role key.

## Gaps still remaining

- Check-in **photos** omitted in backup (`has_photo` only)
- Face **embeddings** redacted
- Admin **passwords** not portable → Phase 5 Supabase Auth invites/resets
- `admins.auth_user_id` still null until Auth cutover

## Regenerate seed from XLSX

```bash
node scripts/import_backup_to_supabase.js
```
