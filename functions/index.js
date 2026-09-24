/**
 * Legacy Cloud Functions source.
 *
 * These cannot be deployed on the Spark (no-billing) plan: Firebase requires
 * Blaze, Cloud Build, and Artifact Registry. The production app does not
 * call these endpoints. Keep this file as reference only — do not add this
 * codebase back to firebase.json unless billing is explicitly enabled.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

/**
 * Helper function to dispatch high-priority FCM multicast notification
 * to all registered and active admin devices.
 */
async function dispatchAdminNotification({
  submissionId,
  title,
  body,
  userName,
  userPhone,
  type,
  locationName,
  locationId,
  timestamp,
}) {
  try {
    // 1. Query all active admin devices
    const devicesSnapshot = await admin
      .firestore()
      .collection('admin_devices')
      .where('isActive', '==', true)
      .get();

    if (devicesSnapshot.empty) {
      console.log('⚠️ No active admin devices found to receive push notifications.');
      return { success: false, reason: 'no_active_devices' };
    }

    const tokens = devicesSnapshot.docs
      .map((doc) => doc.data().token)
      .filter((token) => Boolean(token));

    if (tokens.length === 0) {
      console.log('⚠️ No valid FCM tokens extracted from admin_devices.');
      return { success: false, reason: 'no_valid_tokens' };
    }

    console.log(`📱 Dispatching high-priority FCM notification to ${tokens.length} device(s) for check-in ${submissionId}...`);

    // 2. Build bulletproof FCM multicast payload optimized for Android 13+ killed state and iOS background wakeup
    const message = {
      tokens: tokens,
      notification: {
        title: title,
        body: body,
      },
      data: {
        submissionId: String(submissionId || ''),
        title: String(title || ''),
        body: String(body || ''),
        locationId: String(locationId || ''),
        locationName: String(locationName || 'Venue'),
        userName: String(userName || 'Attendee'),
        userPhone: String(userPhone || ''),
        type: String(type || 'Member'),
        timestamp: String(timestamp || new Date().toISOString()),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        ttl: 86400, // 24 hours
        notification: {
          title: title,
          body: body,
          channelId: 'admin_attendance_channel',
          sound: 'default',
          priority: 'max',
          visibility: 'public',
          icon: 'ic_launcher',
          defaultVibrateTimings: true,
          defaultSound: true,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            badge: 1,
            contentAvailable: true,
          },
        },
      },
    };

    // 3. Send multicast
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(
      `✅ FCM Multicast result for [${submissionId}]: ${response.successCount} succeeded, ${response.failureCount} failed.`
    );

    // 4. Cleanup stale / unregistered tokens
    const staleTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const error = resp.error;
        console.warn(`Device token error for index ${idx}:`, error?.code, error?.message);
        if (
          error &&
          (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered')
        ) {
          staleTokens.push(tokens[idx]);
        }
      }
    });

    if (staleTokens.length > 0) {
      const batch = admin.firestore().batch();
      staleTokens.forEach((badToken) => {
        const docRef = admin.firestore().collection('admin_devices').doc(badToken);
        batch.update(docRef, { isActive: false, error: 'unregistered', deactivatedAt: admin.firestore.FieldValue.serverTimestamp() });
      });
      await batch.commit();
      console.log(`🧹 Deactivated ${staleTokens.length} stale FCM tokens.`);
    }

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (err) {
    console.error(`❌ Error dispatching FCM notification for ${submissionId}:`, err);
    return { success: false, error: err.message };
  }
}

const DEFAULT_PORTAL_URL = 'https://attendiphi-by-metaphi.web.app/';
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function buildCredentialsEmail({ name, email, password, roleLabel, portalUrl }) {
  const subject = 'Your QR Check-in Admin Login Credentials';
  const text = `Hello ${name},

You have been granted Administrator access to the QR Check-in & Attendance Portal.

Your Login Credentials:

────────────────────────────────────
• Portal URL: ${portalUrl}
• Login Email (ID): ${email}
• Password: ${password}
• Access Role: ${roleLabel}
────────────────────────────────────

Please sign in using the Portal URL above and keep your login credentials secure.

Best regards,
Super Admin Team
`;

  const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#f8fafc;margin:0;padding:24px;color:#1e293b;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e2e8f0;">
    <div style="background:#4f46e5;padding:28px 24px;text-align:center;color:#ffffff;">
      <h1 style="margin:0;font-size:20px;">Attendiphi-by-Metaphi</h1>
      <p style="margin:8px 0 0;font-size:13px;opacity:0.9;">QR Check-in &amp; Attendance Portal</p>
    </div>
    <div style="padding:28px 24px;">
      <p style="font-size:16px;font-weight:600;">Hello ${escapeHtml(name)},</p>
      <p style="font-size:14px;color:#475569;line-height:1.6;">
        You have been granted Administrator access to the QR Check-in &amp; Attendance Portal.
      </p>
      <p style="font-size:14px;font-weight:600;margin-bottom:8px;">Your Login Credentials:</p>
      <div style="background:#f1f5f9;border-radius:12px;padding:18px;border:1px solid #cbd5e1;margin-bottom:24px;font-size:13.5px;">
        <p><strong>Portal URL:</strong> <a href="${escapeHtml(portalUrl)}">${escapeHtml(portalUrl)}</a></p>
        <p><strong>Login Email (ID):</strong> ${escapeHtml(email)}</p>
        <p><strong>Password:</strong> ${escapeHtml(password)}</p>
        <p><strong>Access Role:</strong> ${escapeHtml(roleLabel)}</p>
      </div>
      <p style="font-size:13px;color:#64748b;">Please sign in using the Portal URL above and keep your login credentials secure.</p>
      <p style="font-size:13px;">Best regards,<br/>Super Admin Team</p>
    </div>
  </div>
</body>
</html>`;

  return { subject, text, html };
}

function getSmtpTransporter() {
  return { error: 'Email service is not configured. Use the Supabase SMTP Edge Function.' };
}

async function deliverCredentialsEmail({ to, subject, text, html }) {
  const smtp = getSmtpTransporter();
  if (!smtp.transporter) {
    return { ok: false, reason: 'provider', message: smtp.error };
  }

  await smtp.transporter.sendMail({
    from: `"Attendiphi-by-Metaphi" <${smtp.smtpUser}>`,
    to,
    subject,
    text,
    html,
  });
  return { ok: true };
}

function isSuperAdminEmail(email) {
  const configured = (process.env.SUPERADMIN_EMAIL || '').trim().toLowerCase();
  return configured !== '' && email === configured;
}

function superAdminPasswords() {
  const fromEnv = process.env.SUPERADMIN_PASSWORD;
  return fromEnv ? [fromEnv] : [];
}

function jsonCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization'
  );
}

function publicError(kind) {
  switch (kind) {
    case 'unauthorized':
      return 'You are not authorized to send admin credentials.';
    case 'invalid_email':
      return 'Please provide a valid recipient email address.';
    case 'timeout':
      return 'Sending timed out. Please try again.';
    case 'provider':
      return 'Could not send the email. Please try again.';
    case 'unavailable':
      return 'Email service is temporarily unavailable. Please try again.';
    default:
      return 'Failed to send credentials. Please try again.';
  }
}

async function resolveSenderFromPassword(senderEmail, senderPassword) {
  const email = String(senderEmail || '').trim().toLowerCase();
  const password = String(senderPassword || '');
  if (!email || !password) return null;

  if (isSuperAdminEmail(email) && superAdminPasswords().includes(password)) {
    return {
      id: 'super_admin_master',
      email,
      role: 'superadmin',
      isActive: true,
    };
  }

  const snapshot = await admin
    .firestore()
    .collection('admins')
    .where('email', '==', email)
    .limit(1)
    .get();

  if (snapshot.empty) return null;
  const doc = snapshot.docs[0];
  const data = doc.data() || {};
  const stored =
    String(data.plainPassword || '') || String(data.passwordHash || '');
  if (!stored || stored !== password) return null;
  if (data.isActive === false) return null;

  const role = String(data.role || 'admin').toLowerCase();
  if (role !== 'admin' && role !== 'superadmin' && role !== 'super_admin') {
    return null;
  }

  return {
    id: doc.id,
    email,
    role: role === 'admin' ? 'admin' : 'superadmin',
    isActive: true,
  };
}

async function resolveSenderFromIdToken(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice('Bearer '.length).trim();
  if (!token) return null;
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const email = String(decoded.email || decoded.adminEmail || '')
      .trim()
      .toLowerCase();
    if (isSuperAdminEmail(email) || decoded.adminRole === 'superadmin') {
      return {
        id: decoded.adminId || decoded.uid || 'super_admin_master',
        email: email,
        role: 'superadmin',
        isActive: true,
      };
    }
    if (!email) return null;
    const snapshot = await admin
      .firestore()
      .collection('admins')
      .where('email', '==', email)
      .limit(1)
      .get();
    if (snapshot.empty) return null;
    const doc = snapshot.docs[0];
    const data = doc.data() || {};
    if (data.isActive === false) return null;
    const role = String(data.role || 'admin').toLowerCase();
    if (role !== 'admin' && role !== 'superadmin' && role !== 'super_admin') {
      return null;
    }
    return {
      id: doc.id,
      email,
      role: role === 'admin' ? 'admin' : 'superadmin',
      isActive: true,
    };
  } catch (_) {
    return null;
  }
}

/**
 * Triggered on creation of a new check-in document in `checkIns/{checkInId}`.
 * Directly sends push notification to all admins even when the app is killed.
 */
exports.onCheckInCreated = functions.firestore
  .document('checkIns/{checkInId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const checkInId = context.params.checkInId;
    const userName = data.userName || 'Attendee';
    const type = data.type || 'Member';
    const locationName = data.locationName || 'Venue';
    const title = `🔔 New Attendance: ${userName}`;
    const body = `${userName} (${type}) has checked in at ${locationName}.`;

    return dispatchAdminNotification({
      submissionId: checkInId,
      title: title,
      body: body,
      userName: userName,
      userPhone: data.userPhone || '',
      type: type,
      locationName: locationName,
      locationId: data.locationId || '',
      timestamp: data.timestamp || new Date().toISOString(),
    });
  });

/**
 * Triggered on creation in `admin_notifications/{submissionId}`.
 * Marks the notification record with delivery status.
 */
exports.onAdminNotificationCreated = functions.firestore
  .document('admin_notifications/{submissionId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const submissionId = context.params.submissionId;
    const title = data.title || 'New Attendance Submission';
    const body = data.body || 'A new attendance check-in has been submitted.';
    const customData = data.data || {};

    const result = await dispatchAdminNotification({
      submissionId: submissionId,
      title: title,
      body: body,
      userName: customData.userName || data.userName || 'Attendee',
      userPhone: customData.userPhone || data.userPhone || '',
      type: customData.type || data.checkInType || 'Member',
      locationName: customData.locationName || data.locationName || 'Venue',
      locationId: customData.locationId || data.locationId || '',
      timestamp: customData.timestamp || new Date().toISOString(),
    });

    if (result.success) {
      return snap.ref.update({
        status: 'delivered',
        successCount: result.successCount,
        failureCount: result.failureCount,
        dispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      return snap.ref.update({
        status: result.reason || 'error',
        error: result.error || null,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * Triggered on creation of a new admin email record in `admin_mail_dispatch/{mailId}`.
 * Automatically sends welcome email with credentials to admin's Gmail.
 */
exports.onAdminMailDispatch = functions.firestore
  .document('admin_mail_dispatch/{mailId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;
    if (data.source === 'https' || data.status === 'sending' || data.status === 'sent') {
      return null;
    }
    if (!data.bodyText && !data.html) {
      return null;
    }

    const mailId = context.params.mailId;
    const to = data.to;
    const subject = data.subject || 'Your QR Check-in Admin Login Credentials';
    const text = data.bodyText || '';
    const html = data.html || '';

    console.log(`📧 Dispatching welcome credentials email to ${to} (ID: ${mailId})...`);

    try {
      const result = await deliverCredentialsEmail({
        to,
        subject,
        text,
        html,
      });
      if (result.ok) {
        console.log(`✅ Credentials email sent successfully to ${to}`);
        return snap.ref.update({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      return snap.ref.update({
        status: 'queued',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error(`❌ Failed to send credentials email to ${to}`);
      return snap.ref.update({
        status: 'error',
        error: 'provider_failure',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * HTTPS endpoint used by the Admin Management UI to send credentials.
 * POST /sendAdminCredentials
 * Auth: Firebase ID token and/or verified sender email+password.
 * SMTP secrets stay on the server.
 */
exports.sendAdminCredentials = functions.https.onRequest(async (req, res) => {
  jsonCors(res);
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }
  if (req.method !== 'POST') {
    return res.status(405).json({
      success: false,
      error: 'Method not allowed.',
    });
  }

  try {
    const body = req.body || {};
    const sender =
      (await resolveSenderFromIdToken(req.get('Authorization'))) ||
      (await resolveSenderFromPassword(body.senderEmail, body.senderPassword));

    if (!sender) {
      return res.status(401).json({
        success: false,
        error: publicError('unauthorized'),
      });
    }

    const recipientEmail = String(body.recipientEmail || '')
      .trim()
      .toLowerCase();
    const recipientName = String(body.recipientName || '').trim();
    const recipientAdminId = String(body.recipientAdminId || '').trim();
    const password = String(body.password || '');
    const portalUrl = String(body.portalUrl || DEFAULT_PORTAL_URL).trim() ||
      DEFAULT_PORTAL_URL;
    const idempotencyKey = String(body.idempotencyKey || '').trim();

    if (!EMAIL_REGEX.test(recipientEmail)) {
      return res.status(400).json({
        success: false,
        error: publicError('invalid_email'),
      });
    }
    if (!password || password.length < 6) {
      return res.status(400).json({
        success: false,
        error:
          'Credentials are no longer available. Create a new temporary password and try again.',
      });
    }
    if (!idempotencyKey) {
      return res.status(400).json({
        success: false,
        error: publicError('unavailable'),
      });
    }

    let recipientDoc = null;
    if (recipientAdminId) {
      recipientDoc = await admin
        .firestore()
        .collection('admins')
        .doc(recipientAdminId)
        .get();
    }
    if (!recipientDoc || !recipientDoc.exists) {
      const byEmail = await admin
        .firestore()
        .collection('admins')
        .where('email', '==', recipientEmail)
        .limit(1)
        .get();
      if (!byEmail.empty) {
        recipientDoc = byEmail.docs[0];
      }
    }
    if (!recipientDoc || !recipientDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'That admin account was not found.',
      });
    }

    const recipientData = recipientDoc.data() || {};
    const roleLabel =
      String(recipientData.role || 'admin').toLowerCase() === 'superadmin'
        ? 'Super Admin'
        : 'Admin';
    const name = recipientName || recipientData.name || 'Admin';

    const dispatchRef = admin
      .firestore()
      .collection('admin_mail_dispatch')
      .doc(idempotencyKey);
    const existing = await dispatchRef.get();
    if (existing.exists && existing.data()?.status === 'sent') {
      return res.status(200).json({
        success: true,
        alreadySent: true,
        to: recipientEmail,
      });
    }

    await dispatchRef.set(
      {
        to: recipientEmail,
        recipientName: name,
        recipientAdminId: recipientDoc.id,
        senderAdminId: sender.id,
        senderEmail: sender.email,
        subject: 'Your QR Check-in Admin Login Credentials',
        status: 'sending',
        source: 'https',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const mail = buildCredentialsEmail({
      name,
      email: recipientEmail,
      password,
      roleLabel,
      portalUrl,
    });

    const delivered = await deliverCredentialsEmail({
      to: recipientEmail,
      subject: mail.subject,
      text: mail.text,
      html: mail.html,
    });

    if (!delivered.ok) {
      await dispatchRef.set(
        {
          status: 'error',
          error: 'provider_failure',
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return res.status(503).json({
        success: false,
        error: publicError(delivered.reason || 'provider'),
      });
    }

    await dispatchRef.set(
      {
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return res.status(200).json({
      success: true,
      alreadySent: false,
      to: recipientEmail,
    });
  } catch (err) {
    console.error('sendAdminCredentials failed');
    return res.status(500).json({
      success: false,
      error: publicError('unavailable'),
    });
  }
});

const RESET_TOKEN_TTL_MS = 60 * 60 * 1000;
const RESET_COOLDOWN_MS = 60 * 1000;
const RESET_COLLECTION = 'admin_password_resets';

function sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function hashAdminPassword(password, salt) {
  return sha256Hex(`${salt}:${password}`);
}

const FIREBASE_WEB_API_KEY =
  process.env.FIREBASE_WEB_API_KEY || 'AIzaSyCgMYy9B65RLXkN4qgD07J_w_JIX9-BIoQ';

async function ensureAuthUser(email, displayName) {
  try {
    await admin.auth().getUserByEmail(email);
    return true;
  } catch (err) {
    if (err && err.code !== 'auth/user-not-found') {
      console.error('ensureAuthUser lookup failed');
      return false;
    }
  }
  try {
    await admin.auth().createUser({
      email,
      emailVerified: true,
      displayName: displayName || 'Admin',
      password: `${crypto.randomBytes(18).toString('base64url')}Aa1!`,
    });
    return true;
  } catch (err) {
    if (err && err.code === 'auth/email-already-exists') return true;
    console.error('ensureAuthUser create failed');
    return false;
  }
}

async function sendFirebasePasswordResetEmail(email) {
  const portal =
    process.env.PORTAL_URL || 'https://attendiphi-by-metaphi.web.app';
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${FIREBASE_WEB_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requestType: 'PASSWORD_RESET',
        email,
        continueUrl: `${portal.replace(/\/$/, '')}/`,
      }),
    }
  );
  if (!response.ok) {
    const retry = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${FIREBASE_WEB_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestType: 'PASSWORD_RESET',
          email,
        }),
      }
    );
    if (!retry.ok) {
      console.error('Firebase password reset email failed');
      return false;
    }
  }
  return true;
}

function isStrongAdminPassword(password) {
  const value = String(password || '').trim();
  if (value.length < 8) return false;
  return /[0-9!@#%^&*(),.?":{}|<>]/.test(value);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function buildPasswordResetEmail({ name, resetUrl }) {
  const subject = 'Reset Your Attendephi Administrator Password';
  const text = `Hello ${name},

We received a request to reset your Attendephi Administrator password.

Open this link to create a new password:
${resetUrl}

This link will expire after a limited period.

If you did not request this password reset, you can safely ignore this email.

Best regards,
Attendephi by Metaphi
`;
  const html = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#f8fafc;margin:0;padding:24px;color:#1e293b;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e2e8f0;">
    <div style="background:#4f46e5;padding:28px 24px;text-align:center;color:#ffffff;">
      <h1 style="margin:0;font-size:20px;">Attendephi by Metaphi</h1>
    </div>
    <div style="padding:28px 24px;">
      <p style="font-size:16px;font-weight:600;">Hello ${escapeHtml(name)},</p>
      <p style="font-size:14px;color:#475569;line-height:1.6;">
        We received a request to reset your Attendephi Administrator password.
      </p>
      <p style="font-size:14px;color:#475569;line-height:1.6;">
        Click the button below to create a new password:
      </p>
      <p style="text-align:center;margin:28px 0;">
        <a href="${escapeHtml(resetUrl)}" style="display:inline-block;background:#4f46e5;color:#ffffff;text-decoration:none;font-weight:700;font-size:14px;padding:12px 24px;border-radius:10px;">Reset Password</a>
      </p>
      <p style="font-size:13px;color:#64748b;">This link will expire after a limited period.</p>
      <p style="font-size:13px;color:#64748b;">If you did not request this password reset, you can safely ignore this email.</p>
      <p style="font-size:13px;">Best regards,<br/>Attendephi by Metaphi</p>
    </div>
  </div>
</body>
</html>`;
  return { subject, text, html };
}

async function findResetDocByToken(token) {
  const tokenHash = sha256Hex(token);
  const snapshot = await admin
    .firestore()
    .collection(RESET_COLLECTION)
    .where('tokenHash', '==', tokenHash)
    .limit(1)
    .get();
  if (snapshot.empty) return null;
  return snapshot.docs[0];
}

function isResetDocValid(data) {
  if (!data || data.used === true) return false;
  const expiresAt = data.expiresAt && data.expiresAt.toDate
    ? data.expiresAt.toDate()
    : data.expiresAt
      ? new Date(data.expiresAt)
      : null;
  if (!expiresAt || Number.isNaN(expiresAt.getTime())) return false;
  return expiresAt.getTime() > Date.now();
}

const GENERIC_RESET_ACCEPTED = {
  success: true,
  message:
    'If an account exists for this email address, a password reset link has been sent.',
};

/**
 * Starts an Administrator password reset. Always returns a generic success
 * payload so callers cannot enumerate registered emails.
 */
exports.requestAdminPasswordReset = functions.https.onRequest(async (req, res) => {
  jsonCors(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed.' });
  }

  const started = Date.now();
  const finish = async () => {
    const elapsed = Date.now() - started;
    if (elapsed < 400) await sleep(400 - elapsed);
    return res.status(200).json(GENERIC_RESET_ACCEPTED);
  };

  try {
    const email = String((req.body || {}).email || '').trim().toLowerCase();
    if (!EMAIL_REGEX.test(email)) {
      return res.status(400).json({
        success: false,
        error: publicError('invalid_email'),
      });
    }

    const snapshot = await admin
      .firestore()
      .collection('admins')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return finish();
    }

    const adminDoc = snapshot.docs[0];
    const adminData = adminDoc.data() || {};
    if (adminData.isActive === false) {
      return finish();
    }

    const rateRef = admin
      .firestore()
      .collection('admin_password_reset_rate')
      .doc(adminDoc.id);
    const rateSnap = await rateRef.get();
    if (rateSnap.exists) {
      const lastSent = rateSnap.data()?.lastSentAt;
      const lastMs = lastSent && lastSent.toDate ? lastSent.toDate().getTime() : 0;
      if (Date.now() - lastMs < RESET_COOLDOWN_MS) {
        return finish();
      }
    }

    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = sha256Hex(rawToken);
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + RESET_TOKEN_TTL_MS)
    );
    await admin.firestore().collection(RESET_COLLECTION).add({
      tokenHash,
      adminId: adminDoc.id,
      used: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
    });
    await rateRef.set({
      lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const portal =
      process.env.PORTAL_URL || 'https://attendiphi-by-metaphi.web.app';
    const resetUrl = `${portal.replace(/\/$/, '')}/reset-password?token=${encodeURIComponent(rawToken)}`;
    const mail = buildPasswordResetEmail({
      name: adminData.name || 'Admin',
      resetUrl,
    });
    const smtpResult = await deliverCredentialsEmail({
      to: email,
      subject: mail.subject,
      text: mail.text,
      html: mail.html,
    });
    if (!smtpResult.ok) {
      const ready = await ensureAuthUser(email, adminData.name || 'Admin');
      if (ready) {
        await sendFirebasePasswordResetEmail(email);
      }
    }

    return finish();
  } catch (err) {
    console.error('requestAdminPasswordReset failed');
    return finish();
  }
});

exports.verifyAdminPasswordReset = functions.https.onRequest(async (req, res) => {
  jsonCors(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') {
    return res.status(405).json({ valid: false });
  }
  try {
    const token = String((req.body || {}).token || '').trim();
    if (!token) return res.status(200).json({ valid: false });
    const doc = await findResetDocByToken(token);
    if (!doc) return res.status(200).json({ valid: false });
    return res.status(200).json({ valid: isResetDocValid(doc.data()) });
  } catch (err) {
    console.error('verifyAdminPasswordReset failed');
    return res.status(200).json({ valid: false });
  }
});

exports.completeAdminPasswordReset = functions.https.onRequest(async (req, res) => {
  jsonCors(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed.' });
  }

  try {
    const body = req.body || {};
    const token = String(body.token || '').trim();
    const newPassword = String(body.newPassword || '');
    if (!token) {
      return res.status(400).json({
        success: false,
        invalidOrExpired: true,
        error: 'This password reset link is no longer valid.',
      });
    }
    if (!isStrongAdminPassword(newPassword)) {
      return res.status(400).json({
        success: false,
        error:
          'Password must be at least 8 characters and include a number or special character.',
      });
    }

    const resetDoc = await findResetDocByToken(token);
    if (!resetDoc || !isResetDocValid(resetDoc.data())) {
      return res.status(400).json({
        success: false,
        invalidOrExpired: true,
        error: 'This password reset link is no longer valid.',
      });
    }

    const resetData = resetDoc.data() || {};
    const adminId = String(resetData.adminId || '').trim();
    if (!adminId) {
      return res.status(400).json({
        success: false,
        invalidOrExpired: true,
        error: 'This password reset link is no longer valid.',
      });
    }

    const adminRef = admin.firestore().collection('admins').doc(adminId);
    const adminSnap = await adminRef.get();
    if (!adminSnap.exists || adminSnap.data()?.isActive === false) {
      return res.status(400).json({
        success: false,
        invalidOrExpired: true,
        error: 'This password reset link is no longer valid.',
      });
    }

    const salt = crypto.randomBytes(16).toString('hex');
    const passwordHash = hashAdminPassword(newPassword.trim(), salt);

    await adminRef.update({
      passwordHash,
      passwordSalt: salt,
      plainPassword: '',
      mustResetPassword: false,
      passwordUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await resetDoc.ref.update({
      used: true,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const siblings = await admin
      .firestore()
      .collection(RESET_COLLECTION)
      .where('adminId', '==', adminId)
      .get();
    const batch = admin.firestore().batch();
    let pending = 0;
    siblings.docs.forEach((doc) => {
      if (doc.id !== resetDoc.id && doc.data()?.used !== true) {
        batch.update(doc.ref, {
          used: true,
          usedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        pending += 1;
      }
    });
    if (pending > 0) await batch.commit();

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('completeAdminPasswordReset failed');
    return res.status(500).json({
      success: false,
      error: publicError('unavailable'),
    });
  }
});

/**
 * HTTPS Cloud Function for Web Face Recognition.
 * Accepts photoBase64 or probe biometric embeddings and verifies identity
 * against enrolled chapter members using Euclidean distance matching.
 */
exports.matchMemberFace = functions.https.onRequest(async (req, res) => {
  // 1. CORS headers for Flutter Web
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  try {
    const { photoBase64, candidates, adminId, locationId, probeEmbedding } = req.body || {};

    if (!photoBase64 && !probeEmbedding) {
      return res.status(400).json({ error: 'photoBase64 or probeEmbedding is required' });
    }

    // 2. Gather candidates with face embeddings
    let candidateList = candidates;
    if (!Array.isArray(candidateList) || candidateList.length === 0) {
      let query = admin.firestore().collection('employees').where('isActive', '==', true);
      if (adminId) {
        query = query.where('adminId', '==', adminId);
      }
      const snapshot = await query.get();
      candidateList = snapshot.docs
        .map((doc) => ({ id: doc.id, ...doc.data() }))
        .filter((c) => Array.isArray(c.faceEmbedding) && c.faceEmbedding.length > 0);
    } else {
      candidateList = candidateList.filter(
        (c) => Array.isArray(c.faceEmbedding) && c.faceEmbedding.length > 0
      );
    }

    if (!candidateList || candidateList.length === 0) {
      return res.status(200).json({
        matched: false,
        message: 'No enrolled member face profiles found for this chapter.',
      });
    }

    // 3. Euclidean distance computation
    function calculateEuclideanDistance(emb1, emb2) {
      if (!emb1 || !emb2 || emb1.length !== emb2.length) return 999.0;
      let sum = 0.0;
      for (let i = 0; i < emb1.length; i++) {
        const diff = emb1[i] - emb2[i];
        sum += diff * diff;
      }
      return Math.sqrt(sum);
    }

    function distanceToConfidence(distance) {
      if (distance <= 0.0) return 100.0;
      if (distance >= 1.25) return 0.0;
      return Math.min(100.0, Math.max(0.0, (1.0 - distance / 1.25) * 100.0));
    }

    // 4. If probe embedding is provided, perform Euclidean distance match
    if (Array.isArray(probeEmbedding) && probeEmbedding.length > 0) {
      let bestCandidate = null;
      let lowestDistance = 999.0;

      for (const cand of candidateList) {
        const dist = calculateEuclideanDistance(probeEmbedding, cand.faceEmbedding);
        if (dist < lowestDistance) {
          lowestDistance = dist;
          bestCandidate = cand;
        }
      }

      const matchThreshold = 0.78;
      if (bestCandidate && lowestDistance <= matchThreshold) {
        const confidence = distanceToConfidence(lowestDistance);
        console.log(`✓ Web Face Matched: ${bestCandidate.name} (confidence: ${confidence.toFixed(1)}%)`);
        return res.status(200).json({
          matched: true,
          memberId: bestCandidate.id,
          memberName: bestCandidate.name,
          confidence: confidence,
          distance: lowestDistance,
        });
      }

      return res.status(200).json({
        matched: false,
        message: 'Face not recognized with sufficient confidence in this chapter.',
        distance: lowestDistance,
      });
    }

    // 5. If photo is captured, report receipt to client and trigger manual name selection with selfie
    return res.status(200).json({
      matched: false,
      message: 'Selfie photo recorded. Please select your name to verify attendance.',
    });
  } catch (err) {
    console.error('Error in matchMemberFace cloud function:', err);
    return res.status(500).json({ error: err.message });
  }
});


