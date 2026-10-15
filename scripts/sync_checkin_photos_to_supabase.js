#!/usr/bin/env node
/**
 * Sync check-in photoBase64 from Firebase → Supabase SQL updates.
 *
 * XLSX export truncates long base64 (>32k). This script writes a SQL file
 * you run in the Supabase SQL Editor (postgres role bypasses RLS).
 *
 * Usage:
 *   node scripts/sync_checkin_photos_to_supabase.js
 *
 * Output:
 *   supabase/seed/phase3_photos.sql
 */

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const saPath = path.resolve(root, 'serviceAccountKey.json');
const outSqlPath = path.resolve(root, 'supabase/seed/phase3_photos.sql');

if (!fs.existsSync(saPath)) {
  console.error('serviceAccountKey.json not found at', saPath);
  process.exit(1);
}

let admin;
try {
  admin = require(path.resolve(root, 'functions/node_modules/firebase-admin'));
} catch {
  admin = require('firebase-admin');
}

const serviceAccount = JSON.parse(fs.readFileSync(saPath, 'utf8'));
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

function sqlStr(value) {
  if (value == null) return 'NULL';
  return `'${String(value).replace(/'/g, "''")}'`;
}

async function main() {
  console.log('Fetching checkIns photos from Firebase…');
  const snap = await admin.firestore().collection('checkIns').get();

  const lines = [];
  lines.push('-- Attendiphi Phase 3b: restore check-in photos from Firebase');
  lines.push('-- Run in Supabase SQL Editor on project fzghxzybyygslfjyfewu');
  lines.push('begin;');
  lines.push('');

  let withPhoto = 0;
  let skipped = 0;
  let bytes = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const photo =
      typeof data.photoBase64 === 'string' ? data.photoBase64.trim() : '';
    if (!photo) {
      skipped++;
      continue;
    }
    withPhoto++;
    bytes += photo.length;
    const name = data.substituteName || data.userName || '';
    lines.push(`-- ${doc.id} (${data.type || '?'}) ${name} — ${photo.length} chars`);
    lines.push(`update public.check_ins
set
  photo_base64 = ${sqlStr(photo)},
  has_photo = TRUE,
  updated_at = timezone('utc', now())
where id = ${sqlStr(doc.id)};`);
    lines.push('');
  }

  lines.push('commit;');
  lines.push('');
  lines.push(`-- Synced ${withPhoto} photos (${(bytes / 1e6).toFixed(2)} MB base64); skipped ${skipped} without photo.`);

  fs.mkdirSync(path.dirname(outSqlPath), { recursive: true });
  fs.writeFileSync(outSqlPath, lines.join('\n'), 'utf8');

  console.log(`Wrote ${outSqlPath}`);
  console.log(
    `Photos: ${withPhoto}, skipped empty: ${skipped}, size: ${(bytes / 1e6).toFixed(2)} MB`,
  );
  console.log('Next: paste and run that SQL file in Supabase SQL Editor.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
