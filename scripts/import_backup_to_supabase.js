#!/usr/bin/env node
/**
 * Phase 3: Import Attendiphi backup XLSX into Supabase Postgres.
 *
 * Modes:
 *   1) Always writes SQL seed: supabase/seed/phase3_from_backup.sql
 *      (run in Supabase SQL Editor — bypasses RLS)
 *   2) If SUPABASE_SERVICE_ROLE_KEY is set, also upserts via PostgREST
 *
 * Usage:
 *   node scripts/import_backup_to_supabase.js
 *   SUPABASE_SERVICE_ROLE_KEY=... node scripts/import_backup_to_supabase.js --push
 */

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const xlsxPath = path.resolve(
  root,
  'exports/attendiphi-full-backup-2026-10-14T06-14-35-829Z.xlsx',
);
const outSqlPath = path.resolve(root, 'supabase/seed/phase3_from_backup.sql');

const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://fzghxzybyygslfjyfewu.supabase.co';
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const ANON =
  process.env.SUPABASE_ANON_KEY ||
  'sb_publishable_sxoF5zOkdBhDJOm3EH6PjA_uSswNowX';
const doPush = process.argv.includes('--push');

let XLSX;
try {
  XLSX = require(path.resolve(root, 'functions/node_modules/xlsx'));
} catch {
  XLSX = require('xlsx');
}

function sheetRows(wb, ...names) {
  for (const name of names) {
    if (wb.Sheets[name]) {
      return XLSX.utils.sheet_to_json(wb.Sheets[name], { defval: '' });
    }
  }
  return [];
}

/**
 * @param {*} value
 * @param {{ emptyAs?: 'null' | 'empty' }} [opts]
 *   - null: empty/missing → SQL NULL (nullable columns)
 *   - empty: empty/missing → '' (NOT NULL text columns with default '')
 */
function sqlStr(value, opts = {}) {
  const emptyAs = opts.emptyAs || 'null';
  if (value == null || value === '') {
    return emptyAs === 'empty' ? `''` : 'NULL';
  }
  const s = String(value);
  return `'${s.replace(/'/g, "''")}'`;
}

/** NOT NULL text → never emit SQL NULL */
function sqlText(value, fallback = '') {
  if (value == null || value === '') {
    return sqlStr(fallback, { emptyAs: 'empty' });
  }
  return sqlStr(value);
}

function sqlBool(value) {
  if (value === true || value === 'yes' || value === 'true' || value === 'TRUE') {
    return 'TRUE';
  }
  if (value === false || value === 'no' || value === 'false' || value === 'FALSE') {
    return 'FALSE';
  }
  if (value === '' || value == null) return 'NULL';
  return 'FALSE';
}

function sqlTs(value) {
  if (value == null || value === '') return 'NULL';
  // Excel may emit dates as numbers or ISO strings
  if (typeof value === 'number') {
    const parsed = XLSX.SSF.parse_date_code(value);
    if (!parsed) return 'NULL';
    const iso = new Date(
      Date.UTC(parsed.y, parsed.m - 1, parsed.d, parsed.H, parsed.M, parsed.S),
    ).toISOString();
    return sqlStr(iso);
  }
  const d = new Date(String(value));
  if (Number.isNaN(d.getTime())) return 'NULL';
  return sqlStr(d.toISOString());
}

/** Emits a Postgres `date` literal (or NULL). */
function sqlDate(value) {
  if (value == null || value === '') return 'NULL';
  let ymd = null;
  if (typeof value === 'number') {
    const parsed = XLSX.SSF.parse_date_code(value);
    if (!parsed) return 'NULL';
    const m = String(parsed.m).padStart(2, '0');
    const d = String(parsed.d).padStart(2, '0');
    ymd = `${parsed.y}-${m}-${d}`;
  } else {
    const s = String(value).trim();
    if (/^\d{4}-\d{2}-\d{2}/.test(s)) {
      ymd = s.slice(0, 10);
    } else {
      const d = new Date(s);
      if (Number.isNaN(d.getTime())) return 'NULL';
      ymd = d.toISOString().slice(0, 10);
    }
  }
  return `DATE '${ymd}'`;
}

function sqlTextArray(value) {
  if (value == null || value === '') return `'{}'`;
  let parts = [];
  if (Array.isArray(value)) {
    parts = value.map(String);
  } else {
    const s = String(value).trim();
    if (s.startsWith('[')) {
      try {
        parts = JSON.parse(s).map(String);
      } catch {
        parts = s.split(',').map((x) => x.trim()).filter(Boolean);
      }
    } else {
      parts = s.split(',').map((x) => x.trim()).filter(Boolean);
    }
  }
  const escaped = parts.map((p) => `"${String(p).replace(/"/g, '\\"')}"`);
  return `'{${escaped.join(',')}}'`;
}

function mapAdminRole(role) {
  const r = String(role || '').trim().toLowerCase();
  if (r.includes('super')) return 'superadmin';
  return 'admin';
}

function mapCheckInType(type) {
  const t = String(type || 'member').trim();
  const allowed = new Set([
    'member',
    'substitute',
    'visitor',
    'absent',
    'notCheckedIn',
  ]);
  return allowed.has(t) ? t : 'member';
}

function buildSql(wb) {
  const lines = [];
  lines.push('-- Attendiphi Phase 3 seed from backup XLSX');
  lines.push('-- Source: attendiphi-full-backup-2026-10-14T06-14-35-829Z.xlsx');
  lines.push('-- Run in Supabase SQL Editor on project fzghxzybyygslfjyfewu');
  lines.push('begin;');
  lines.push('');

  // Members
  const members = sheetRows(wb, 'members', 'raw_employees');
  lines.push(`-- members (${members.length})`);
  for (const row of members) {
    const id = String(row.memberId || row.id || '').trim();
    if (!id) continue;
    lines.push(
      `insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  ${sqlStr(id)},
  ${sqlText(row.name)},
  ${sqlText(row.email)},
  ${sqlText(row.phone)},
  ${sqlText(row.role, 'Member')},
  ${sqlText(row.designation)},
  coalesce(${sqlBool(row.isActive)}, TRUE),
  ${sqlStr(row.photoUrl)},
  coalesce(${sqlBool(row.faceEnrolled)}, FALSE),
  coalesce(${sqlBool(row.faceRegistered)}, FALSE),
  ${sqlTs(row.createdAt)},
  coalesce(${sqlTs(row.updatedAt)}, timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());`,
    );
  }
  lines.push('');

  // Admins (no auth_user_id yet — Phase 5)
  const admins = sheetRows(wb, 'raw_admins');
  lines.push(`-- admins (${admins.length})`);
  for (const row of admins) {
    const id = String(row.id || row.uid || '').trim();
    if (!id) continue;
    const email = String(row.email || '').trim().toLowerCase();
    if (!email) continue;
    lines.push(
      `insert into public.admins (
  id, uid, name, email, phone, role, must_reset_password, is_active,
  created_by, assigned_location_ids, password_hash, password_salt,
  created_at, last_login_at
) values (
  ${sqlStr(id)},
  ${sqlText(row.uid || id)},
  ${sqlText(row.name)},
  ${sqlText(email)},
  ${sqlText(row.phone)},
  '${mapAdminRole(row.role)}'::public.admin_role,
  coalesce(${sqlBool(row.mustResetPassword)}, FALSE),
  coalesce(${sqlBool(row.isActive)}, TRUE),
  ${sqlStr(row.createdBy)},
  ${sqlTextArray(row.assignedLocationIds)},
  ${sqlStr(row.passwordHash === '[REDACTED]' ? null : row.passwordHash)},
  ${sqlStr(row.passwordSalt === '[REDACTED]' ? null : row.passwordSalt)},
  ${sqlTs(row.createdAt)},
  ${sqlTs(row.lastLoginAt)}
)
on conflict (id) do update set
  uid = excluded.uid,
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  must_reset_password = excluded.must_reset_password,
  is_active = excluded.is_active,
  assigned_location_ids = excluded.assigned_location_ids,
  updated_at = timezone('utc', now());`,
    );
  }
  lines.push('');

  // Check-ins
  const checkIns = sheetRows(wb, 'check_ins_all', 'raw_checkIns');
  lines.push(`-- check_ins (${checkIns.length})`);
  for (const row of checkIns) {
    const id = String(row.checkInId || row.id || '').trim();
    if (!id) continue;
    const memberId = String(row.memberId || '').trim();
    const type = mapCheckInType(row.type);
    lines.push(
      `insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  ${sqlStr(id)},
  '${type}'::public.check_in_type,
  ${sqlText(row.locationId)},
  ${sqlText(row.locationName)},
  ${sqlText(row.userName)},
  ${sqlText(row.userPhone)},
  ${sqlStr(row.userEmail)},
  ${memberId ? sqlStr(memberId) : 'NULL'},
  ${sqlStr(row.substituteForMember)},
  ${sqlStr(row.substituteName)},
  ${sqlStr(row.substitutePhone)},
  ${sqlStr(row.companyName)},
  ${sqlStr(row.category)},
  ${sqlStr(row.invitedByMember)},
  coalesce(${sqlBool(row.hasPhoto)}, FALSE),
  ${sqlStr(row.deviceId)},
  coalesce(${sqlBool(row.isVerified)}, FALSE),
  coalesce(${sqlBool(row.isFlagged)}, FALSE),
  ${sqlStr(row.flagReason)},
  coalesce(${sqlBool(row.faceVerified)}, FALSE),
  ${sqlStr(row.verificationMethod)},
  ${sqlDate(row.sessionDate)},
  ${sqlTs(row.attendedAt || row.createdAt || row.timestamp)},
  ${sqlTs(row.timestamp)},
  coalesce(${sqlTs(row.createdAt)}, timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());`,
    );
  }
  lines.push('');

  // Session attendance
  const sessions = sheetRows(wb, 'raw_sessionAttendance');
  lines.push(`-- session_attendance (${sessions.length})`);
  for (const row of sessions) {
    const id = String(row.id || '').trim();
    if (!id) continue;
    lines.push(
      `insert into public.session_attendance (id, session_date, checked_in_member_ids, updated_at)
values (
  ${sqlStr(id)},
  coalesce(${sqlDate(row.sessionDate)}, ${sqlDate(id)}),
  ${sqlTextArray(row.checkedInMemberIds)},
  coalesce(${sqlTs(row.updatedAt)}, timezone('utc', now()))
)
on conflict (id) do update set
  session_date = excluded.session_date,
  checked_in_member_ids = excluded.checked_in_member_ids,
  updated_at = timezone('utc', now());`,
    );
  }
  lines.push('');

  // Locks
  function emitLocks(table, rows, fieldMap) {
    lines.push(`-- ${table} (${rows.length})`);
    for (const row of rows) {
      const id = String(row.id || '').trim();
      if (!id) continue;
      const sessionDateSql =
        sqlDate(row.sessionDate) === 'NULL' && /^\d{4}-\d{2}-\d{2}/.test(id)
          ? sqlDate(id.slice(0, 10))
          : sqlDate(row.sessionDate);
      lines.push(
        `insert into public.${table} (id, ${fieldMap.col}, session_date, check_in_id, created_at)
values (
  ${sqlStr(id)},
  ${sqlText(row[fieldMap.src])},
  ${sessionDateSql},
  ${sqlStr(row.checkInId)},
  coalesce(${sqlTs(row.createdAt)}, timezone('utc', now()))
)
on conflict (id) do update set
  ${fieldMap.col} = excluded.${fieldMap.col},
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;`,
      );
    }
    lines.push('');
  }

  emitLocks('device_session_locks', sheetRows(wb, 'raw_deviceSessionLocks'), {
    col: 'device_id',
    src: 'deviceId',
  });
  emitLocks('phone_session_locks', sheetRows(wb, 'raw_phoneSessionLocks'), {
    col: 'phone_digits',
    src: 'phoneDigits',
  });
  emitLocks('member_session_locks', sheetRows(wb, 'raw_memberSessionLocks'), {
    col: 'member_id',
    src: 'memberId',
  });

  // App config
  const configs = sheetRows(wb, 'raw_appConfig');
  lines.push(`-- app_config (${configs.length})`);
  for (const row of configs) {
    const id = String(row.id || 'checkInRestrictions').trim();
    lines.push(
      `insert into public.app_config (id, restrictions_enabled, updated_by, updated_by_email, updated_at)
values (
  ${sqlStr(id)},
  coalesce(${sqlBool(row.restrictionsEnabled)}, FALSE),
  ${sqlStr(row.updatedBy)},
  ${sqlStr(row.updatedByEmail)},
  coalesce(${sqlTs(row.updatedAt)}, timezone('utc', now()))
)
on conflict (id) do update set
  restrictions_enabled = excluded.restrictions_enabled,
  updated_by = excluded.updated_by,
  updated_by_email = excluded.updated_by_email,
  updated_at = timezone('utc', now());`,
    );
  }
  lines.push('');

  // Face templates metadata (embeddings usually redacted).
  // Skip rows whose member_id is not in members (FK face_templates_member_id_fkey).
  const memberIds = new Set(
    members
      .map((row) => String(row.memberId || row.id || '').trim())
      .filter(Boolean),
  );
  const faces = sheetRows(wb, 'raw_faceTemplates');
  const facesKept = [];
  const facesSkipped = [];
  for (const row of faces) {
    const id = String(row.id || '').trim();
    if (!id) continue;
    const memberId = String(row.memberId || '').trim();
    if (memberId && !memberIds.has(memberId)) {
      facesSkipped.push({ id, memberId, name: row.name });
      continue;
    }
    facesKept.push(row);
  }
  lines.push(
    `-- face_templates (${facesKept.length} kept, ${facesSkipped.length} skipped — orphan member_id)`,
  );
  for (const row of facesSkipped) {
    lines.push(
      `-- skipped face_template ${sqlStr(row.id)} member_id=${sqlStr(row.memberId)} name=${sqlStr(row.name)}`,
    );
  }
  for (const row of facesKept) {
    const id = String(row.id || '').trim();
    const memberId = String(row.memberId || '').trim();
    lines.push(
      `insert into public.face_templates (id, member_id, name, chapter_id, model, model_version, updated_at)
values (
  ${sqlStr(id)},
  ${memberId ? sqlStr(memberId) : 'NULL'},
  ${sqlStr(row.name)},
  ${sqlStr(row.chapterId)},
  ${sqlStr(row.model)},
  ${sqlStr(row.modelVersion)},
  coalesce(${sqlTs(row.updatedAt)}, timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  name = excluded.name,
  model = excluded.model,
  model_version = excluded.model_version,
  updated_at = timezone('utc', now());`,
    );
  }
  lines.push('');

  // Notifications / mail dispatch as raw-ish
  const notifs = sheetRows(wb, 'raw_admin_notifications');
  lines.push(`-- admin_notifications (${notifs.length})`);
  for (const row of notifs) {
    const id = String(row.id || '').trim();
    if (!id) continue;
    lines.push(
      `insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  ${sqlStr(id)},
  ${sqlStr(row.title)},
  ${sqlStr(row.body)},
  ${sqlStr(row.submissionId)},
  ${sqlStr(row.locationId)},
  ${sqlStr(row.locationName)},
  ${sqlStr(row.userName)},
  ${sqlStr(row.userPhone)},
  ${sqlStr(row.checkInType)},
  ${sqlStr(row.status)},
  ${sqlStr(row.targetRole)},
  ${sqlTs(row.timestamp)}
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;`,
    );
  }
  lines.push('');

  const mails = sheetRows(wb, 'raw_admin_mail_dispatch');
  lines.push(`-- admin_mail_dispatch (${mails.length})`);
  for (const row of mails) {
    const id = String(row.id || '').trim();
    if (!id) continue;
    lines.push(
      `insert into public.admin_mail_dispatch (
  id, recipient_email, recipient_name, role, portal_url, subject,
  status, delivery, automatic_send, created_at
) values (
  ${sqlStr(id)},
  ${sqlStr(row.recipientEmail)},
  ${sqlStr(row.recipientName)},
  ${sqlStr(row.role)},
  ${sqlStr(row.portalUrl)},
  ${sqlStr(row.subject)},
  ${sqlStr(row.status)},
  ${sqlStr(row.delivery)},
  ${sqlBool(row.automaticSend)},
  ${sqlTs(row.createdAt)}
)
on conflict (id) do update set
  status = excluded.status,
  subject = excluded.subject;`,
    );
  }

  lines.push('');
  lines.push('commit;');
  lines.push('');
  lines.push('-- Verify:');
  lines.push('-- select count(*) from public.members;');
  lines.push('-- select count(*) from public.check_ins;');
  lines.push('-- select type, count(*) from public.check_ins group by type;');
  lines.push('-- select count(*) from public.admins;');

  return {
    sql: lines.join('\n'),
    counts: {
      members: members.length,
      admins: admins.length,
      check_ins: checkIns.length,
      session_attendance: sessions.length,
      device_session_locks: sheetRows(wb, 'raw_deviceSessionLocks').length,
      phone_session_locks: sheetRows(wb, 'raw_phoneSessionLocks').length,
      member_session_locks: sheetRows(wb, 'raw_memberSessionLocks').length,
      face_templates: facesKept.length,
      face_templates_skipped: facesSkipped.length,
      app_config: configs.length,
      admin_notifications: notifs.length,
      admin_mail_dispatch: mails.length,
    },
  };
}

async function pushViaRest(wb) {
  if (!SERVICE_ROLE) {
    console.error(
      'Missing SUPABASE_SERVICE_ROLE_KEY — skipping --push REST upsert.',
    );
    return false;
  }

  let createClient;
  try {
    ({ createClient } = require('@supabase/supabase-js'));
  } catch {
    console.error(
      'Install @supabase/supabase-js to use --push:\n  npm install @supabase/supabase-js',
    );
    return false;
  }

  const client = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const members = sheetRows(wb, 'members', 'raw_employees')
    .map((row) => ({
      id: String(row.memberId || row.id || '').trim(),
      name: row.name || '',
      email: row.email || '',
      phone: row.phone || '',
      role: row.role || 'Member',
      designation: row.designation || '',
      is_active: row.isActive !== 'no' && row.isActive !== false,
      photo_url: row.photoUrl || null,
      face_enrolled: row.faceEnrolled === 'yes' || row.faceEnrolled === true,
      face_registered:
        row.faceRegistered === 'yes' || row.faceRegistered === true,
    }))
    .filter((m) => m.id);

  const { error: mErr } = await client.from('members').upsert(members);
  if (mErr) throw mErr;
  console.log(`Pushed members: ${members.length}`);

  const checkIns = sheetRows(wb, 'check_ins_all', 'raw_checkIns')
    .map((row) => {
      const id = String(row.checkInId || row.id || '').trim();
      if (!id) return null;
      const memberId = String(row.memberId || '').trim();
      return {
        id,
        type: mapCheckInType(row.type),
        location_id: row.locationId || '',
        location_name: row.locationName || '',
        user_name: row.userName || '',
        user_phone: row.userPhone || '',
        user_email: row.userEmail || null,
        member_id: memberId || null,
        substitute_for_member: row.substituteForMember || null,
        substitute_name: row.substituteName || null,
        substitute_phone: row.substitutePhone || null,
        company_name: row.companyName || null,
        category: row.category || null,
        invited_by_member: row.invitedByMember || null,
        has_photo: row.hasPhoto === 'yes' || row.hasPhoto === true,
        device_id: row.deviceId || null,
        is_verified: row.isVerified === 'yes' || row.isVerified === true,
        is_flagged: row.isFlagged === 'yes' || row.isFlagged === true,
        flag_reason: row.flagReason || null,
        face_verified: row.faceVerified === 'yes' || row.faceVerified === true,
        verification_method: row.verificationMethod || null,
      };
    })
    .filter(Boolean);

  const { error: cErr } = await client.from('check_ins').upsert(checkIns);
  if (cErr) throw cErr;
  console.log(`Pushed check_ins: ${checkIns.length}`);
  return true;
}

async function main() {
  if (!fs.existsSync(xlsxPath)) {
    console.error('Backup not found:', xlsxPath);
    process.exit(1);
  }

  console.log('Reading', xlsxPath);
  const wb = XLSX.readFile(xlsxPath);
  const { sql, counts } = buildSql(wb);

  fs.mkdirSync(path.dirname(outSqlPath), { recursive: true });
  fs.writeFileSync(outSqlPath, sql, 'utf8');
  console.log('\nWrote SQL seed:', outSqlPath);
  console.log('Row counts:');
  for (const [k, v] of Object.entries(counts)) {
    console.log(`  ${k}: ${v}`);
  }

  if (doPush) {
    console.log('\nPushing via service role…');
    await pushViaRest(wb);
  } else {
    console.log('\nNext: run the SQL file in Supabase SQL Editor');
    console.log('  Project: fzghxzybyygslfjyfewu');
    console.log('  Or: SUPABASE_SERVICE_ROLE_KEY=... node scripts/import_backup_to_supabase.js --push');
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
