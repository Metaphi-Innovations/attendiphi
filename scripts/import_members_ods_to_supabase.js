#!/usr/bin/env node
/**
 * Upsert members from an ODS (name, phone) into public.members on
 * local Docker or attendiphi-test only. Never production.
 *
 *   SUPABASE_URL='http://127.0.0.1:54321' \
 *   SUPABASE_SERVICE_ROLE_KEY='…local service_role…' \
 *   node scripts/import_members_ods_to_supabase.js
 *
 * Optional:
 *   ODS_PATH=supabase/seed/members_list.ods
 *   --dry-run
 *
 * Never commit service_role keys.
 */

const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');

const PROD_REF = 'fzghxzybyygslfjyfewu';
const STAGING_REF = 'ofieqhdkvofsjnpxkmee';
const dryRun = process.argv.includes('--dry-run');

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const ODS_PATH = path.resolve(
  process.env.ODS_PATH ||
    path.join(__dirname, '../supabase/seed/members_list.ods'),
);

function isLocalHost(host) {
  const h = host.toLowerCase();
  return (
    h === '127.0.0.1' ||
    h === 'localhost' ||
    h.startsWith('127.0.0.1:') ||
    h.startsWith('localhost:')
  );
}

function assertSafeTarget() {
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    console.error(
      'Missing SUPABASE_URL and/or SUPABASE_SERVICE_ROLE_KEY (local or attendiphi-test only).',
    );
    process.exit(1);
  }
  let host = '';
  try {
    host = new URL(SUPABASE_URL).host;
  } catch {
    console.error('Invalid SUPABASE_URL');
    process.exit(1);
  }
  if (host.includes(PROD_REF)) {
    console.error(`REFUSING production host (${host}).`);
    process.exit(1);
  }
  if (!isLocalHost(host) && !host.includes(STAGING_REF)) {
    console.error(
      `REFUSING host ${host}. Allowed: local Docker or ${STAGING_REF}.`,
    );
    process.exit(1);
  }
  console.log(`ODS import target → ${SUPABASE_URL}${dryRun ? ' (dry-run)' : ''}`);
}

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

function rowsToMembers(rawRows) {
  const nowIso = new Date().toISOString();
  const members = [];
  const seen = new Set();
  for (const row of rawRows) {
    const name = String(row[0] || '').trim();
    const phone = normalizePhone(row[1]);
    if (!name || phone.length !== 10) {
      console.warn(`Skipping invalid row: ${JSON.stringify(row)}`);
      continue;
    }
    if (seen.has(phone)) {
      console.warn(`Skipping duplicate phone ${phone} (${name})`);
      continue;
    }
    seen.add(phone);
    members.push({
      id: `mem_${phone}`,
      name,
      email: '',
      phone,
      role: 'Member',
      designation: '',
      is_active: true,
      updated_at: nowIso,
    });
  }
  return members;
}

async function upsertMembers(members) {
  const chunkSize = 50;
  for (let i = 0; i < members.length; i += chunkSize) {
    const chunk = members.slice(i, i + chunkSize);
    if (dryRun) continue;
    const url = new URL(`${SUPABASE_URL}/rest/v1/members`);
    url.searchParams.set('on_conflict', 'id');
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        apikey: SERVICE_ROLE,
        Authorization: `Bearer ${SERVICE_ROLE}`,
        'Content-Type': 'application/json',
        Prefer: 'resolution=merge-duplicates,return=minimal',
      },
      body: JSON.stringify(chunk),
    });
    if (!res.ok) {
      throw new Error(
        `Upsert members failed: ${res.status} ${await res.text()}`,
      );
    }
  }
}

async function main() {
  assertSafeTarget();
  if (!fs.existsSync(ODS_PATH)) {
    console.error('ODS not found:', ODS_PATH);
    process.exit(1);
  }
  const members = rowsToMembers(parseOdsRows(ODS_PATH));
  console.log(`Parsed ${members.length} members from ${ODS_PATH}`);
  await upsertMembers(members);
  console.log(
    dryRun
      ? `Dry-run OK (${members.length} would upsert).`
      : `Upserted ${members.length} members.`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
