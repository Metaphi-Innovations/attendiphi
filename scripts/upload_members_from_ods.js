#!/usr/bin/env node

/**
 * Upsert members from assets/data/Members List.ods into Firestore `employees`.
 *
 * Usage:
 *   node scripts/upload_members_from_ods.js
 *   node scripts/upload_members_from_ods.js --dry-run
 *
 * Matching: by normalized 10-digit phone (update name if exists, else create).
 * Email/photo left empty (optional fields).
 */

const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');

const saPath = path.resolve(__dirname, '../serviceAccountKey.json');
if (!fs.existsSync(saPath)) {
  console.error('❌ serviceAccountKey.json not found at:', saPath);
  process.exit(1);
}

let admin;
try {
  admin = require(path.resolve(__dirname, '../functions/node_modules/firebase-admin'));
} catch {
  admin = require('firebase-admin');
}

const serviceAccount = JSON.parse(fs.readFileSync(saPath, 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const dryRun = process.argv.includes('--dry-run');
const odsPath = path.resolve(__dirname, '../assets/data/Members List.ods');

function normalizePhone(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('91') && digits.length === 12) digits = digits.slice(2);
  if (digits.startsWith('0') && digits.length === 11) digits = digits.slice(1);
  return digits;
}

function parseOdsRows(filePath) {
  // Prefer Python (stdlib zip+xml) — no extra npm deps.
  const py = `
import zipfile, xml.etree.ElementTree as ET, json, sys
p = sys.argv[1]
with zipfile.ZipFile(p) as z:
    root = ET.fromstring(z.read('content.xml'))
ns = {
  'table':'urn:oasis:names:tc:opendocument:xmlns:table:1.0',
  'text':'urn:oasis:names:tc:opendocument:xmlns:text:1.0',
}
rows = []
for table in root.findall('.//table:table', ns):
  for tr in table.findall('table:table-row', ns):
    cells = []
    for tc in tr.findall('table:table-cell', ns):
      repeat = int(tc.get('{urn:oasis:names:tc:opendocument:xmlns:table:1.0}number-columns-repeated') or '1')
      texts = [''.join(n.itertext()) for n in tc.findall('.//text:p', ns)]
      val = ' '.join(t.strip() for t in texts if t.strip())
      for _ in range(min(repeat, 10)):
        cells.append(val)
    while cells and not cells[-1]:
      cells.pop()
    if any(c.strip() for c in cells):
      rows.append(cells)
print(json.dumps(rows))
`;
  const out = execFileSync('python3', ['-c', py, filePath], {
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024,
  });
  return JSON.parse(out);
}

async function main() {
  if (!fs.existsSync(odsPath)) {
    console.error('❌ ODS not found:', odsPath);
    process.exit(1);
  }

  const rawRows = parseOdsRows(odsPath);
  const members = [];
  const seenPhones = new Set();

  for (const row of rawRows) {
    const name = String(row[0] || '').trim();
    const phone = normalizePhone(row[1]);
    if (!name || phone.length !== 10) {
      console.warn(`⚠️  Skipping invalid row: ${JSON.stringify(row)}`);
      continue;
    }
    if (!/^[6-9]\d{9}$/.test(phone)) {
      console.warn(`⚠️  Skipping non-mobile phone for ${name}: ${phone}`);
      continue;
    }
    if (seenPhones.has(phone)) {
      console.warn(`⚠️  Duplicate phone in ODS for ${name}: ${phone} (skipped)`);
      continue;
    }
    seenPhones.add(phone);
    members.push({ name, phone });
  }

  console.log(`\n📋 Parsed ${members.length} members from ODS`);
  console.log(`🔥 Project: ${serviceAccount.project_id}`);
  console.log(dryRun ? '🔎 DRY RUN — no writes\n' : '⬆️  Uploading to employees…\n');

  const snap = await db.collection('employees').get();
  const byPhone = new Map();
  snap.forEach((doc) => {
    const data = doc.data() || {};
    const phone = normalizePhone(data.phone);
    if (phone.length === 10) byPhone.set(phone, { id: doc.id, data });
  });

  let created = 0;
  let updated = 0;
  let unchanged = 0;
  const nowIso = new Date().toISOString();

  for (const m of members) {
    const existing = byPhone.get(m.phone);
    if (existing) {
      const prevName = String(existing.data.name || '').trim();
      if (prevName === m.name && normalizePhone(existing.data.phone) === m.phone) {
        unchanged++;
        continue;
      }
      if (dryRun) {
        console.log(`♻️  would update ${m.name} (${m.phone}) id=${existing.id}`);
        updated++;
        continue;
      }
      await db.collection('employees').doc(existing.id).set(
        {
          name: m.name,
          phone: m.phone,
          updatedAt: nowIso,
          isActive: existing.data.isActive !== false,
        },
        { merge: true },
      );
      console.log(`♻️  updated ${m.name} (${m.phone})`);
      updated++;
    } else {
      if (dryRun) {
        console.log(`➕ would create ${m.name} (${m.phone})`);
        created++;
        continue;
      }
      const docRef = db.collection('employees').doc();
      await docRef.set({
        id: docRef.id,
        name: m.name,
        phone: m.phone,
        email: '',
        role: 'Member',
        designation: '',
        isActive: true,
        faceEnrolled: false,
        faceRegistered: false,
        photoUrl: null,
        createdAt: nowIso,
        updatedAt: nowIso,
      });
      console.log(`➕ created ${m.name} (${m.phone})`);
      created++;
    }
  }

  console.log('\n——— Summary ———');
  console.log(`Created:   ${created}`);
  console.log(`Updated:   ${updated}`);
  console.log(`Unchanged: ${unchanged}`);
  console.log(`Total ODS: ${members.length}`);
  console.log(dryRun ? '\n(dry run complete)\n' : '\n🎉 Upload complete\n');
}

main().catch((err) => {
  console.error('❌', err);
  process.exit(1);
});
