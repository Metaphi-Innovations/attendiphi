const admin = require('./functions/node_modules/firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

console.log('✅ Firebase Admin SDK initialized successfully!');
console.log('🚀 FCM Daemon is actively monitoring Firestore `checkIns` for attendance submissions...');

let isInitialSnapshot = true;
const knownCheckInIds = new Set();

admin.firestore().collection('checkIns').onSnapshot(async (snapshot) => {
  if (isInitialSnapshot) {
    snapshot.forEach(doc => knownCheckInIds.add(doc.id));
    isInitialSnapshot = false;
    console.log(`📌 Primed with ${knownCheckInIds.size} existing check-in records. Ready for new submissions!`);
    return;
  }

  for (const change of snapshot.docChanges()) {
    if (change.type === 'added' && !knownCheckInIds.has(change.doc.id)) {
      knownCheckInIds.add(change.doc.id);
      const data = change.doc.data() || {};
      const submissionId = change.doc.id;
      const userName = data.userName || 'Attendee';
      const type = data.type || 'Member';
      const locationName = data.locationName || 'Venue';
      const locationId = data.locationId || '';
      const title = `🔔 New Attendance: ${userName}`;
      const body = `${userName} (${type}) has checked in at ${locationName}.`;

      console.log(`\n📢 [NEW CHECK-IN DETECTED]: ${userName} (${type}) at ${locationName} (ID: ${submissionId})`);

      try {
        // Query active admin device tokens
        const devicesSnapshot = await admin.firestore().collection('admin_devices').where('isActive', '==', true).get();

        if (devicesSnapshot.empty) {
          console.log('⚠️ No active admin device tokens found in admin_devices.');
          continue;
        }

        const tokens = devicesSnapshot.docs.map(doc => doc.data().token).filter(Boolean);
        console.log(`📱 Sending FCM push to ${tokens.length} device(s)...`);

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
            userPhone: String(data.userPhone || ''),
            type: String(type || 'Member'),
            timestamp: String(data.timestamp || new Date().toISOString()),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            ttl: 86400,
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

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`✅ FCM Push delivered: ${response.successCount} succeeded, ${response.failureCount} failed.`);
      } catch (err) {
        console.error('❌ Error sending FCM multicast:', err);
      }
    }
  }
}, (err) => {
  console.error('❌ Firestore listener error:', err);
});

// Real-time listener for Admin Credentials Mail Dispatch
let isInitialMailSnapshot = true;
const knownMailIds = new Set();

admin.firestore().collection('admin_mail_dispatch').onSnapshot(async (snapshot) => {
  if (isInitialMailSnapshot) {
    snapshot.forEach(doc => knownMailIds.add(doc.id));
    isInitialMailSnapshot = false;
    return;
  }

  for (const change of snapshot.docChanges()) {
    if (change.type === 'added' && !knownMailIds.has(change.doc.id)) {
      knownMailIds.add(change.doc.id);
      const data = change.doc.data() || {};
      const mailId = change.doc.id;
      const to = data.to;
      const subject = data.subject || 'Admin Credentials';
      if (data.source === 'https' || (!data.bodyText && !data.html)) {
        continue;
      }
      console.log(`\n📧 [CREDENTIALS MAIL DOC IGNORED]: SMTP disabled here. Use Supabase SMTP Edge Function. To ${to} (Doc ID: ${mailId})`);
    }
  }
}, (err) => {
  console.error('❌ Mail listener error:', err);
});

