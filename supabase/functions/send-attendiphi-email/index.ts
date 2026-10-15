import type { JWTPayload } from "jose";
import {
  ATTENDIPHI_LOGO_CID,
  sendSmtpMail,
  smtpErrorDetail,
  smtpUserMessage,
  SmtpConfigError,
} from "./smtp.ts";
import {
  attendiphiAdminRoleByAuthUserId,
  dataServiceRoleKey,
  dataSupabaseUrl,
  deleteSupabaseAuthUser,
  generateRecoveryActionLink,
  provisionAdminAuthUser,
  verifyAttendiphiAccessToken,
} from "./supabase_admin_auth.ts";

/** Inline CID logo embedded by smtp.ts (reliable in Gmail; no remote image fetch). */
const LOGO_SRC = `cid:${ATTENDIPHI_LOGO_CID}`;
const GENERIC_RESET_MESSAGE =
  "If an account exists for this email, a password reset link has been sent.";

const PRODUCTION_ORIGINS = new Set([
  "https://attendiphi.metaphi.in",
  "http://localhost",
  "http://127.0.0.1",
]);

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const RATE_WINDOW_MS = 15 * 60 * 1000;
const MAX_RESET_PER_EMAIL = 5;
const MAX_RESET_PER_IP = 20;

type EmailType = "admin_welcome" | "password_reset";

interface WelcomeBody {
  type?: string;
  action?: string;
  emailType?: string;
  email?: string;
  recipientEmail?: string;
  recipientName?: string;
  subject?: string;
  html?: string;
  password?: string;
  roleLabel?: string;
  portalUrl?: string;
  targetUid?: string;
  uid?: string;
  adminId?: string;
}

interface RateBucket {
  count: number;
  resetAt: number;
}

const resetEmailBuckets = new Map<string, RateBucket>();
const resetIpBuckets = new Map<string, RateBucket>();

Deno.serve(async (req) => {
  const origin = req.headers.get("origin") ?? "";
  const cors = corsHeaders(origin);

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: cors });
  }

  if (req.method !== "POST") {
    return json(405, { ok: false, error: "Method not allowed" }, cors);
  }

  if (origin && !isAllowedOrigin(origin)) {
    console.log("email_denied reason=cors status=403");
    return json(403, { ok: false, error: "Origin is not allowed" }, cors);
  }

  try {
    let body: WelcomeBody;
    try {
      body = await req.json();
    } catch {
      return json(400, { ok: false, error: "Invalid JSON body" }, cors);
    }

    const action = String(body.action ?? body.type ?? body.emailType ?? "").trim().toLowerCase();
    if (action === "delete_admin" || action === "delete_user") {
      return await handleDeleteAdmin(req, body, cors);
    }
    if (action === "provision_admin" || action === "create_auth_user") {
      return await handleProvisionAdmin(req, body, cors);
    }

    const emailType = ((body.emailType ?? body.type ?? "").trim()) as EmailType;
    if (emailType === "password_reset") {
      return await handlePasswordReset(req, body, cors);
    }

    return await handleAdminWelcome(req, body, cors);
  } catch (error) {
    console.log(`email_failed reason=unhandled status=500 detail=${errorName(error)}`);
    return json(500, { ok: false, error: "Could not process request" }, cors);
  }
});

async function handleDeleteAdmin(
  req: Request,
  body: WelcomeBody,
  cors: HeadersInit,
): Promise<Response> {
  const accessToken = bearerToken(req.headers.get("authorization"));
  if (!accessToken) {
    console.log("delete_admin_denied reason=missing_bearer status=401");
    return json(401, { ok: false, error: "Missing Supabase access token" }, cors);
  }

  let claims: JWTPayload;
  try {
    claims = await verifyAttendiphiAccessToken(accessToken);
  } catch (error) {
    console.log(
      `delete_admin_denied reason=invalid_supabase_token status=401 detail=${errorName(error)}`,
    );
    return json(401, { ok: false, error: "Invalid or expired Supabase session" }, cors);
  }

  const actorUid = String(claims.sub ?? "").trim();
  if (!actorUid) {
    return json(401, { ok: false, error: "Token is missing user identity" }, cors);
  }

  const role = await attendiphiAdminRoleByAuthUserId(actorUid);
  if (role !== "superadmin") {
    console.log(`delete_admin_denied reason=not_super_admin status=403 uid=${actorUid}`);
    return json(403, { ok: false, error: "Only Super Admin can delete Auth accounts" }, cors);
  }

  const targetUid = String(body.targetUid ?? body.uid ?? "").trim();
  const targetEmail = String(body.email ?? body.recipientEmail ?? "").trim().toLowerCase();

  if (!targetUid && !targetEmail) {
    return json(400, { ok: false, error: "targetUid or email is required to delete admin" }, cors);
  }

  if (targetUid && targetUid === actorUid) {
    return json(400, { ok: false, error: "You cannot delete your own admin account" }, cors);
  }

  try {
    const result = await deleteSupabaseAuthUser({
      targetUid,
      targetEmail,
    });
    if (result.targetUid && result.targetUid === actorUid) {
      return json(400, { ok: false, error: "You cannot delete your own admin account" }, cors);
    }
    console.log(
      `delete_admin_success targetUid=${result.targetUid ?? ""} actorUid=${actorUid}`,
    );
    return json(200, {
      ok: true,
      deleted: true,
      targetUid: result.targetUid,
      message: "Admin deleted from Supabase Authentication successfully.",
      note: result.note,
    }, cors);
  } catch (error) {
    console.log(`delete_admin_failed reason=unhandled detail=${errorName(error)}`);
    return json(500, {
      ok: false,
      error: "Could not delete user from Supabase Authentication.",
    }, cors);
  }
}

async function handleProvisionAdmin(
  req: Request,
  body: WelcomeBody,
  cors: HeadersInit,
): Promise<Response> {
  const accessToken = bearerToken(req.headers.get("authorization"));
  if (!accessToken) {
    return json(401, { ok: false, error: "Missing Supabase access token" }, cors);
  }

  let claims: JWTPayload;
  try {
    claims = await verifyAttendiphiAccessToken(accessToken);
  } catch (error) {
    console.log(
      `provision_admin_denied reason=invalid_supabase_token status=401 detail=${errorName(error)}`,
    );
    return json(401, { ok: false, error: "Invalid or expired Supabase session" }, cors);
  }

  const actorUid = String(claims.sub ?? "").trim();
  if (!actorUid) {
    return json(401, { ok: false, error: "Token is missing user identity" }, cors);
  }

  const role = await attendiphiAdminRoleByAuthUserId(actorUid);
  if (role !== "superadmin") {
    console.log(`provision_admin_denied reason=not_super_admin status=403 uid=${actorUid}`);
    return json(403, { ok: false, error: "Only Super Admin can provision Auth accounts" }, cors);
  }

  const email = String(body.email ?? body.recipientEmail ?? "").trim().toLowerCase();
  const password = String(body.password ?? "").trim();
  const adminId = String(body.adminId ?? body.targetUid ?? body.uid ?? "").trim();

  if (!EMAIL_RE.test(email)) {
    return json(400, { ok: false, error: "email is invalid" }, cors);
  }
  if (password.length < 6) {
    return json(400, { ok: false, error: "password must be at least 6 characters" }, cors);
  }

  try {
    const result = await provisionAdminAuthUser({
      email,
      password,
      adminId: adminId || undefined,
    });
    console.log(
      `provision_admin_success email=${email} authUserId=${result.authUserId} created=${result.created} actorUid=${actorUid}`,
    );
    return json(200, {
      ok: true,
      provisioned: true,
      created: result.created,
      authUserId: result.authUserId,
      message: result.created
        ? "Supabase Auth user created and linked."
        : "Supabase Auth user updated and linked.",
    }, cors);
  } catch (error) {
    console.log(`provision_admin_failed detail=${errorName(error)}`);
    return json(500, {
      ok: false,
      error: "Could not create Supabase Auth user for this admin.",
    }, cors);
  }
}

async function handlePasswordReset(
  req: Request,
  body: WelcomeBody,
  cors: HeadersInit,
): Promise<Response> {
  const email = String(body.email ?? body.recipientEmail ?? "").trim().toLowerCase();
  if (!EMAIL_RE.test(email)) {
    return json(400, { ok: false, error: "email is invalid" }, cors);
  }

  const ip = clientIp(req);
  // Persist limits across Edge isolates; fall back to in-memory on RPC failure.
  const emailLimited = await isResetRateLimited(`email:${email}`, MAX_RESET_PER_EMAIL);
  const ipLimited = await isResetRateLimited(`ip:${ip}`, MAX_RESET_PER_IP);
  if (emailLimited || ipLimited) {
    console.log("password_reset_denied reason=rate_limited status=429");
    return json(429, {
      ok: false,
      error: "Too many attempts. Please try again later.",
    }, cors);
  }

  // Always return the same message whether or not the account exists.
  const generic = json(200, {
    ok: true,
    emailType: "password_reset",
    message: GENERIC_RESET_MESSAGE,
  }, cors);

  const redirectTo = sanitizeResetRedirect(body.portalUrl);
  let actionLink = "";
  try {
    const generated = await generateRecoveryActionLink({
      email,
      redirectTo,
    });
    if ("notFound" in generated) {
      console.log("password_reset_accepted reason=unknown_account");
      return generic;
    }
    actionLink = generated.actionLink;
  } catch (error) {
    console.log(
      `password_reset_failed reason=link_generation detail=${errorName(error)}`,
    );
    return json(500, {
      ok: false,
      error: "Could not send a reset email. Please try again.",
    }, cors);
  }

  try {
    const sent = await sendSmtpMail({
      to: email,
      subject: "Reset your Attendiphi password",
      html: resetHtml(actionLink),
      text: resetText(),
      attachLogo: true,
    });
    console.log(
      `password_reset_success transport=smtp messageId=${sent.messageId} redirectTo=${redirectTo}`,
    );
    return generic;
  } catch (error) {
    console.log(
      `password_reset_failed reason=smtp detail=${smtpErrorDetail(error)}`,
    );
    if (error instanceof SmtpConfigError) {
      return json(500, {
        ok: false,
        error: smtpUserMessage(error),
      }, cors);
    }
    return json(502, {
      ok: false,
      error: smtpUserMessage(error),
    }, cors);
  }
}

/** Portal reset landing — must be allow-listed in Auth URL Configuration. */
function sanitizeResetRedirect(raw: unknown): string {
  const fallback = "https://attendiphi.metaphi.in/admin-reset-password";
  try {
    const portal = sanitizePortalUrl(raw);
    return `${new URL(portal).origin}/admin-reset-password`;
  } catch {
    return fallback;
  }
}

async function handleAdminWelcome(
  req: Request,
  body: WelcomeBody,
  cors: HeadersInit,
): Promise<Response> {
  const accessToken = bearerToken(req.headers.get("authorization"));
  if (!accessToken) {
    console.log("email_denied reason=missing_bearer status=401");
    return json(401, { ok: false, error: "Missing Supabase access token" }, cors);
  }

  let claims: JWTPayload;
  try {
    claims = await verifyAttendiphiAccessToken(accessToken);
  } catch (error) {
    console.log(
      `email_denied reason=invalid_supabase_token status=401 detail=${errorName(error)}`,
    );
    return json(401, { ok: false, error: "Invalid or expired Supabase session" }, cors);
  }

  const actorEmail = String(claims.email ?? "").trim().toLowerCase();
  const actorUid = String(claims.sub ?? "").trim();
  if (!actorUid) {
    console.log("email_denied reason=token_missing_identity status=401");
    return json(401, { ok: false, error: "Token is missing user identity" }, cors);
  }

  const role = await attendiphiAdminRoleByAuthUserId(actorUid);
  if (role !== "admin" && role !== "superadmin") {
    console.log(`email_denied reason=not_admin status=403 uid=${actorUid}`);
    return json(403, { ok: false, error: "Only Attendiphi administrators can send mail" }, cors);
  }

  const emailType = (body.emailType ?? "").trim() as EmailType;
  if (emailType !== "admin_welcome") {
    return json(400, { ok: false, error: "Unsupported emailType" }, cors);
  }

  const recipientEmail = (body.recipientEmail ?? "").trim().toLowerCase();
  const recipientName = (body.recipientName ?? "").trim() || "Admin";
  // Optional client password for Auth provision only — never emailed (P2).
  const password = (body.password ?? "").trim() || randomTempPassword();
  const roleLabel = (body.roleLabel ?? "Admin").trim() || "Admin";
  const portalUrl = sanitizePortalUrl(body.portalUrl);
  const subject = (body.subject ?? "").trim() ||
    "Attendiphi - Set up your admin login";

  if (!EMAIL_RE.test(recipientEmail)) {
    return json(400, { ok: false, error: "recipientEmail is invalid" }, cors);
  }

  // Ensure Auth login exists; password is not included in the email body.
  try {
    const provisioned = await provisionAdminAuthUser({
      email: recipientEmail,
      password,
      adminId: String(body.adminId ?? "").trim() || undefined,
    });
    console.log(
      `admin_welcome_provisioned authUserId=${provisioned.authUserId} created=${provisioned.created}`,
    );
  } catch (error) {
    console.log(
      `email_failed type=admin_welcome reason=auth_provision detail=${errorName(error)} actorUid=${actorUid}`,
    );
    return json(500, {
      ok: false,
      error: "Could not create the Auth login for this admin. Email was not sent.",
      adminCreated: true,
      emailSent: false,
    }, cors);
  }

  const redirectTo = sanitizeResetRedirect(portalUrl);
  let actionLink = "";
  try {
    const generated = await generateRecoveryActionLink({
      email: recipientEmail,
      redirectTo,
    });
    if ("notFound" in generated) {
      console.log(
        `email_failed type=admin_welcome reason=invite_link_user_missing`,
      );
      return json(500, {
        ok: false,
        error: "Could not create an invite link for this admin.",
        adminCreated: true,
        emailSent: false,
      }, cors);
    }
    actionLink = generated.actionLink;
  } catch (error) {
    console.log(
      `email_failed type=admin_welcome reason=invite_link detail=${errorName(error)}`,
    );
    return json(500, {
      ok: false,
      error: "Could not create an invite link. Email was not sent.",
      adminCreated: true,
      emailSent: false,
    }, cors);
  }

  const html = welcomeHtml({
    name: recipientName,
    email: recipientEmail,
    actionLink,
    roleLabel,
    portalUrl,
  });
  const text = welcomeText({
    name: recipientName,
    email: recipientEmail,
    actionLink,
    roleLabel,
    portalUrl,
  });

  try {
    const sent = await sendSmtpMail({
      to: recipientEmail,
      subject,
      html,
      text,
    });
    console.log(
      `email_success type=admin_welcome transport=smtp messageId=${sent.messageId} actorUid=${actorUid}`,
    );
    return json(200, {
      ok: true,
      emailType,
      id: sent.messageId,
      adminCreated: true,
      emailSent: true,
    }, cors);
  } catch (error) {
    console.log(
      `email_failed type=admin_welcome reason=smtp detail=${smtpErrorDetail(error)} actorUid=${actorUid}`,
    );
    const status = error instanceof SmtpConfigError ? 500 : 502;
    return json(status, {
      ok: false,
      error: smtpUserMessage(error),
      adminCreated: true,
      emailSent: false,
    }, cors);
  }
}

function isAllowedOrigin(origin: string): boolean {
  if (PRODUCTION_ORIGINS.has(origin)) return true;
  try {
    const url = new URL(origin);
    const local = url.hostname === "localhost" || url.hostname === "127.0.0.1";
    return local && (url.protocol === "http:" || url.protocol === "https:");
  } catch {
    return false;
  }
}

function corsHeaders(origin: string): HeadersInit {
  const allowOrigin = isAllowedOrigin(origin) ? origin : [...PRODUCTION_ORIGINS][0];
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

function json(status: number, payload: Record<string, unknown>, cors: HeadersInit) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...cors,
      "Content-Type": "application/json",
    },
  });
}

function bearerToken(header: string | null): string {
  if (!header) return "";
  const match = header.match(/^Bearer\s+(\S+)/i);
  return match?.[1]?.trim() ?? "";
}

function clientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for") ?? "";
  const first = forwarded.split(",")[0]?.trim();
  if (first) return first;
  return req.headers.get("cf-connecting-ip")?.trim() || "unknown";
}

function isRateLimited(
  buckets: Map<string, RateBucket>,
  key: string,
  max: number,
): boolean {
  const now = Date.now();
  const current = buckets.get(key);
  if (!current || now >= current.resetAt) {
    buckets.set(key, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return false;
  }
  current.count += 1;
  return current.count > max;
}

/** Persisted rate limit via SECURITY DEFINER RPC (service role). */
async function isResetRateLimited(key: string, max: number): Promise<boolean> {
  const memoryBuckets = key.startsWith("ip:")
    ? resetIpBuckets
    : resetEmailBuckets;
  try {
    const res = await fetch(
      `${dataSupabaseUrl()}/rest/v1/rpc/bump_email_rate_limit`,
      {
        method: "POST",
        headers: {
          apikey: dataServiceRoleKey(),
          Authorization: `Bearer ${dataServiceRoleKey()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_bucket_key: key,
          p_max_hits: max,
          p_window_seconds: Math.floor(RATE_WINDOW_MS / 1000),
        }),
      },
    );
    if (!res.ok) {
      console.log(
        `rate_limit_rpc_fallback status=${res.status} key_prefix=${key.split(":")[0]}`,
      );
      return isRateLimited(memoryBuckets, key, max);
    }
    const limited = await res.json();
    return limited === true;
  } catch (error) {
    console.log(
      `rate_limit_rpc_error detail=${errorName(error)} key_prefix=${key.split(":")[0]}`,
    );
    return isRateLimited(memoryBuckets, key, max);
  }
}

function sanitizePortalUrl(raw: unknown): string {
  const fallback = "https://attendiphi.metaphi.in/";
  if (typeof raw !== "string") return fallback;
  try {
    const url = new URL(raw.trim());
    if (url.protocol !== "https:" && url.protocol !== "http:") return fallback;
    const allowedHosts = new Set([
      "attendiphi.metaphi.in",
      "localhost",
      "127.0.0.1",
    ]);
    if (!allowedHosts.has(url.hostname)) return fallback;
    return url.toString();
  } catch {
    return fallback;
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function resetText(): string {
  return `Hello,

We received a request to reset the password for your Attendiphi account.

Open the Reset Password button in the HTML version of this email to create a new password.

If you did not request a password reset, you can safely ignore this email.

For your security, never share your password or this reset link with anyone.

Thanks,
The Attendiphi Team

Attendiphi by Metaphi
`;
}

function resetHtml(resetUrl: string): string {
  const safeUrl = escapeHtml(resetUrl);
  // Branded layout matching Attendiphi credentials / reset mail (purple header).
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#eef2ff;margin:0;padding:24px;color:#1e293b;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e2e8f0;box-shadow:0 8px 24px rgba(15,23,42,0.06);">
    <div style="background:#4f46e5;padding:36px 24px;text-align:center;">
      <img src="${LOGO_SRC}" alt="Attendiphi by Metaphi" width="180" style="max-width:180px;height:auto;margin:0 auto;display:block;border:0;" />
    </div>
    <div style="padding:32px 28px 28px;">
      <h1 style="margin:0 0 20px;font-size:24px;font-weight:700;color:#0f172a;line-height:1.3;">Reset your password</h1>
      <p style="margin:0 0 12px;font-size:15px;color:#334155;line-height:1.6;">Hello,</p>
      <p style="margin:0 0 12px;font-size:15px;color:#334155;line-height:1.6;">
        We received a request to reset the password for your Attendiphi account.
      </p>
      <p style="margin:0 0 8px;font-size:15px;color:#334155;line-height:1.6;">
        Click the button below to create a new password.
      </p>
      <p style="text-align:center;margin:28px 0 24px;">
        <a href="${safeUrl}" style="display:inline-block;background:#4f46e5;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:10px;font-weight:700;font-size:15px;">Reset Password</a>
      </p>
      <p style="margin:0 0 10px;font-size:13px;color:#64748b;line-height:1.6;">
        If you did not request a password reset, you can safely ignore this email.
      </p>
      <p style="margin:0 0 24px;font-size:13px;color:#64748b;line-height:1.6;">
        For your security, never share your password or this reset link with anyone.
      </p>
      <p style="margin:0;font-size:14px;color:#334155;line-height:1.6;">
        Thanks,<br>The Attendiphi Team
      </p>
      <p style="margin:20px 0 0;font-size:12px;color:#94a3b8;">Attendiphi by Metaphi</p>
    </div>
  </div>
</body>
</html>`;
}

function randomTempPassword(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function welcomeText(input: {
  name: string;
  email: string;
  actionLink: string;
  roleLabel: string;
  portalUrl: string;
}): string {
  return `Hello ${input.name},

You have been granted ${input.roleLabel} access to the Attendiphi QR Check-in portal.

Open this secure link to set your password (it expires after a short time):
${input.actionLink}

Portal: ${input.portalUrl}
Login email: ${input.email}

If you did not expect this email, you can ignore it.

Best regards,
Attendiphi Super Admin
`;
}

function welcomeHtml(input: {
  name: string;
  email: string;
  actionLink: string;
  roleLabel: string;
  portalUrl: string;
}): string {
  const safeLink = escapeHtml(input.actionLink);
  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#f8fafc;margin:0;padding:24px;color:#1e293b;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e2e8f0;">
    <div style="background:#ffffff;padding:24px 24px 20px;text-align:center;border-bottom:1px solid #e2e8f0;">
      <img src="${LOGO_SRC}" alt="Attendiphi" width="160" style="max-height:72px;width:auto;height:auto;display:inline-block;border:0;" />
      <p style="margin:12px 0 0;font-size:13px;color:#64748b;">QR Check-in &amp; Attendance Portal</p>
    </div>
    <div style="padding:28px 24px;">
      <p style="font-size:16px;font-weight:600;">Hello ${escapeHtml(input.name)},</p>
      <p style="font-size:14px;color:#475569;line-height:1.6;">
        You have been granted <strong>${escapeHtml(input.roleLabel)}</strong> access to Attendiphi.
      </p>
      <p style="font-size:14px;color:#475569;line-height:1.6;">
        Click the button below to set your own password. We never email passwords in plaintext.
      </p>
      <p style="text-align:center;margin:28px 0 24px;">
        <a href="${safeLink}" style="display:inline-block;background:#4f46e5;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:10px;font-weight:700;font-size:15px;">Set your password</a>
      </p>
      <div style="background:#f1f5f9;border-radius:12px;padding:18px;border:1px solid #cbd5e1;margin-bottom:24px;font-size:13.5px;">
        <p><strong>Portal URL:</strong> <a href="${escapeHtml(input.portalUrl)}">${escapeHtml(input.portalUrl)}</a></p>
        <p><strong>Login Email:</strong> ${escapeHtml(input.email)}</p>
        <p><strong>Access Role:</strong> ${escapeHtml(input.roleLabel)}</p>
      </div>
      <p style="font-size:13px;color:#64748b;">If you did not expect this email, you can ignore it.</p>
      <p style="font-size:13px;">Best regards,<br/>Attendiphi Super Admin</p>
    </div>
  </div>
</body>
</html>`;
}

function errorName(error: unknown): string {
  if (error instanceof Error) return error.name || "Error";
  return "unknown";
}
