const functions = require('firebase-functions');
const admin = require('firebase-admin');

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

    const mailId = context.params.mailId;
    const to = data.to;
    const subject = data.subject || 'Your QR Check-in Admin Login Credentials';
    const text = data.bodyText || '';
    const html = data.html || '';

    console.log(`📧 Dispatching welcome credentials email to ${to} (ID: ${mailId})...`);

    try {
      let nodemailer;
      try {
        nodemailer = require('nodemailer');
      } catch (e) {
        console.warn('Nodemailer not bundled, skipping direct SMTP transport:', e);
      }

      if (nodemailer) {
        const smtpHost = process.env.SMTP_HOST || 'smtp.gmail.com';
        const smtpPort = parseInt(process.env.SMTP_PORT || '587', 10);
        const smtpUser = process.env.SMTP_USER || process.env.GMAIL_USER;
        const smtpPass = process.env.SMTP_PASS || process.env.GMAIL_PASS;

        if (smtpUser && smtpPass) {
          const transporter = nodemailer.createTransport({
            host: smtpHost,
            port: smtpPort,
            secure: smtpPort === 465,
            auth: {
              user: smtpUser,
              pass: smtpPass,
            },
          });

          await transporter.sendMail({
            from: `"QR Check-in Super Admin" <${smtpUser}>`,
            to: to,
            subject: subject,
            text: text,
            html: html,
          });

          console.log(`✅ Credentials email sent successfully to ${to}`);
          return snap.ref.update({
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          console.log('ℹ️ No SMTP_USER / GMAIL_USER configured in env. Record saved for client/relay dispatch.');
        }
      }

      return snap.ref.update({
        status: 'queued',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error(`❌ Failed to send credentials email to ${to}:`, err);
      return snap.ref.update({
        status: 'error',
        error: err.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

