/**
 * Attendiphi Auth + admins lookup for the email Edge Function.
 *
 * Prefer same-project secrets (auto-injected when the function is deployed on
 * `fzghxzybyygslfjyfewu`):
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *   SUPABASE_ANON_KEY
 *
 * Optional overrides (legacy bridge from a separate email project):
 *   ATTENDIPHI_DATA_SUPABASE_URL
 *   ATTENDIPHI_DATA_SERVICE_ROLE_KEY
 *   ATTENDIPHI_DATA_JWT_SECRET
 */
import { jwtVerify, type JWTPayload } from "jose";

export function dataSupabaseUrl(): string {
  return (
    Deno.env.get("ATTENDIPHI_DATA_SUPABASE_URL") ??
    Deno.env.get("SUPABASE_URL") ??
    "https://fzghxzybyygslfjyfewu.supabase.co"
  ).replace(/\/$/, "");
}

export function dataServiceRoleKey(): string {
  const key = (
    Deno.env.get("ATTENDIPHI_DATA_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    ""
  ).trim();
  if (!key) throw new Error("missing_data_service_role");
  return key;
}

/**
 * Prefer Auth `/user` (works with JWT secret or asymmetric signing keys).
 * Fall back to local HS256 verify when a JWT secret is set.
 */
export async function verifyAttendiphiAccessToken(
  token: string,
): Promise<JWTPayload> {
  const viaAuthApi = await verifyViaAuthUser(token);
  if (viaAuthApi) return viaAuthApi;

  const secret = (
    Deno.env.get("ATTENDIPHI_DATA_JWT_SECRET") ??
    Deno.env.get("JWT_SECRET") ??
    ""
  ).trim();
  if (!secret) throw new Error("invalid_supabase_token");

  const { payload } = await jwtVerify(
    token,
    new TextEncoder().encode(secret),
    {
      algorithms: ["HS256"],
      audience: "authenticated",
      clockTolerance: 5,
    },
  );
  if (!payload.sub) throw new Error("missing_sub");
  return payload;
}

async function verifyViaAuthUser(token: string): Promise<JWTPayload | null> {
  try {
    const url = dataSupabaseUrl();
    const key = (
      Deno.env.get("ATTENDIPHI_DATA_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SB_PUBLISHABLE_KEY") ??
      ""
    ).trim();
    if (!key) return null;

    const res = await fetch(`${url}/auth/v1/user`, {
      headers: {
        apikey: key,
        Authorization: `Bearer ${token}`,
      },
    });
    if (!res.ok) return null;
    const user = await res.json() as { id?: string; email?: string };
    const sub = (user.id ?? "").trim();
    if (!sub) return null;
    return {
      sub,
      email: (user.email ?? "").trim().toLowerCase() || undefined,
      role: "authenticated",
      aud: "authenticated",
    };
  } catch {
    return null;
  }
}

export async function attendiphiAdminRoleByAuthUserId(
  authUserId: string,
): Promise<string | null> {
  const url = dataSupabaseUrl();
  const key = dataServiceRoleKey();
  const q = new URLSearchParams({
    select: "role,is_active,auth_user_id,id,email",
    or: `(auth_user_id.eq.${authUserId},id.eq.${authUserId})`,
    limit: "1",
  });
  const res = await fetch(`${url}/rest/v1/admins?${q}`, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
    },
  });
  if (!res.ok) {
    console.log(`admin_role_lookup_failed status=${res.status}`);
    return null;
  }
  const rows = await res.json() as Array<{
    role?: string;
    is_active?: boolean;
  }>;
  if (!Array.isArray(rows) || rows.length === 0) return null;
  if (rows[0].is_active === false) return null;
  return (rows[0].role ?? "").trim().toLowerCase() || null;
}

/**
 * Creates (or updates password for) a Supabase Auth user and links
 * `public.admins.auth_user_id`.
 */
export async function provisionAdminAuthUser(params: {
  email: string;
  password: string;
  adminId?: string;
}): Promise<{ authUserId: string; created: boolean }> {
  const url = dataSupabaseUrl();
  const key = dataServiceRoleKey();
  const email = params.email.trim().toLowerCase();
  const password = params.password;
  if (!email || password.length < 6) {
    throw new Error("invalid_provision_input");
  }

  let authUserId = "";
  let created = false;

  const createRes = await fetch(`${url}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
    }),
  });
  const createBody = await createRes.json().catch(() => ({})) as {
    id?: string;
    msg?: string;
    message?: string;
  };

  if (createRes.ok && createBody.id) {
    authUserId = createBody.id;
    created = true;
  } else {
    const msg = String(createBody.msg ?? createBody.message ?? "").toLowerCase();
    const already =
      createRes.status === 422 ||
      msg.includes("already") ||
      msg.includes("registered");
    if (!already) {
      throw new Error(
        `auth_create_failed:${createRes.status}:${JSON.stringify(createBody)}`,
      );
    }
    authUserId = await findAuthUserIdByEmail(url, key, email);
    if (!authUserId) {
      throw new Error("auth_user_exists_but_not_found");
    }
    const upd = await fetch(
      `${url}/auth/v1/admin/users/${encodeURIComponent(authUserId)}`,
      {
        method: "PUT",
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          password,
          email_confirm: true,
        }),
      },
    );
    if (!upd.ok) {
      const errText = await upd.text();
      throw new Error(`auth_password_update_failed:${upd.status}:${errText}`);
    }
  }

  const adminId = (params.adminId ?? "").trim();
  if (adminId) {
    await linkAdminAuthUserId(url, key, adminId, authUserId);
  } else {
    await linkAdminAuthUserIdByEmail(url, key, email, authUserId);
  }

  return { authUserId, created };
}

async function linkAdminAuthUserId(
  url: string,
  key: string,
  adminId: string,
  authUserId: string,
): Promise<void> {
  const res = await fetch(
    `${url}/rest/v1/admins?id=eq.${encodeURIComponent(adminId)}`,
    {
      method: "PATCH",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        auth_user_id: authUserId,
        updated_at: new Date().toISOString(),
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`link_admin_failed:${res.status}:${await res.text()}`);
  }
}

async function linkAdminAuthUserIdByEmail(
  url: string,
  key: string,
  email: string,
  authUserId: string,
): Promise<void> {
  const res = await fetch(
    `${url}/rest/v1/admins?email=eq.${encodeURIComponent(email)}`,
    {
      method: "PATCH",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        auth_user_id: authUserId,
        updated_at: new Date().toISOString(),
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`link_admin_by_email_failed:${res.status}:${await res.text()}`);
  }
}

/** Creates a recovery action_link for [email] (Auth Admin API). */
export async function generateRecoveryActionLink(params: {
  email: string;
  redirectTo: string;
}): Promise<{ actionLink: string } | { notFound: true }> {
  const url = dataSupabaseUrl();
  const key = dataServiceRoleKey();
  const email = params.email.trim().toLowerCase();
  const redirectTo = params.redirectTo.trim();

  const res = await fetch(`${url}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      type: "recovery",
      email,
      redirect_to: redirectTo,
    }),
  });

  const body = await res.json().catch(() => ({})) as Record<string, unknown>;
  if (!res.ok) {
    const msg = String(
      body.msg ?? body.message ?? body.error_description ?? body.error ?? "",
    ).toLowerCase();
    if (
      res.status === 404 ||
      msg.includes("not found") ||
      msg.includes("user not found") ||
      msg.includes("unable to find")
    ) {
      return { notFound: true };
    }
    throw new Error(
      `generate_recovery_link_failed:${res.status}:${JSON.stringify(body)}`,
    );
  }

  const props = (body.properties ?? body) as Record<string, unknown>;
  const actionLink = String(
    props.action_link ?? body.action_link ?? "",
  ).trim();
  if (!actionLink) {
    throw new Error("generate_recovery_link_missing_action_link");
  }
  return { actionLink };
}

export async function deleteSupabaseAuthUser(params: {
  targetUid?: string;
  targetEmail?: string;
}): Promise<{ deleted: boolean; targetUid?: string; note?: string }> {
  const url = dataSupabaseUrl();
  const key = dataServiceRoleKey();
  let uid = (params.targetUid ?? "").trim();
  const email = (params.targetEmail ?? "").trim().toLowerCase();

  // Prefer email resolution: admins.id / legacy uid may be Firebase-style ids,
  // not auth.users UUIDs.
  if (email) {
    const byEmail = await findAuthUserIdByEmail(url, key, email);
    if (byEmail) uid = byEmail;
  }

  if (!uid || !isUuid(uid)) {
    return {
      deleted: true,
      note: "Account was not found in Supabase Auth",
    };
  }

  const del = await fetch(`${url}/auth/v1/admin/users/${encodeURIComponent(uid)}`, {
    method: "DELETE",
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
    },
  });
  if (del.ok || del.status === 404) {
    return { deleted: true, targetUid: uid };
  }
  const errText = await del.text();
  throw new Error(`supabase_auth_delete_failed:${del.status}:${errText}`);
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value.trim());
}

async function findAuthUserIdByEmail(
  url: string,
  key: string,
  email: string,
): Promise<string> {
  const list = await fetch(
    `${url}/auth/v1/admin/users?page=1&per_page=200`,
    {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
      },
    },
  );
  if (!list.ok) return "";
  const data = await list.json() as {
    users?: Array<{ id?: string; email?: string }>;
  };
  const match = (data.users ?? []).find(
    (u) => (u.email ?? "").toLowerCase() === email,
  );
  return (match?.id ?? "").trim();
}
