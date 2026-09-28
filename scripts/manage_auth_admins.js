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
  const [cmd, arg] = process.argv.slice(2);

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
`);
      break;
  }
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
