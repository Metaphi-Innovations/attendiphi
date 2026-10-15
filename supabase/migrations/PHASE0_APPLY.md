# Phase P0 — RLS lockdown + `submit_public_check_in`

**Project:** `fzghxzybyygslfjyfewu`

## 1. Run migration

Supabase Dashboard → SQL Editor → paste and run:

`20261015110000_p0_rls_lockdown_submit_rpc.sql`

## 2. Set HMAC secret (same as web build)

Use the value from `.secrets/checkin_session_token_secret` / `CHECKIN_SESSION_TOKEN_SECRET`:

```sql
insert into public.app_secrets (id, value)
values ('CHECKIN_SESSION_TOKEN_SECRET', '<same-secret-as-build_web_release.sh>')
on conflict (id) do update
set value = excluded.value,
    updated_at = timezone('utc', now());
```

Until this row exists (≥16 chars), the RPC skips HMAC verify but still enforces
Thursday / session date / GPS when restrictions are ON.

## 3. Deploy Flutter web

```bash
./scripts/build_web_release.sh
```

Release builds **require** the dart-define (no bootstrap secret on web).

## 4. Smoke

- Private browser → Oct 15 opaque QR → member check-in succeeds  
- Second submit same phone → Already Responded  
- Anon REST `GET /check_ins` → denied  
- Anon REST `GET /public_members` → id/name/phone only  
