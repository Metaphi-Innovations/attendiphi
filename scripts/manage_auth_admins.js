#!/usr/bin/env node

/**
 * CLI utility to inspect, delete, and reconcile Firebase Authentication users
 * with Firestore admin accounts.
 *
 * Uses serviceAccountKey.json for full Firebase Admin access.
 *
 * Usage:
 *   node scripts/manage_auth_admins.js list
 *   node scripts/manage_auth_admins.js delete <email-or-uid>
 *   node scripts/manage_auth_admins.js clean-orphans
 *   node scripts/manage_auth_admins.js create-superadmin <email> <password> [name]
 */

const path = require('path');
const fs = require('fs');

// Locate serviceAccountKey.json
const saPath = path.resolve(__dirname, '../serviceAccountKey.json');
if (!fs.existsSync(saPath)) {
  console.error('❌ serviceAccountKey.json not found at:', saPath);
  process.exit(1);
}

// Locate firebase-admin in functions/node_modules or local
let admin;
try {
  admin = require(path.resolve(__dirname, '../functions/node_modules/firebase-admin'));
} catch {
  try {
    admin = require('firebase-admin');
  } catch (err) {
    console.error('❌ Could not load firebase-admin package:', err.message);
    process.exit(1);
  }
}

const serviceAccount = JSON.parse(fs.readFileSync(saPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db = admin.firestore();

async function listUsers() {
  console.log(`\n🔍 Fetching Firebase Auth users for project "${serviceAccount.project_id}"...\n`);
  const listResult = await auth.listUsers(1000);
  const authUsers = listResult.users;

  const adminDocsSnap = await db.collection('admins').get();
  const firestoreAdmins = new Map();
  adminDocsSnap.forEach((doc) => {
    firestoreAdmins.set(doc.id, doc.data());
  });

  console.log(`Found ${authUsers.length} Firebase Auth user(s) and ${firestoreAdmins.size} Firestore admin(s):\n`);
  console.log('--------------------------------------------------------------------------------');
  console.log(' UID                                | Email                          | Firestore');
  console.log('--------------------------------------------------------------------------------');

  for (const user of authUsers) {
    const email = (user.email || 'no-email').padEnd(30, ' ');
    const uid = user.uid.padEnd(34, ' ');
    const fsDoc = firestoreAdmins.get(user.uid);
    const status = fsDoc
      ? `✅ Active (${fsDoc.role || 'admin'})`
      : '⚠️  ORPHANED (No Firestore admin)';
    console.log(` ${uid} | ${email} | ${status}`);
  }
  console.log('--------------------------------------------------------------------------------\n');
}

async function deleteUser(identifier) {
  if (!identifier) {
    console.error('❌ Please provide an email or UID to delete.');
    process.exit(1);
  }

  const clean = identifier.trim().toLowerCase();
  let targetUser;

  try {
    // Try finding by email
    targetUser = await auth.getUserByEmail(clean);
  } catch {
    try {
      // Try finding by UID
      targetUser = await auth.getUser(identifier.trim());
    } catch {
      console.log(`⚠️ User "${identifier}" was not found in Firebase Auth.`);
    }
  }

  if (targetUser) {
    await auth.deleteUser(targetUser.uid);
    console.log(`✅ Successfully deleted user from Firebase Auth:`);
    console.log(`   Email: ${targetUser.email}`);
    console.log(`   UID:   ${targetUser.uid}`);
  }

  // Also check if Firestore doc exists and delete it
  const targetUid = targetUser ? targetUser.uid : identifier.trim();
  const docRef = db.collection('admins').doc(targetUid);
  const docSnap = await docRef.get();
  if (docSnap.exists) {
    await docRef.delete();
    console.log(`✅ Also deleted corresponding Firestore document: admins/${targetUid}`);
  } else {
    // Check if any admin doc has this email
    const emailQuery = await db.collection('admins').where('email', '==', clean).get();
    if (!emailQuery.empty) {
      for (const d of emailQuery.docs) {
        await d.ref.delete();
        console.log(`✅ Deleted matching Firestore document by email: admins/${d.id}`);
      }
    }
  }

  console.log('\n🎉 Done!\n');
}

/**
 * Create or update a Firebase Auth user and Firestore admins/{uid} as Super Admin.
 * Passwords are CLI args only — never commit them to source.
 */
async function createSuperAdmin(emailArg, passwordArg, nameArg) {
  const email = String(emailArg || '').trim().toLowerCase();
  const password = String(passwordArg || '');
  const name = String(nameArg || email.split('@')[0] || 'Super Admin').trim();

  if (!email || !email.includes('@')) {
    console.error('❌ Valid email is required.');
    process.exit(1);
  }
  if (password.length < 8) {
    console.error('❌ Password must be at least 8 characters.');
    process.exit(1);
  }

  let user;
  try {
    user = await auth.getUserByEmail(email);
    await auth.updateUser(user.uid, {
      password,
      displayName: name,
      disabled: false,
      emailVerified: true,
    });
    console.log(`♻️  Updated existing Auth user: ${email} (${user.uid})`);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') {
      throw err;
    }
    user = await auth.createUser({
      email,
      password,
      displayName: name,
      emailVerified: true,
      disabled: false,
    });
    console.log(`✅ Created Auth user: ${email} (${user.uid})`);
  }

  const docRef = db.collection('admins').doc(user.uid);
  const existing = await docRef.get();
  const payload = {
    uid: user.uid,
    email,
    name,
    role: 'superadmin',
    isActive: true,
    phone: existing.exists ? (existing.data().phone || '') : '',
    mustResetPassword: false,
    createdBy: existing.exists
      ? (existing.data().createdBy || user.uid)
      : user.uid,
    assignedLocationIds: existing.exists
      ? (existing.data().assignedLocationIds || [])
      : [],
  };
  if (!existing.exists) {
    payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await docRef.set(payload, { merge: true });
  console.log(`✅ Firestore admins/${user.uid} → role=superadmin, isActive=true`);
  console.log(`🎉 Super Admin ready: ${email}\n`);
}

async function cleanOrphans() {
  console.log(`\n🧹 Scanning for orphaned Firebase Auth users...\n`);
  const listResult = await auth.listUsers(1000);
  const authUsers = listResult.users;

  const adminDocsSnap = await db.collection('admins').get();
  const firestoreAdmins = new Set();
  adminDocsSnap.forEach((doc) => {
    firestoreAdmins.add(doc.id);
  });

  const orphans = authUsers.filter((u) => !firestoreAdmins.has(u.uid));

  if (orphans.length === 0) {
    console.log('✨ No orphaned Firebase Auth users found! All accounts are in sync.\n');
    return;
  }

  console.log(`Found ${orphans.length} orphaned Auth user(s):`);
  for (const orphan of orphans) {
    console.log(` - ${orphan.email} (${orphan.uid})`);
  }

  console.log('\nDeleting orphaned accounts from Firebase Authentication...');
  for (const orphan of orphans) {
    await auth.deleteUser(orphan.uid);
    console.log(` ✅ Deleted: ${orphan.email} (${orphan.uid})`);
  }

  console.log('\n🎉 Cleanup completed successfully!\n');
}

async function main() {
  const [cmd, arg, arg2, arg3] = process.argv.slice(2);

  switch (cmd) {
    case 'list':
      await listUsers();
      break;
    case 'delete':
      await deleteUser(arg);
      break;
    case 'clean-orphans':
      await cleanOrphans();
      break;
    case 'create-superadmin':
      await createSuperAdmin(arg, arg2, arg3);
      break;
    default:
      console.log(`
Attendiphi Auth Admin Management Utility

Commands:
  node scripts/manage_auth_admins.js list
      List all Firebase Auth users and their Firestore status

  node scripts/manage_auth_admins.js delete <email-or-uid>
      Delete user from Firebase Auth and Firestore

  node scripts/manage_auth_admins.js clean-orphans
      Delete all Firebase Auth accounts that have no Firestore admin document

  node scripts/manage_auth_admins.js create-superadmin <email> <password> [name]
      Create/update Auth user + Firestore Super Admin (password via CLI only)
`);
      break;
  }
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
