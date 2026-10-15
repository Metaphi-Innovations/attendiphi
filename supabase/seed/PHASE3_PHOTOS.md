# Phase 3b — Restore check-in photos

Substitute selfies live in `check_ins.photo_base64`. The main XLSX seed omits them (size). Sync from Firebase:

```bash
node scripts/sync_checkin_photos_to_supabase.js
```

Then in Supabase SQL Editor (project **fzghxzybyygslfjyfewu**), run:

`supabase/seed/phase3_photos.sql`

Expected: **8** updates (only check-ins that have a photo in Firebase). Hot-restart the app after.
