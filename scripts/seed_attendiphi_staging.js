#!/usr/bin/env node
/**
 * Idempotent demo seed for Supabase **attendiphi-test** only.
 *
 *   SUPABASE_URL='https://ofieqhdkvofsjnpxkmee.supabase.co' \
 *   SUPABASE_SERVICE_ROLE_KEY='…test service_role…' \
 *   node scripts/seed_attendiphi_staging.js
 *
 * Optional:
 *   STAGING_ADMIN_EMAIL='staging.admin@example.com'
 *   STAGING_ADMIN_PASSWORD='AttendiphiStaging1!'
 *   SESSION_DATE='2026-10-15'   # Thursday YMD
 *
 * Aborts if URL host looks like live production.
 * Never commit service_role keys.
 */

const PROD_REF = 'fzghxzybyygslfjyfewu';
const STAGING_REF = 'ofieqhdkvofsjnpxkmee';

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const ADMIN_EMAIL =
  process.env.STAGING_ADMIN_EMAIL || 'staging.admin@example.com';
const ADMIN_PASSWORD =
  process.env.STAGING_ADMIN_PASSWORD || 'AttendiphiStaging1!';
const SESSION_DATE = process.env.SESSION_DATE || '2026-10-15';
const PREV_SESSION = process.env.PREV_SESSION_DATE || '2026-10-08';

function assertStagingTarget() {
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    console.error(
      'Missing SUPABASE_URL and/or SUPABASE_SERVICE_ROLE_KEY (test project only).',
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
    console.error(
      `REFUSING to seed production host (${host}). Use attendiphi-test (${STAGING_REF}).`,
    );
    process.exit(1);
  }
  if (!host.includes(STAGING_REF)) {
    console.error(
      `REFUSING: host ${host} is not attendiphi-test (${STAGING_REF}).`,
    );
    process.exit(1);
  }
  console.log(`Seeding staging only → ${SUPABASE_URL}`);
}

const headers = {
  apikey: SERVICE_ROLE,
  Authorization: `Bearer ${SERVICE_ROLE}`,
  'Content-Type': 'application/json',
  Prefer: 'resolution=merge-duplicates,return=representation',
};

async function upsert(table, rows, onConflict) {
  const url = new URL(`${SUPABASE_URL}/rest/v1/${table}`);
  if (onConflict) url.searchParams.set('on_conflict', onConflict);
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      ...headers,
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: JSON.stringify(rows),
  });
  if (!res.ok) {
    throw new Error(
      `Upsert ${table} failed: ${res.status} ${await res.text()}`,
    );
  }
}

async function createOrFindAuthUser(email, password) {
  const createRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { staging_demo: true },
    }),
  });
  const createBody = await createRes.json().catch(() => ({}));
  if (createRes.ok && createBody.id) {
    return createBody.id;
  }

  const listRes = await fetch(
    `${SUPABASE_URL}/auth/v1/admin/users?page=1&per_page=200`,
    { headers },
  );
  if (!listRes.ok) {
    throw new Error(
      `List auth users failed: ${listRes.status} ${await listRes.text()}`,
    );
  }
  const listBody = await listRes.json();
  const users = listBody.users || [];
  const hit = users.find(
    (u) => String(u.email || '').toLowerCase() === email.toLowerCase(),
  );
  if (!hit?.id) {
    throw new Error(
      `Could not create or find auth user ${email}: ${JSON.stringify(createBody)}`,
    );
  }
  return hit.id;
}

function thursdayAt(ymd, hour, minute) {
  return `${ymd}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00+05:30`;
}

async function main() {
  assertStagingTarget();

  const nowIso = new Date().toISOString();
  const members = [
    {
      id: 'mem_demo_01',
      name: 'Demo Member One',
      email: 'demo.member1@example.com',
      phone: '9000000001',
      role: 'Member',
      is_active: true,
      updated_at: nowIso,
    },
    {
      id: 'mem_demo_02',
      name: 'Demo Member Two',
      email: 'demo.member2@example.com',
      phone: '9000000002',
      role: 'Member',
      is_active: true,
      updated_at: nowIso,
    },
    {
      id: 'mem_demo_03',
      name: 'Demo Member Three',
      email: 'demo.member3@example.com',
      phone: '9000000003',
      role: 'Member',
      is_active: true,
      updated_at: nowIso,
    },
    {
      id: 'mem_demo_04',
      name: 'Demo Member Four',
      email: 'demo.member4@example.com',
      phone: '9000000004',
      role: 'Member',
      is_active: true,
      updated_at: nowIso,
    },
    {
      id: 'mem_demo_05',
      name: 'Demo Member Five',
      email: 'demo.member5@example.com',
      phone: '9000000005',
      role: 'Member',
      is_active: true,
      updated_at: nowIso,
    },
    {
      id: 'mem_demo_06',
      name: 'Demo Member Six',
      email: 'demo.member6@example.com',
      phone: '9000000006',
      role: 'Member',
      is_active: true,
      updated_at: nowIso,
    },
  ];

  await upsert('members', members, 'id');
  console.log(`Upserted ${members.length} demo members`);

  // Staging GPS pin (attendiphi.staging.metaphi.in) — not production Jade.
  await upsert(
    'locations',
    [
      {
        id: 'location_x',
        name: 'Metaphi',
        address:
          'Excel Plaza, 90 Feet Road, Behind Durga Parmeshwari Mandir, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400075, India',
        latitude: 19.083304,
        longitude: 72.913425,
        radius_meters: 500,
        is_active: true,
        updated_at: nowIso,
        raw: { source: 'staging_seed' },
      },
    ],
    'id',
  );
  console.log('Upserted location_x (staging test pin)');

  const authUserId = await createOrFindAuthUser(ADMIN_EMAIL, ADMIN_PASSWORD);
  await upsert(
    'admins',
    [
      {
        id: 'admin_staging_demo',
        auth_user_id: authUserId,
        uid: authUserId,
        name: 'Staging Demo Admin',
        email: ADMIN_EMAIL,
        phone: '9000000099',
        role: 'superadmin',
        must_reset_password: false,
        is_active: true,
        assigned_location_ids: [],
        updated_at: nowIso,
      },
    ],
    'id',
  );
  console.log(`Upserted staging admin ${ADMIN_EMAIL} (auth ${authUserId})`);

  // Same keys on every row (PostgREST batch upsert requirement).
  const baseCheckIn = {
    location_id: 'location_x',
    location_name: 'Metaphi',
    user_email: null,
    user_latitude: 19.083304,
    user_longitude: 72.913425,
    member_id: null,
    substitute_for_member: null,
    substitute_name: null,
    substitute_phone: null,
    company_name: null,
    category: null,
    invited_by_member: null,
    has_photo: false,
    updated_at: nowIso,
  };

  const checkIns = [
    {
      ...baseCheckIn,
      id: 'cin_demo_member_1510',
      type: 'member',
      user_name: 'Demo Member One',
      user_phone: '9000000001',
      gps_accuracy: 8,
      distance_meters: 12,
      member_id: 'mem_demo_01',
      session_date: SESSION_DATE,
      attended_at: thursdayAt(SESSION_DATE, 7, 45),
      timestamp: thursdayAt(SESSION_DATE, 7, 45),
      created_at: thursdayAt(SESSION_DATE, 7, 45),
    },
    {
      ...baseCheckIn,
      id: 'cin_demo_sub_1510',
      type: 'substitute',
      user_name: 'Demo Member Two',
      user_phone: '9111111111',
      gps_accuracy: 10,
      distance_meters: 20,
      member_id: 'mem_demo_02',
      substitute_for_member: 'Demo Member Two',
      substitute_name: 'Demo Substitute Ava',
      substitute_phone: '9111111111',
      session_date: SESSION_DATE,
      attended_at: thursdayAt(SESSION_DATE, 7, 50),
      timestamp: thursdayAt(SESSION_DATE, 7, 50),
      created_at: thursdayAt(SESSION_DATE, 7, 50),
    },
    {
      ...baseCheckIn,
      id: 'cin_demo_visitor_1510',
      type: 'visitor',
      user_name: 'Demo Visitor Priya',
      user_phone: '9222222222',
      user_email: 'demo.visitor@example.com',
      gps_accuracy: 15,
      distance_meters: 25,
      company_name: 'Demo Foods Pvt Ltd',
      category: 'corporate',
      invited_by_member: 'Demo Member One',
      session_date: SESSION_DATE,
      attended_at: thursdayAt(SESSION_DATE, 7, 55),
      timestamp: thursdayAt(SESSION_DATE, 7, 55),
      created_at: thursdayAt(SESSION_DATE, 7, 55),
    },
    {
      ...baseCheckIn,
      id: 'cin_demo_visitor_0810',
      type: 'visitor',
      user_name: 'Demo Visitor Oct8',
      user_phone: '9333333333',
      user_email: 'demo.visitor.oct8@example.com',
      gps_accuracy: 12,
      distance_meters: 18,
      company_name: 'Oct8 Demo Co',
      category: 'guest',
      invited_by_member: 'Demo Member Three',
      session_date: PREV_SESSION,
      attended_at: thursdayAt(PREV_SESSION, 8, 10),
      timestamp: thursdayAt(PREV_SESSION, 8, 10),
      created_at: thursdayAt(PREV_SESSION, 8, 10),
    },
  ];

  await upsert('check_ins', checkIns, 'id');
  console.log(`Upserted ${checkIns.length} demo check-ins`);

  await upsert(
    'session_attendance',
    [
      {
        id: `session_${SESSION_DATE}`,
        session_date: SESSION_DATE,
        checked_in_member_ids: ['mem_demo_01', 'mem_demo_02'],
        updated_at: nowIso,
      },
      {
        id: `session_${PREV_SESSION}`,
        session_date: PREV_SESSION,
        checked_in_member_ids: [],
        updated_at: nowIso,
      },
    ],
    'id',
  );
  console.log('Upserted session_attendance rows');

  console.log('\nStaging seed complete.');
  console.log(`  Admin login: ${ADMIN_EMAIL}`);
  console.log('  Password: (STAGING_ADMIN_PASSWORD or AttendiphiStaging1!)');
  console.log(`  Sessions: ${PREV_SESSION}, ${SESSION_DATE}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
