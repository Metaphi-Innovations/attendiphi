#!/usr/bin/env node
/**
 * Phase 5: Create Supabase Auth users for each public.admins email and
 * link admins.auth_user_id.
 *
 * Requires service role (never put this key in Flutter):
 *
 *   SUPABASE_SERVICE_ROLE_KEY='…' node scripts/provision_supabase_admin_auth.js
 *
 * Optional:
 *   TEMP_PASSWORD='ChangeMeNow!'   # default AttendiphiTemp1!
 *   SUPABASE_URL=https://fzghxzybyygslfjyfewu.supabase.co
 */

const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://fzghxzybyygslfjyfewu.supabase.co';
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const TEMP_PASSWORD = process.env.TEMP_PASSWORD || 'AttendiphiTemp1!';

if (!SERVICE_ROLE) {
  console.error('Missing SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

// Staging safety: refuse prod when ATTENDIPHI_STAGING_ONLY=1.
if (process.env.ATTENDIPHI_STAGING_ONLY === '1') {
  if (String(SUPABASE_URL).includes('fzghxzybyygslfjyfewu')) {
    console.error(
      'ATTENDIPHI_STAGING_ONLY=1 — refusing production URL. Use attendiphi-test.',
    );
    process.exit(1);
  }
}

const headers = {
  apikey: SERVICE_ROLE,
  Authorization: `Bearer ${SERVICE_ROLE}`,
  'Content-Type': 'application/json',
};

async function listAdmins() {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/admins?select=id,email,auth_user_id,is_active&order=email`,
    { headers },
  );
  if (!res.ok) {
    throw new Error(`List admins failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function createAuthUser(email, password) {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    // Already exists — look up by email
    if (
      res.status === 422 ||
      String(body?.msg || body?.message || '').toLowerCase().includes('already')
    ) {
      return { existing: true };
    }
    throw new Error(
      `Create user ${email} failed: ${res.status} ${JSON.stringify(body)}`,
    );
  }
  return { user: body };
}

async function findAuthUserIdByEmail(email) {
  const res = await fetch(
    `${SUPABASE_URL}/auth/v1/admin/users?page=1&per_page=200`,
    { headers },
  );
  if (!res.ok) {
    throw new Error(`List auth users failed: ${res.status}`);
  }
  const body = await res.json();
  const users = body.users || body || [];
  const hit = users.find(
    (u) => String(u.email || '').toLowerCase() === email.toLowerCase(),
  );
  return hit?.id || null;
}

async function linkAdmin(adminId, authUserId) {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/admins?id=eq.${encodeURIComponent(adminId)}`,
    {
      method: 'PATCH',
      headers: { ...headers, Prefer: 'return=minimal' },
      body: JSON.stringify({
        auth_user_id: authUserId,
        must_reset_password: true,
        updated_at: new Date().toISOString(),
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`Link ${adminId} failed: ${res.status} ${await res.text()}`);
  }
}

async function main() {
  console.log('Provisioning Supabase Auth users for admins…');
  console.log('Temp password (share securely):', TEMP_PASSWORD);
  const admins = await listAdmins();
  const created = [];

  for (const admin of admins) {
    const email = String(admin.email || '').trim().toLowerCase();
    if (!email) continue;
    if (admin.auth_user_id) {
      console.log(`  skip ${email} (already linked ${admin.auth_user_id})`);
      continue;
    }

    let authUserId = null;
    const result = await createAuthUser(email, TEMP_PASSWORD);
    if (result.user?.id) {
      authUserId = result.user.id;
      created.push(email);
    } else {
      authUserId = await findAuthUserIdByEmail(email);
    }
    if (!authUserId) {
      console.warn(`  ! could not resolve auth user for ${email}`);
      continue;
    }
    await linkAdmin(admin.id, authUserId);
    console.log(`  linked ${email} → ${authUserId}`);
  }

  console.log(`Done. New Auth users: ${created.length}`);
  console.log(
    'Admins should sign in with the temp password, then change it (must_reset_password).',
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
