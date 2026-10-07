/**
 * Gmail-compatible SMTP sender for Supabase Edge Functions (Deno).
 * Uses denomailer with TLS on port 465. No Resend API.
 *
 * Required secrets (never log values):
 *   SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD,
 *   SMTP_FROM_EMAIL, SMTP_FROM_NAME
 *
 * Production Gmail (set via `supabase secrets set`, not in git):
 *   SMTP_HOST=smtp.gmail.com
 *   SMTP_PORT=465
 *   SMTP_USERNAME=attendiphi.metaphi@gmail.com
 *   SMTP_FROM_EMAIL=attendiphi.metaphi@gmail.com
 *   SMTP_FROM_NAME=Attendiphi by Metaphi
 *   SMTP_PASSWORD=<Gmail App Password only>
 *
 * Deno Deploy: prefer 465 (TLS). Ports 25/587 are often blocked.
 */

import { SMTPClient } from "denomailer";
import { ATTENDIPHI_LOGO_PNG_BASE64 } from "./logo_png_base64.ts";

/** Content-ID used in HTML as cid:attendiphi-logo (inline, not remote URL). */
export const ATTENDIPHI_LOGO_CID = "attendiphi-logo";

export interface SmtpMail {
  to: string;
  subject: string;
  text: string;
  html: string;
  /** When true, embeds the Attendiphi logo for cid:attendiphi-logo in HTML. */
  attachLogo?: boolean;
}

export interface SmtpSendResult {
  ok: true;
  messageId: string;
}

export class SmtpConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SmtpConfigError";
  }
}

export class SmtpSendError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SmtpSendError";
  }
}

interface SmtpConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  fromEmail: string;
  fromName: string;
  tls: boolean;
}

const SMTP_TIMEOUT_MS = 25_000;

export function readSmtpConfig(): SmtpConfig {
  const host = (
    Deno.env.get("SMTP_HOST")?.trim() ||
    Deno.env.get("SMTP_HOSTNAME")?.trim() ||
    ""
  );
  const portRaw = Deno.env.get("SMTP_PORT")?.trim() || "";
  const username = Deno.env.get("SMTP_USERNAME")?.trim() || "";
  const password = (Deno.env.get("SMTP_PASSWORD") ?? "")
    .replaceAll(/\s+/g, "")
    .trim();
  const fromEmail = Deno.env.get("SMTP_FROM_EMAIL")?.trim() || "";
  const fromName =
    Deno.env.get("SMTP_FROM_NAME")?.trim() || "Attendiphi by Metaphi";
  const secureRaw = Deno.env.get("SMTP_SECURE")?.trim().toLowerCase();

  const missing: string[] = [];
  if (!host) missing.push("SMTP_HOST");
  if (!portRaw) missing.push("SMTP_PORT");
  if (!username) missing.push("SMTP_USERNAME");
  if (!password) missing.push("SMTP_PASSWORD");
  if (!fromEmail) missing.push("SMTP_FROM_EMAIL");
  if (missing.length > 0) {
    throw new SmtpConfigError(`Missing SMTP secrets: ${missing.join(", ")}`);
  }

  const port = Number(portRaw);
  if (!Number.isFinite(port) || port <= 0 || port > 65535) {
    throw new SmtpConfigError("SMTP_PORT must be a valid port number");
  }

  // Gmail SSL: port 465 requires TLS. Override only via SMTP_SECURE.
  let tls = port === 465;
  if (secureRaw === "true" || secureRaw === "1") tls = true;
  if (secureRaw === "false" || secureRaw === "0") tls = false;

  return { host, port, username, password, fromEmail, fromName, tls };
}

export function smtpFromHeader(config: SmtpConfig): string {
  const name =
    config.fromName.replaceAll(/[<>\r\n]/g, "").trim() ||
    "Attendiphi by Metaphi";
  return `${name} <${config.fromEmail}>`;
}

export function smtpUserMessage(error: unknown): string {
  if (error instanceof SmtpConfigError) {
    return "Email service is not configured. Set Gmail SMTP secrets in Supabase.";
  }
  const name = error instanceof Error ? error.name : "";
  const msg = error instanceof Error ? error.message.toLowerCase() : "";
  if (name === "AbortError" || msg.includes("timeout") || msg.includes("timed out")) {
    return "Gmail SMTP timed out. Check connectivity and try again.";
  }
  if (
    msg.includes("auth") ||
    msg.includes("535") ||
    msg.includes("534") ||
    msg.includes("invalid login") ||
    msg.includes("username") ||
    msg.includes("password") ||
    msg.includes("badcredentials")
  ) {
    return "Gmail SMTP authentication failed. Use a Google App Password for SMTP_PASSWORD (not the normal Gmail password).";
  }
  if (
    msg.includes("econnrefused") ||
    msg.includes("enotfound") ||
    msg.includes("connect") ||
    msg.includes("network") ||
    msg.includes("unreachable") ||
    msg.includes("tls")
  ) {
    return "Could not connect to Gmail SMTP (smtp.gmail.com:465). Check SMTP_HOST and SMTP_PORT.";
  }
  return "Gmail rejected the message. Check SMTP configuration and try again.";
}

/** Safe log detail — no passwords, auth headers, or message bodies. */
export function smtpErrorDetail(error: unknown): string {
  if (!(error instanceof Error)) return "unknown";
  const raw = `${error.name}: ${error.message}`.replace(
    /(pass(word)?|secret|apikey|authorization)\s*[:=]\s*\S+/gi,
    "$1=[redacted]",
  );
  return raw.slice(0, 240);
}

export async function sendSmtpMail(mail: SmtpMail): Promise<SmtpSendResult> {
  const config = readSmtpConfig();
  const from = smtpFromHeader(config);
  const messageId = `smtp-${crypto.randomUUID()}`;

  const client = new SMTPClient({
    connection: {
      hostname: config.host,
      port: config.port,
      tls: config.tls,
      auth: {
        username: config.username,
        password: config.password,
      },
    },
  });

  try {
    await withTimeout(
      client.send({
        from,
        to: mail.to,
        subject: mail.subject,
        content: mail.text,
        html: mail.html,
        // Inline CID so Gmail shows the logo without fetching a remote URL
        // (remote images often break in Spam / behind image proxy).
        attachments: mail.attachLogo === false
          ? undefined
          : [
            {
              contentType: "image/png",
              filename: "attendiphi_logo.png",
              contentID: ATTENDIPHI_LOGO_CID,
              encoding: "base64",
              content: ATTENDIPHI_LOGO_PNG_BASE64,
            },
          ],
      }),
      SMTP_TIMEOUT_MS,
    );
    return { ok: true, messageId };
  } catch (error) {
    throw error instanceof SmtpConfigError || error instanceof SmtpSendError
      ? error
      : new SmtpSendError(smtpErrorDetail(error));
  } finally {
    try {
      await client.close();
    } catch {
      // ignore close errors
    }
  }
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: number | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      const err = new Error(`SMTP timed out after ${ms}ms`);
      err.name = "AbortError";
      reject(err);
    }, ms);
  });
  return Promise.race([promise, timeout]).finally(() => {
    if (timer !== undefined) clearTimeout(timer);
  });
}
