# Phase 6 — Full app data on Supabase; leave Firebase Hosting & FCM

## Data + auth (flags)

```bash
flutter run -d chrome \
  --dart-define=USE_SUPABASE_DATA=true \
  --dart-define=USE_SUPABASE_AUTH=true
```

| Feature | Backend |
|---------|---------|
| Members, check-ins, locks, locations, app_config, admins, devices, notifications | **Supabase Postgres** |
| Admin login / password reset email | **Supabase Auth** |
| In-app / local OS alerts | **Local notifications + Supabase poll** (no FCM) |
| Web deploy | **Cloudflare Pages** (not Firebase Hosting; Supabase has no SPA host) |

## SQL to apply (if not yet)

1. `20261014132000_seed_location_x.sql`
2. `20261014132100_admin_notifications_anon_insert.sql`

## Stop Firebase Hosting

```bash
# Instead of: firebase deploy --only hosting
./scripts/deploy_web_cloudflare.sh
```

One-time: `npx wrangler login` and create Pages project `attendiphi`.

## FCM removed on Supabase path

With `USE_SUPABASE_DATA=true`:

- No FCM background handler
- `LocalNotificationService` (no `firebase_messaging`)
- Device rows in `admin_devices` use a local UUID (`pushProvider: local`)

## Still initializing Firebase Core (temporary)

Firebase Core may still start for Crashlytics / Auth bridge leftovers. App **data** and **admin auth** (with flags) do not use Firestore/FCM/Hosting. Full Firebase package removal is a later cleanup once the Auth bridge is dropped.
