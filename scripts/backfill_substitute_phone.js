#!/usr/bin/env node

/**
 * Backfill `substitutePhone` on existing substitute check-ins.
 *
 * Older QR submits only stored the typed phone in `userPhone`. This script
 * copies that value into `substitutePhone` when the dedicated field is missing.
 *
 * Usage:
 *   node scripts/backfill_substitute_phone.js --dry-run
 *   node scripts/backfill_substitute_phone.js
 */

const path = require('path');
const fs = require('fs');

const saPath = path.resolve(__dirname, '../serviceAccountKey.json');
if (!fs.existsSync(saPath)) {
  console.error('❌ serviceAccountKey.json not found at:', saPath);
  process.exit(1);
}

let admin;
try {
  admin = require(path.resolve(__dirname, '../functions/node_modules/firebase-admin'));
} catch {
  try {
    admin = require('firebase-admin');
  } catch (err) {
    console.error('❌ Could not load firebase-admin:', err.message);
    process.exit(1);
  }
}

const serviceAccount = JSON.parse(fs.readFileSync(saPath, 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const dryRun = process.argv.includes('--dry-run');

function digits(phone) {
  return String(phone || '').replace(/\D/g, '');
}

function phonesMatch(a, b) {
  const left = digits(a);
  const right = digits(b);
  if (!left || !right) return false;
  if (left === right) return true;
  return left.endsWith(right) || right.endsWith(left);
}

function normalizeName(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

async function loadEmployeesById() {
  const snap = await db.collection('employees').get();
  const byId = new Map();
  const byName = new Map();
  snap.forEach((doc) => {
    const data = doc.data() || {};
    const emp = {
      id: doc.id,
      name: String(data.name || '').trim(),
      phone: String(data.phone || '').trim(),
    };
    byId.set(doc.id, emp);
    const key = normalizeName(emp.name);
    if (key) byName.set(key, emp);
  });
  return { byId, byName };
}

function resolveCoveredMember(data, employees) {
  const memberId = String(data.memberId || '').trim();
  if (memberId && employees.byId.has(memberId)) {
    return employees.byId.get(memberId);
  }
  const coveredName = String(
    data.substituteForMember || data.userName || '',
  ).trim();
  if (coveredName) {
    return employees.byName.get(normalizeName(coveredName)) || null;
  }
  return null;
}

async function main() {
  console.log(
    `\n🔧 Backfill substitutePhone (${dryRun ? 'DRY RUN' : 'WRITE'}) — project "${serviceAccount.project_id}"\n`,
  );

  const employees = await loadEmployeesById();
  const snap = await db.collection('checkIns').where('type', '==', 'substitute').get();

  console.log(`Found ${snap.size} substitute check-in(s).\n`);

  let updated = 0;
  let skippedHasField = 0;
  let skippedNoPhone = 0;
  let flaggedMemberMatch = 0;
  let nameBackfilled = 0;

  const batchSize = 400;
  let batch = db.batch();
  let batchCount = 0;

  async function commitBatch() {
    if (batchCount === 0) return;
    if (!dryRun) await batch.commit();
    batch = db.batch();
    batchCount = 0;
  }

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const existingSubPhone = String(data.substitutePhone || '').trim();
    const userPhone = String(data.userPhone || '').trim();
    const updates = {};

    if (existingSubPhone) {
      skippedHasField += 1;
    } else if (!userPhone) {
      skippedNoPhone += 1;
    } else {
      updates.substitutePhone = userPhone;
      const member = resolveCoveredMember(data, employees);
      if (member && phonesMatch(userPhone, member.phone)) {
        flaggedMemberMatch += 1;
        console.log(
          `⚠️  ${doc.id}: userPhone matches member roster (${member.name}) — still copying to substitutePhone`,
        );
      } else {
        console.log(`✅ ${doc.id}: substitutePhone ← ${userPhone}`);
      }
      updated += 1;
    }

    // Also restore substituteName when missing but userName is a distinct attendee.
    const existingSubName = String(data.substituteName || '').trim();
    const userName = String(data.userName || '').trim();
    const coveredName = String(data.substituteForMember || '').trim();
    if (
      !existingSubName &&
      userName &&
      coveredName &&
      normalizeName(userName) !== normalizeName(coveredName)
    ) {
      updates.substituteName = userName;
      nameBackfilled += 1;
      console.log(`📝 ${doc.id}: substituteName ← ${userName}`);
    }

    if (Object.keys(updates).length === 0) continue;

    if (!dryRun) {
      batch.update(doc.ref, updates);
      batchCount += 1;
      if (batchCount >= batchSize) await commitBatch();
    }
  }

  await commitBatch();

  console.log('\n----------------------------------------');
  console.log(`substitutePhone set/updated : ${updated}`);
  console.log(`already had substitutePhone : ${skippedHasField}`);
  console.log(`no userPhone to copy        : ${skippedNoPhone}`);
  console.log(`matched member roster phone : ${flaggedMemberMatch}`);
  console.log(`substituteName backfilled  : ${nameBackfilled}`);
  console.log(dryRun ? '\nDry run only — no writes.\n' : '\nDone.\n');
}

main().catch((err) => {
  console.error('❌ Backfill failed:', err);
  process.exit(1);
});
