import { jwtVerify, createRemoteJWKSet, SignJWT, importPKCS8, type JWTPayload } from "jose";
import {
  ATTENDIPHI_LOGO_CID,
  sendSmtpMail,
  smtpErrorDetail,
  smtpUserMessage,
  SmtpConfigError,
} from "./smtp.ts";

const FIREBASE_PROJECT_ID = "qr-checkin-dev";
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const IDENTITY_TOOLKIT_OOB_URL =
  `https://identitytoolkit.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/accounts:sendOobCode`;
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const RESET_CONTINUE_URL =
  "https://attendiphi-by-metaphi.web.app/admin-reset-password";
/** Inline CID logo embedded by smtp.ts (reliable in Gmail; no remote image fetch). */
const LOGO_SRC = `cid:${ATTENDIPHI_LOGO_CID}`;
const GENERIC_RESET_MESSAGE =
  "If an account exists for this email, a password reset link has been sent.";

const JWKS = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

const PRODUCTION_ORIGINS = new Set([
  "https://attendiphi-by-metaphi.web.app",
  "https://attendiphi.metaphi.in",
]);

const FIRESTORE_DOC_BASE =
  `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents`;

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
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

interface RateBucket {
  count: number;
  resetAt: number;
}

const resetEmailBuckets = new Map<string, RateBucket>();
const resetIpBuckets = new Map<string, RateBucket>();
let cachedGoogleToken: { value: string; exp: number } | null = null;

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
  const firebaseToken = bearerToken(req.headers.get("authorization"));
  if (!firebaseToken) {
    console.log("delete_admin_denied reason=missing_bearer status=401");
    return json(401, { ok: false, error: "Missing Firebase ID token" }, cors);
  }

  let claims: JWTPayload;
  try {
    claims = await verifyFirebaseIdToken(firebaseToken);
  } catch (error) {
    console.log(
      `delete_admin_denied reason=invalid_firebase_token status=401 detail=${errorName(error)}`,
    );
    return json(401, { ok: false, error: "Invalid or expired Firebase ID token" }, cors);
  }

  const actorUid = String(claims.sub ?? claims.user_id ?? "").trim();
  if (!actorUid) {
    return json(401, { ok: false, error: "Firebase token is missing user identity" }, cors);
  }

  const isAdmin = await assertAttendiphiAdmin(firebaseToken, actorUid);
  if (!isAdmin) {
    console.log(`delete_admin_denied reason=not_admin status=403 uid=${actorUid}`);
    return json(403, { ok: false, error: "Only Attendiphi administrators can delete accounts" }, cors);
  }

  let targetUid = String(body.targetUid ?? body.uid ?? "").trim();
  const targetEmail = String(body.email ?? body.recipientEmail ?? "").trim().toLowerCase();

  if (!targetUid && !targetEmail) {
    return json(400, { ok: false, error: "targetUid or email is required to delete admin" }, cors);
  }

  if (targetUid && targetUid === actorUid) {
    return json(400, { ok: false, error: "You cannot delete your own admin account" }, cors);
  }

  let accessToken: string;
  try {
    accessToken = await googleAccessToken();
  } catch (error) {
    console.log(`delete_admin_failed reason=google_token detail=${errorName(error)}`);
    return json(500, {
      ok: false,
      error: "Authentication service configuration error (missing service account credentials).",
    }, cors);
  }

  // If targetUid is missing or if we need to resolve it by email:
  if (!targetUid && targetEmail) {
    try {
      const lookupRes = await fetch(
        `https://identitytoolkit.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/accounts:lookup`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ email: [targetEmail] }),
        },
      );
      if (lookupRes.ok) {
        const lookupData = await lookupRes.json();
        const users = lookupData?.users;
        if (Array.isArray(users) && users.length > 0 && users[0].localId) {
          targetUid = users[0].localId;
        }
      }
    } catch (e) {
      console.log(`delete_admin_lookup_failed detail=${errorName(e)}`);
    }
  }

  if (!targetUid) {
    // If not found in Auth by email, it is already deleted or never existed.
    console.log(`delete_admin_success reason=not_found_by_email email=${targetEmail}`);
    return json(200, {
      ok: true,
      deleted: true,
      note: "Account was not found in Firebase Authentication",
    }, cors);
  }

  if (targetUid === actorUid) {
    return json(400, { ok: false, error: "You cannot delete your own admin account" }, cors);
  }

  try {
    const deleteRes = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/accounts:delete`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ localId: targetUid }),
      },
    );

    if (deleteRes.ok) {
      console.log(`delete_admin_success targetUid=${targetUid} actorUid=${actorUid}`);
      return json(200, {
        ok: true,
        deleted: true,
        targetUid,
        message: "Admin deleted from Firebase Authentication successfully.",
      }, cors);
    }

    const errData = await deleteRes.json().catch(() => ({}));
    const errCode = (errData?.error?.message as string) || "";
    if (errCode === "USER_NOT_FOUND") {
      console.log(`delete_admin_success reason=user_not_found targetUid=${targetUid}`);
      return json(200, {
        ok: true,
        deleted: true,
        targetUid,
        note: "User was already not in Firebase Authentication.",
      }, cors);
    }

    console.log(`delete_admin_failed status=${deleteRes.status} detail=${errCode}`);
    return json(deleteRes.status, {
      ok: false,
      error: `Firebase Auth error: ${errCode || deleteRes.statusText}`,
    }, cors);
  } catch (error) {
    console.log(`delete_admin_failed reason=unhandled detail=${errorName(error)}`);
    return json(500, {
      ok: false,
      error: "Could not delete user from Firebase Authentication.",
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
  if (isRateLimited(resetEmailBuckets, `email:${email}`, MAX_RESET_PER_EMAIL) ||
    isRateLimited(resetIpBuckets, `ip:${ip}`, MAX_RESET_PER_IP)) {
    console.log("password_reset_denied reason=rate_limited status=429");
    return json(429, {
      ok: false,
      error: "Too many attempts. Please try again later.",
    }, cors);
  }

  const generic = json(200, {
    ok: true,
    emailType: "password_reset",
    message: GENERIC_RESET_MESSAGE,
  }, cors);

  let oobLink = "";
  try {
    oobLink = await generateFirebasePasswordResetLink(email);
  } catch (error) {
    const code = identityErrorCode(error);
    if (code === "EMAIL_NOT_FOUND" || code === "USER_NOT_FOUND") {
      console.log("password_reset_accepted reason=unknown_account");
      return generic;
    }
    if (
      code === "missing_service_account" ||
      code === "invalid_service_account" ||
      code === "google_token_failed"
    ) {
      console.log(
        `password_reset_failed reason=link_generation detail=${code}`,
      );
      return json(500, {
        ok: false,
        error:
          "Password reset is not configured. Set a valid FIREBASE_SERVICE_ACCOUNT_JSON secret for project qr-checkin-dev, then redeploy is not required.",
      }, cors);
    }
    console.log(
      `password_reset_failed reason=link_generation detail=${code || errorName(error)}`,
    );
    return json(500, {
      ok: false,
      error: "Could not send a reset email. Please try again.",
    }, cors);
  }

  let resetUrl = "";
  try {
    resetUrl = flutterResetUrlFromFirebaseOobLink(oobLink);
  } catch {
    console.log("password_reset_failed reason=malformed_oob_link");
    return json(500, { ok: false, error: "Could not send a reset email. Please try again." }, cors);
  }

  try {
    const sent = await sendSmtpMail({
      to: email,
      subject: "Reset your Attendiphi password",
      html: resetHtml(resetUrl),
      text: resetText(),
    });
    console.log(
      `password_reset_success transport=smtp messageId=${sent.messageId}`,
    );
    return generic;
  } catch (error) {
    console.log(
      `password_reset_failed reason=smtp detail=${smtpErrorDetail(error)}`,
    );
    // Do not reveal whether the account exists; still surface a soft failure
    // so locked-out users know to retry if SMTP is down.
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

async function handleAdminWelcome(
  req: Request,
  body: WelcomeBody,
  cors: HeadersInit,
): Promise<Response> {
  const firebaseToken = bearerToken(req.headers.get("authorization"));
  if (!firebaseToken) {
    console.log("email_denied reason=missing_bearer status=401");
    return json(401, { ok: false, error: "Missing Firebase ID token" }, cors);
  }

  let claims: JWTPayload;
  try {
    claims = await verifyFirebaseIdToken(firebaseToken);
  } catch (error) {
    console.log(
      `email_denied reason=invalid_firebase_token status=401 detail=${errorName(error)}`,
    );
    return json(401, { ok: false, error: "Invalid or expired Firebase ID token" }, cors);
  }

  const actorEmail = String(claims.email ?? "").trim().toLowerCase();
  const actorUid = String(claims.sub ?? claims.user_id ?? "").trim();
  if (!actorEmail || !actorUid) {
    console.log("email_denied reason=token_missing_identity status=401");
    return json(401, { ok: false, error: "Firebase token is missing user identity" }, cors);
  }

  const isAdmin = await assertAttendiphiAdmin(firebaseToken, actorUid);
  if (!isAdmin) {
    console.log(`email_denied reason=not_admin status=403 uid=${actorUid}`);
    return json(403, { ok: false, error: "Only Attendiphi administrators can send mail" }, cors);
  }

  const emailType = (body.emailType ?? "").trim() as EmailType;
  if (emailType !== "admin_welcome") {
    return json(400, { ok: false, error: "Unsupported emailType" }, cors);
  }

  const recipientEmail = (body.recipientEmail ?? "").trim().toLowerCase();
  const recipientName = (body.recipientName ?? "").trim() || "Admin";
  const password = (body.password ?? "").trim();
  const roleLabel = (body.roleLabel ?? "Admin").trim() || "Admin";
  const portalUrl = sanitizePortalUrl(body.portalUrl);
  const subject = (body.subject ?? "").trim() ||
    "Attendiphi - Your QR Check-in Admin Login Credentials";

  if (!EMAIL_RE.test(recipientEmail)) {
    return json(400, { ok: false, error: "recipientEmail is invalid" }, cors);
  }
  if (!password) {
    return json(400, { ok: false, error: "password is required for admin_welcome" }, cors);
  }

  const html = welcomeHtml({
    name: recipientName,
    email: recipientEmail,
    password,
    roleLabel,
    portalUrl,
  });
  const text = welcomeText({
    name: recipientName,
    email: recipientEmail,
    password,
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

async function verifyFirebaseIdToken(token: string): Promise<JWTPayload> {
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: FIREBASE_ISSUER,
    audience: FIREBASE_PROJECT_ID,
    clockTolerance: 5,
  });
  if (!payload.sub) {
    throw new Error("missing_sub");
  }
  return payload;
}

async function assertAttendiphiAdmin(
  firebaseIdToken: string,
  uid: string,
): Promise<boolean> {
  const response = await fetch(
    `${FIRESTORE_DOC_BASE}/admins/${encodeURIComponent(uid)}`,
    {
      headers: { Authorization: `Bearer ${firebaseIdToken}` },
    },
  );
  if (!response.ok) {
    console.log(`email_denied reason=firestore_lookup status=${response.status}`);
    return false;
  }
  const doc = await response.json() as {
    fields?: { isActive?: { booleanValue?: boolean }; role?: { stringValue?: string } };
  };
  if (doc.fields?.isActive?.booleanValue === false) return false;
  const role = (doc.fields?.role?.stringValue ?? "").trim().toLowerCase();
  return role === "admin" || role === "superadmin";
}

function sanitizePortalUrl(raw: unknown): string {
  const fallback = "https://attendiphi-by-metaphi.web.app/";
  if (typeof raw !== "string") return fallback;
  try {
    const url = new URL(raw.trim());
    if (url.protocol !== "https:" && url.protocol !== "http:") return fallback;
    const allowedHosts = new Set([
      "attendiphi-by-metaphi.web.app",
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

function readServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")?.trim() ?? "";
  const encoded = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON_BASE64")?.trim() ?? "";
  const jsonText = raw || (encoded ? atob(encoded) : "");
  // Empty string / placeholder secrets fail Forgot Password before SMTP runs.
  if (!jsonText || jsonText.length < 32) {
    throw new Error("missing_service_account");
  }
  let parsed: ServiceAccount;
  try {
    parsed = JSON.parse(jsonText) as ServiceAccount;
  } catch {
    throw new Error("invalid_service_account");
  }
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error("invalid_service_account");
  }
  return parsed;
}

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedGoogleToken && cachedGoogleToken.exp - 60 > now) {
    return cachedGoogleToken.value;
  }
  const account = readServiceAccount();
  const pem = account.private_key.replaceAll("\\n", "\n");
  const key = await importPKCS8(pem, "RS256");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/identitytoolkit",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience(account.token_uri || GOOGLE_TOKEN_URL)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const tokenResponse = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const payload = await tokenResponse.json().catch(() => ({}));
  const accessToken = typeof payload.access_token === "string" ? payload.access_token : "";
  if (!tokenResponse.ok || !accessToken) {
    throw new Error("google_token_failed");
  }
  cachedGoogleToken = { value: accessToken, exp: now + 3300 };
  return accessToken;
}

async function generateFirebasePasswordResetLink(email: string): Promise<string> {
  const accessToken = await googleAccessToken();
  const response = await fetch(IDENTITY_TOOLKIT_OOB_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      requestType: "PASSWORD_RESET",
      email,
      returnOobLink: true,
      continueUrl: RESET_CONTINUE_URL,
      canHandleCodeInApp: false,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error("identity_toolkit_failed");
    (error as Error & { identityCode?: string }).identityCode =
      String(payload?.error?.message ?? "").split(":")[0]?.trim();
    throw error;
  }
  const oobLink = typeof payload.oobLink === "string" ? payload.oobLink : "";
  if (!oobLink) {
    throw new Error("missing_oob_link");
  }
  return oobLink;
}

function identityErrorCode(error: unknown): string {
  if (error && typeof error === "object" && "identityCode" in error) {
    return String((error as { identityCode?: string }).identityCode ?? "");
  }
  if (error instanceof Error) return error.message;
  return "";
}

function flutterResetUrlFromFirebaseOobLink(oobLink: string): string {
  const uri = new URL(oobLink);
  const oobCode = uri.searchParams.get("oobCode")?.trim() ?? "";
  const apiKey = uri.searchParams.get("apiKey")?.trim() ?? "";
  if (!oobCode) {
    throw new Error("missing_oob_code");
  }
  const landing = new URL(RESET_CONTINUE_URL);
  landing.searchParams.set("mode", "resetPassword");
  landing.searchParams.set("oobCode", oobCode);
  if (apiKey) landing.searchParams.set("apiKey", apiKey);
  return landing.toString();
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
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#f8fafc;margin:0;padding:24px;color:#1e293b;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e2e8f0;">
    <div style="background:#ffffff;padding:28px 24px;text-align:center;border-bottom:1px solid #e2e8f0;">
      <img src="${LOGO_SRC}" alt="Attendiphi" width="160" style="max-width:160px;height:auto;margin:0 auto 12px;display:block;border:0;" />
      <p style="margin:0;font-size:13px;color:#64748b;">Attendiphi by Metaphi</p>
    </div>
    <div style="padding:28px 24px;">
      <h1 style="margin:0 0 16px;font-size:22px;color:#0f172a;">Reset your password</h1>
      <p style="font-size:15px;color:#334155;line-height:1.6;">Hello,</p>
      <p style="font-size:15px;color:#334155;line-height:1.6;">
        We received a request to reset the password for your Attendiphi account.
      </p>
      <p style="font-size:15px;color:#334155;line-height:1.6;">
        Click the button below to create a new password.
      </p>
      <p style="text-align:center;margin:28px 0;">
        <a href="${safeUrl}" style="display:inline-block;background:#4f46e5;color:#ffffff;text-decoration:none;padding:14px 28px;border-radius:10px;font-weight:600;font-size:15px;">Reset Password</a>
      </p>
      <p style="font-size:13px;color:#64748b;line-height:1.6;">
        If you did not request a password reset, you can safely ignore this email.
      </p>
      <p style="font-size:13px;color:#64748b;line-height:1.6;">
        For your security, never share your password or this reset link with anyone.
      </p>
      <p style="font-size:13px;color:#334155;margin-top:24px;">
        Thanks,<br>The Attendiphi Team
      </p>
      <p style="font-size:12px;color:#94a3b8;">Attendiphi by Metaphi</p>
    </div>
  </div>
</body>
</html>`;
}

function welcomeText(input: {
  name: string;
  email: string;
  password: string;
  roleLabel: string;
  portalUrl: string;
}): string {
  return `Hello ${input.name},

You have been granted Administrator access to the QR Check-in & Attendance Portal.

Your Login Credentials:
────────────────────────────────────
• Portal URL: ${input.portalUrl}
• Login Email (ID): ${input.email}
• Password: ${input.password}
• Access Role: ${input.roleLabel}
────────────────────────────────────

Please sign in using the Portal URL above and keep your login credentials secure.

Best regards,
Super Admin
`;
}

function welcomeHtml(input: {
  name: string;
  email: string;
  password: string;
  roleLabel: string;
  portalUrl: string;
}): string {
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
        You have been granted Administrator access to the QR Check-in &amp; Attendance Portal.
      </p>
      <p style="font-size:14px;font-weight:600;margin-bottom:8px;">Your Login Credentials:</p>
      <div style="background:#f1f5f9;border-radius:12px;padding:18px;border:1px solid #cbd5e1;margin-bottom:24px;font-size:13.5px;">
        <p><strong>Portal URL:</strong> <a href="${escapeHtml(input.portalUrl)}">${escapeHtml(input.portalUrl)}</a></p>
        <p><strong>Login Email (ID):</strong> ${escapeHtml(input.email)}</p>
        <p><strong>Password:</strong> ${escapeHtml(input.password)}</p>
        <p><strong>Access Role:</strong> ${escapeHtml(input.roleLabel)}</p>
      </div>
      <p style="font-size:13px;color:#64748b;">Please sign in using the Portal URL above and keep your login credentials secure.</p>
      <p style="font-size:13px;">Best regards,<br/>Super Admin</p>
    </div>
  </div>
</body>
</html>`;
}

function errorName(error: unknown): string {
  if (error instanceof Error) return error.name || "Error";
  return "unknown";
}
