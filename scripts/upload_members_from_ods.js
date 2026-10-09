#!/usr/bin/env node

/**
 * Upsert members from assets/data/Members List.ods into Firestore `employees`
 * and keep `publicMembers` in sync (active upsert / inactive-or-empty delete).
 *
 * Usage:
 *   node scripts/upload_members_from_ods.js
 *   node scripts/upload_members_from_ods.js --dry-run
 *
 * Matching: by normalized 10-digit phone (update name if exists, else create).
 * Email/photo left empty (optional fields).
 *
 * Prefer admin UI CRUD for day-to-day changes (client uses atomic batches).
 * After bulk ODS imports, a full `backfill_public_members.js` dry-run is still
 * recommended to catch orphans outside this import set.
 */

const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');
const { planPublicMemberOp } = require('./backfill_public_members.js');

const dryRun = process.argv.includes('--dry-run');
const odsPath = path.resolve(__dirname, '../assets/data/Members List.ods');
const saPath = path.resolve(__dirname, '../serviceAccountKey.json');

function normalizePhone(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('91') && digits.length === 12) digits = digits.slice(2);
  if (digits.startsWith('0') && digits.length === 11) digits = digits.slice(1);
  return digits;
}

function parseOdsRows(filePath) {
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

/** Queue employee + publicMembers ops on a WriteBatch (same commit). */
function queueEmployeeAndPublicMember(batch, db, { id, employeeFields, isActive }) {
  const empRef = db.collection('employees').doc(id);
  batch.set(empRef, employeeFields, { merge: true });
  const plan = planPublicMemberOp(id, {
    name: employeeFields.name,
    phone: employeeFields.phone,
    isActive,
  });
  const pubRef = db.collection('publicMembers').doc(id);
  if (plan.op === 'upsert') {
    batch.set(pubRef, plan.payload, { merge: true });
  } else {
    batch.delete(pubRef);
  }
  return plan;
}

async function main() {
  if (!fs.existsSync(odsPath)) {
    console.error('❌ ODS not found:', odsPath);
    process.exit(1);
  }
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
  const projectId = serviceAccount.project_id || '(unknown)';
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  const db = admin.firestore();

  const rawRows = parseOdsRows(odsPath);
  const members = [];
  const seenPhones = new Set();

  for (const row of rawRows) {
    const name = String(row[0] || '').trim();
    const phone = normalizePhone(row[1]);
    if (!name || phone.length !== 10) {
      console.warn(`⚠️  Skipping invalid row`);
      continue;
    }
    if (!/^[6-9]\d{9}$/.test(phone)) {
      console.warn(`⚠️  Skipping non-mobile phone for ${name}`);
      continue;
    }
    if (seenPhones.has(phone)) {
      console.warn(`⚠️  Duplicate phone in ODS for ${name} (skipped)`);
      continue;
    }
    seenPhones.add(phone);
    members.push({ name, phone });
  }

  console.log(`\n📋 Parsed ${members.length} members from ODS`);
  console.log(`🔥 Project: ${projectId}`);
  console.log(
    dryRun
      ? '🔎 DRY RUN — no writes to employees or publicMembers\n'
      : '⬆️  Uploading employees + syncing publicMembers…\n',
  );

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
  let projectionsUpserted = 0;
  let projectionsDeleted = 0;
  const nowIso = new Date().toISOString();

  for (const m of members) {
    const existing = byPhone.get(m.phone);
    if (existing) {
      const prevName = String(existing.data.name || '').trim();
      const isActive = existing.data.isActive !== false;
      if (prevName === m.name && normalizePhone(existing.data.phone) === m.phone) {
        unchanged++;
        continue;
      }
      if (dryRun) {
        const plan = planPublicMemberOp(existing.id, {
          name: m.name,
          phone: m.phone,
          isActive,
        });
        console.log(
          `♻️  would update employee ${existing.id} + publicMembers ${plan.op}`,
        );
        if (plan.op === 'upsert') projectionsUpserted++;
        else projectionsDeleted++;
        updated++;
        continue;
      }
      const batch = db.batch();
      const plan = queueEmployeeAndPublicMember(batch, db, {
        id: existing.id,
        isActive,
        employeeFields: {
          name: m.name,
          phone: m.phone,
          updatedAt: nowIso,
          isActive,
        },
      });
      await batch.commit();
      if (plan.op === 'upsert') projectionsUpserted++;
      else projectionsDeleted++;
      console.log(`♻️  updated employee ${existing.id} (phone redacted)`);
      updated++;
    } else {
      if (dryRun) {
        console.log(`➕ would create employee + upsert publicMembers for ${m.name}`);
        created++;
        projectionsUpserted++;
        continue;
      }
      const docRef = db.collection('employees').doc();
      const batch = db.batch();
      const plan = queueEmployeeAndPublicMember(batch, db, {
        id: docRef.id,
        isActive: true,
        employeeFields: {
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
        },
      });
      await batch.commit();
      if (plan.op === 'upsert') projectionsUpserted++;
      else projectionsDeleted++;
      console.log(`➕ created employee ${docRef.id} (phone redacted)`);
      created++;
    }
  }

  console.log('\n——— Summary ———');
  console.log(`Created:   ${created}`);
  console.log(`Updated:   ${updated}`);
  console.log(`Unchanged: ${unchanged}`);
  console.log(`publicMembers upserts (planned or done): ${projectionsUpserted}`);
  console.log(`publicMembers deletes (planned or done): ${projectionsDeleted}`);
  console.log(`Total ODS: ${members.length}`);
  console.log(dryRun ? '\n(dry run complete)\n' : '\n🎉 Upload + projection sync complete\n');
}

module.exports = {
  normalizePhone,
  queueEmployeeAndPublicMember,
};

if (require.main === module) {
  main().catch((err) => {
    console.error('❌', err && err.message ? err.message : err);
    process.exit(1);
  });
}
