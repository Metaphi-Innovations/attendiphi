#!/usr/bin/env node
/**
 * Full Attendiphi Firebase backup → multi-sheet Excel (.xlsx + .xls).
 *
 * Includes:
 *  - Every Firestore collection (auto-discovered)
 *  - Firebase Auth users
 *  - Friendly domain sheets: members, check-ins by type, substitutes,
 *    visitors, daily attendance, attendance overview
 *
 * Supabase hosts the email Edge Function only (no app tables).
 *
 * Usage:
 *   node scripts/export_firebase_data_to_xls.js
 *   node scripts/export_firebase_data_to_xls.js --include-photos
 *
 * Requires: serviceAccountKey.json at repo root.
 */

const path = require('path');
const fs = require('fs');

const root = path.resolve(__dirname, '..');
const saPath = path.resolve(root, 'serviceAccountKey.json');
const includePhotos = process.argv.includes('--include-photos');

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

let XLSX;
try {
  XLSX = require(path.resolve(root, 'functions/node_modules/xlsx'));
} catch {
  XLSX = require('xlsx');
}

const serviceAccount = JSON.parse(fs.readFileSync(saPath, 'utf8'));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const auth = admin.auth();

const REDACT_ALWAYS = new Set([
  'passwordHash',
  'passwordSalt',
  'password',
  'faceEmbedding',
  'embedding',
  'embeddings',
  'fcmToken',
  'token',
  'tokens',
  'refreshToken',
  'idToken',
  'sessionToken',
  'hmacSecret',
  'secret',
  'privateKey',
  'credentials',
]);

function serializeValue(value) {
  if (value == null) return '';
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) {
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }
  if (typeof value === 'object') {
    if (
      typeof value.latitude === 'number' &&
      typeof value.longitude === 'number'
    ) {
      return `${value.latitude},${value.longitude}`;
    }
    if (typeof value.path === 'string') return value.path;
    try {
      return JSON.stringify(value, (_k, v) => {
        if (v instanceof admin.firestore.Timestamp) {
          return v.toDate().toISOString();
        }
        return v;
      });
    } catch {
      return String(value);
    }
  }
  return value;
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string' || typeof value === 'number') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof value === 'object' && typeof value._seconds === 'number') {
    return new Date(value._seconds * 1000);
  }
  return null;
}

function dayKey(date) {
  if (!date) return '';
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function sanitizeDoc(id, data) {
  const row = { id };
  for (const [key, raw] of Object.entries(data || {})) {
    if (REDACT_ALWAYS.has(key)) {
      row[key] = '[REDACTED]';
      continue;
    }
    if (
      !includePhotos &&
      (key === 'photoBase64' ||
        key === 'photo' ||
        key.toLowerCase().includes('base64'))
    ) {
      const s = typeof raw === 'string' ? raw : '';
      row.hasPhoto = s.trim() ? 'yes' : 'no';
      row[key] = s.trim() ? '[PHOTO_OMITTED]' : '';
      continue;
    }
    const serialized = serializeValue(raw);
    if (typeof serialized === 'string' && serialized.length > 32000) {
      row[key] =
        `${serialized.slice(0, 500)}…[TRUNCATED ${serialized.length} chars]`;
    } else {
      row[key] = serialized;
    }
  }
  return row;
}

function sheetFromRows(rows) {
  if (!rows.length) {
    return XLSX.utils.aoa_to_sheet([['(no documents)']]);
  }
  const headers = [];
  const seen = new Set();
  for (const row of rows) {
    for (const key of Object.keys(row)) {
      if (!seen.has(key)) {
        seen.add(key);
        headers.push(key);
      }
    }
  }
  const aoa = [headers];
  for (const row of rows) {
    aoa.push(headers.map((h) => (row[h] == null ? '' : row[h])));
  }
  return XLSX.utils.aoa_to_sheet(aoa);
}

function addSheet(workbook, name, rows) {
  const safe = name.slice(0, 31);
  XLSX.utils.book_append_sheet(workbook, sheetFromRows(rows), safe);
}

async function listAllCollectionIds() {
  const known = [
    'employees',
    'publicMembers',
    'checkIns',
    'admins',
    'locations',
    'sessionAttendance',
    'faceTemplates',
    'admin_devices',
    'admin_notifications',
    'admin_mail_dispatch',
    'appConfig',
    'deviceSessionLocks',
    'phoneSessionLocks',
    'memberSessionLocks',
  ];
  try {
    const cols = await db.listCollections();
    const ids = cols.map((c) => c.id);
    return Array.from(new Set([...known, ...ids])).sort();
  } catch {
    return known;
  }
}

async function fetchCollection(name) {
  console.log(`  • raw/${name}…`);
  const snap = await db.collection(name).get();
  const rawDocs = [];
  const rows = [];
  snap.forEach((doc) => {
    rawDocs.push({ id: doc.id, data: doc.data() });
    rows.push(sanitizeDoc(doc.id, doc.data()));
  });
  console.log(`    ${rows.length} doc(s)`);
  return { rows, rawDocs };
}

async function fetchAuthUsers() {
  console.log('  • auth_users…');
  const rows = [];
  let nextPageToken;
  do {
    const result = await auth.listUsers(1000, nextPageToken);
    for (const user of result.users) {
      rows.push({
        uid: user.uid,
        email: user.email || '',
        displayName: user.displayName || '',
        phoneNumber: user.phoneNumber || '',
        disabled: user.disabled ? 'yes' : 'no',
        emailVerified: user.emailVerified ? 'yes' : 'no',
        providerIds: (user.providerData || [])
          .map((p) => p.providerId)
          .join(','),
        createdAt: user.metadata?.creationTime || '',
        lastSignInAt: user.metadata?.lastSignInTime || '',
      });
    }
    nextPageToken = result.pageToken;
  } while (nextPageToken);
  console.log(`    ${rows.length} user(s)`);
  return rows;
}

function normalizeType(type) {
  const t = String(type || '').trim().toLowerCase();
  if (t === 'substitute') return 'substitute';
  if (t === 'visitor') return 'visitor';
  if (t === 'absent') return 'absent';
  if (t === 'notcheckedin' || t === 'not_checked_in') return 'notCheckedIn';
  return 'member';
}

function attendanceAt(data) {
  return (
    toDate(data.createdAt) ||
    toDate(data.timestamp) ||
    toDate(data.sessionDate) ||
    null
  );
}

function buildDomainSheets({ employees, checkIns, sessionAttendance }) {
  const members = employees.map(({ id, data }) => ({
    memberId: id,
    name: data.name || '',
    phone: data.phone || '',
    email: data.email || '',
    role: data.role || '',
    designation: data.designation || '',
    isActive: data.isActive === false ? 'no' : 'yes',
    faceEnrolled: data.faceEnrolled ? 'yes' : 'no',
    faceRegistered: data.faceRegistered ? 'yes' : 'no',
    photoUrl: data.photoUrl || '',
    createdAt: serializeValue(data.createdAt),
    updatedAt: serializeValue(data.updatedAt),
  }));

  const checkInRows = checkIns.map(({ id, data }) => {
    const at = attendanceAt(data);
    return {
      checkInId: id,
      type: normalizeType(data.type),
      sessionDate: data.sessionDate || dayKey(at),
      attendedAt: at ? at.toISOString() : '',
      memberId: data.memberId || '',
      userName: data.userName || '',
      userPhone: data.userPhone || '',
      userEmail: data.userEmail || '',
      locationId: data.locationId || '',
      locationName: data.locationName || '',
      isVerified: data.isVerified ? 'yes' : 'no',
      isFlagged: data.isFlagged ? 'yes' : 'no',
      flagReason: data.flagReason || '',
      faceVerified: data.faceVerified ? 'yes' : 'no',
      verificationMethod: data.verificationMethod || '',
      substituteName: data.substituteName || '',
      substitutePhone: data.substitutePhone || '',
      substituteForMember: data.substituteForMember || '',
      invitedByMember: data.invitedByMember || '',
      companyName: data.companyName || '',
      category: data.category || '',
      deviceId: data.deviceId || '',
      hasPhoto:
        typeof data.photoBase64 === 'string' && data.photoBase64.trim()
          ? 'yes'
          : 'no',
      createdAt: serializeValue(data.createdAt),
      timestamp: serializeValue(data.timestamp),
    };
  });

  const byType = (type) =>
    checkInRows.filter((r) => r.type === type);

  // Daily attendance: one row per member × session date with status
  const sessions = new Set();
  for (const row of checkInRows) {
    if (row.sessionDate) sessions.add(String(row.sessionDate).slice(0, 10));
  }
  for (const { id, data } of sessionAttendance || []) {
    const fromDoc =
      data.sessionDate ||
      (typeof id === 'string' && /^\d{4}-\d{2}-\d{2}/.test(id)
        ? id.slice(0, 10)
        : '');
    if (fromDoc) sessions.add(String(fromDoc).slice(0, 10));
  }
  const sessionList = Array.from(sessions).filter(Boolean).sort();

  const memberById = new Map();
  for (const m of members) memberById.set(m.memberId, m);

  // Index check-ins by memberId+session and by name+session
  const statusByMemberSession = new Map();
  for (const row of checkInRows) {
    const keyMember = row.memberId
      ? `${row.memberId}|${row.sessionDate}`
      : null;
    const keyName = `${String(row.userName || '')
      .trim()
      .toLowerCase()}|${row.sessionDate}`;
    const payload = {
      type: row.type,
      checkInId: row.checkInId,
      attendedAt: row.attendedAt,
      substituteName: row.substituteName,
      visitorName: row.type === 'visitor' ? row.userName : '',
    };
    if (keyMember) statusByMemberSession.set(keyMember, payload);
    statusByMemberSession.set(keyName, payload);
  }

  const dailyAttendance = [];
  for (const session of sessionList) {
    for (const member of members) {
      const hit =
        statusByMemberSession.get(`${member.memberId}|${session}`) ||
        statusByMemberSession.get(
          `${member.name.trim().toLowerCase()}|${session}`,
        );
      dailyAttendance.push({
        sessionDate: session,
        memberId: member.memberId,
        memberName: member.name,
        memberPhone: member.phone,
        status: hit ? hit.type : 'notCheckedIn',
        checkInId: hit?.checkInId || '',
        attendedAt: hit?.attendedAt || '',
        substituteName: hit?.substituteName || '',
      });
    }
    // Orphan check-ins (visitor / unknown member) for that day
    for (const row of checkInRows.filter((r) => r.sessionDate === session)) {
      if (row.type === 'visitor') {
        dailyAttendance.push({
          sessionDate: session,
          memberId: '',
          memberName: row.userName || '(visitor)',
          memberPhone: row.userPhone || '',
          status: 'visitor',
          checkInId: row.checkInId,
          attendedAt: row.attendedAt,
          substituteName: '',
        });
      }
    }
  }

  // Attendance overview: per-member totals across all sessions
  const overview = members.map((member) => {
    const rows = checkInRows.filter(
      (r) =>
        r.memberId === member.memberId ||
        (r.userName || '').trim().toLowerCase() ===
          member.name.trim().toLowerCase(),
    );
    const present = rows.filter((r) => r.type === 'member');
    const substitute = rows.filter((r) => r.type === 'substitute');
    const absent = rows.filter((r) => r.type === 'absent');
    const last = rows
      .map((r) => r.attendedAt)
      .filter(Boolean)
      .sort()
      .at(-1);
    return {
      memberId: member.memberId,
      memberName: member.name,
      phone: member.phone,
      isActive: member.isActive,
      totalRecords: rows.length,
      presentCount: present.length,
      substituteCoveredCount: substitute.length,
      absentCount: absent.length,
      lastAttendanceAt: last || '',
    };
  });

  // Substitute profiles (like Substitutes admin page)
  const subByKey = new Map();
  for (const row of byType('substitute')) {
    const phone = String(row.substitutePhone || row.userPhone || '')
      .replace(/\D/g, '');
    const name = (row.substituteName || row.userName || 'Unknown').trim();
    const key =
      phone.length >= 10 ? `p:${phone.slice(-10)}` : `n:${name.toLowerCase()}`;
    if (!subByKey.has(key)) {
      subByKey.set(key, {
        identityKey: key,
        substituteName: name,
        substitutePhone: row.substitutePhone || row.userPhone || '',
        totalVisits: 0,
        membersCovered: new Set(),
        visits: [],
      });
    }
    const profile = subByKey.get(key);
    profile.totalVisits += 1;
    const covered =
      row.substituteForMember || row.userName || 'Unknown member';
    profile.membersCovered.add(covered);
    profile.visits.push(row);
    if (!profile.substituteName || profile.substituteName === 'Unknown') {
      profile.substituteName = name;
    }
  }

  const substituteProfiles = Array.from(subByKey.values())
    .map((p) => {
      const times = p.visits
        .map((v) => v.attendedAt)
        .filter(Boolean)
        .sort();
      return {
        identityKey: p.identityKey,
        substituteName: p.substituteName,
        substitutePhone: p.substitutePhone,
        totalVisits: p.totalVisits,
        membersCoveredCount: p.membersCovered.size,
        membersCovered: Array.from(p.membersCovered).join(' | '),
        firstVisit: times[0] || '',
        lastVisit: times.at(-1) || '',
      };
    })
    .sort((a, b) => b.totalVisits - a.totalVisits);

  const substituteVisits = byType('substitute').map((r) => ({
    checkInId: r.checkInId,
    sessionDate: r.sessionDate,
    attendedAt: r.attendedAt,
    substituteName: r.substituteName || r.userName,
    substitutePhone: r.substitutePhone || r.userPhone,
    coveredMember: r.substituteForMember || r.userName,
    memberId: r.memberId,
    isVerified: r.isVerified,
    hasPhoto: r.hasPhoto,
    locationName: r.locationName,
  }));

  return {
    members,
    check_ins_all: checkInRows,
    member_check_ins: byType('member'),
    substitute_check_ins: byType('substitute'),
    visitor_check_ins: byType('visitor'),
    absent_records: byType('absent'),
    substitute_profiles: substituteProfiles,
    substitute_visits: substituteVisits,
    daily_attendance: dailyAttendance,
    attendance_overview: overview,
  };
}

async function main() {
  console.log(`\nFull backup from Firebase project "${serviceAccount.project_id}"…`);
  console.log(
    includePhotos
      ? 'Including photo payloads.'
      : 'Omitting photo base64 (use --include-photos to include).',
  );

  const workbook = XLSX.utils.book_new();
  const collectionIds = await listAllCollectionIds();
  const rawByName = {};

  addSheet(workbook, '_meta', [
    { key: 'exportedAt', value: new Date().toISOString() },
    { key: 'firebaseProjectId', value: serviceAccount.project_id },
    {
      key: 'supabaseNote',
      value:
        'Supabase = email Edge Function only; no app DB tables. All Attendiphi business data is in Firebase.',
    },
    {
      key: 'supabaseUrl',
      value: 'https://ktnhyohshdwqvvlgeynp.supabase.co',
    },
    {
      key: 'photosIncluded',
      value: includePhotos ? 'yes' : 'no',
    },
    {
      key: 'redactedFields',
      value: Array.from(REDACT_ALWAYS).join(', '),
    },
    {
      key: 'sheetGuide',
      value:
        'members=roster; check_ins_all=all attendance; substitute_*=substitutes; visitor_check_ins=visitors; daily_attendance=per member per session; attendance_overview=member totals; raw_* = full Firestore dumps',
    },
  ]);

  for (const name of collectionIds) {
    try {
      const { rows, rawDocs } = await fetchCollection(name);
      rawByName[name] = rawDocs;
      addSheet(workbook, `raw_${name}`, rows);
    } catch (err) {
      console.warn(`  ! ${name}: ${err.message}`);
      addSheet(workbook, `raw_${name}`, [{ error: String(err.message) }]);
      rawByName[name] = [];
    }
  }

  try {
    const authRows = await fetchAuthUsers();
    addSheet(workbook, 'auth_users', authRows);
  } catch (err) {
    console.warn(`  ! auth_users: ${err.message}`);
    addSheet(workbook, 'auth_users', [{ error: String(err.message) }]);
  }

  console.log('  • building domain sheets…');
  const domain = buildDomainSheets({
    employees: rawByName.employees || [],
    checkIns: rawByName.checkIns || [],
    sessionAttendance: rawByName.sessionAttendance || [],
  });

  addSheet(workbook, 'members', domain.members);
  addSheet(workbook, 'check_ins_all', domain.check_ins_all);
  addSheet(workbook, 'member_check_ins', domain.member_check_ins);
  addSheet(workbook, 'substitute_check_ins', domain.substitute_check_ins);
  addSheet(workbook, 'substitute_profiles', domain.substitute_profiles);
  addSheet(workbook, 'substitute_visits', domain.substitute_visits);
  addSheet(workbook, 'visitor_check_ins', domain.visitor_check_ins);
  addSheet(workbook, 'absent_records', domain.absent_records);
  addSheet(workbook, 'daily_attendance', domain.daily_attendance);
  addSheet(workbook, 'attendance_overview', domain.attendance_overview);

  const outDir = path.resolve(root, 'exports');
  fs.mkdirSync(outDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const base = path.join(outDir, `attendiphi-full-backup-${stamp}`);

  // xlsx is the reliable full backup format (xls has sheet/column limits).
  const xlsxPath = `${base}.xlsx`;
  XLSX.writeFile(workbook, xlsxPath, { bookType: 'xlsx' });

  // Also write classic .xls for convenience (may truncate very wide sheets).
  const xlsPath = `${base}.xls`;
  try {
    XLSX.writeFile(workbook, xlsPath, { bookType: 'xls' });
  } catch (err) {
    console.warn(`Could not write .xls (${err.message}); use .xlsx instead.`);
  }

  console.log('\nDomain sheet counts:');
  for (const [k, v] of Object.entries(domain)) {
    console.log(`  ${k}: ${v.length}`);
  }
  console.log(`\nWrote:\n  ${xlsxPath}`);
  if (fs.existsSync(xlsPath)) console.log(`  ${xlsPath}`);
  console.log('');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
