import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

const dir = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(resolve(dir, '../../firestore.rules'), 'utf8');

const testEnv = await initializeTestEnvironment({
  projectId: 'demo-attendiphi',
  firestore: {
    rules,
    host: '127.0.0.1',
    port: 8088,
  },
});

const unauth = testEnv.unauthenticatedContext().firestore();
const adminAuth = testEnv.authenticatedContext('admin-uid').firestore();
const otherAuth = testEnv.authenticatedContext('other-uid').firestore();
const superAuth = testEnv.authenticatedContext('super-uid').firestore();

await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await db.doc('admins/super-uid').set({
    uid: 'super-uid',
    email: 'super@example.com',
    name: 'Super',
    role: 'superadmin',
    isActive: true,
    createdBy: 'super-uid',
  });
  await db.doc('admins/admin-uid').set({
    uid: 'admin-uid',
    email: 'admin@example.com',
    name: 'Admin',
    role: 'admin',
    isActive: true,
    createdBy: 'super-uid',
  });
});

await assertFails(unauth.collection('admins').get());
await assertFails(unauth.doc('admins/admin-uid').get());
await assertFails(unauth.collection('checkIns').get());
await assertFails(unauth.doc('checkIns/c1').set({ userName: 'A' }, { merge: true }));
await assertFails(unauth.doc('checkIns/c1').delete());
await assertFails(unauth.doc('employees/e1').set({ name: 'X' }));
await assertFails(unauth.doc('locations/l1').set({ name: 'X' }));
await assertFails(unauth.collection('admin_devices').get());
await assertFails(unauth.collection('admin_notifications').get());

await assertSucceeds(
  unauth.doc('checkIns/c1').set({
    userName: 'Rahul Sharma',
    userPhone: '+919876543210',
    locationId: 'location_x',
    locationName: 'Main Hall',
    type: 'member',
  }),
);
await assertFails(unauth.doc('checkIns/c1').get());
await assertFails(unauth.doc('checkIns/c1').update({ userName: 'Hacked' }));
await assertFails(unauth.doc('checkIns/c1').delete());

await assertFails(
  adminAuth.doc('admins/promoted').set({
    uid: 'promoted',
    email: 'p@example.com',
    name: 'P',
    role: 'superadmin',
    isActive: true,
    createdBy: 'admin-uid',
  }),
);

// Regular admin can check if a new doc exists (resource == null)
await assertSucceeds(adminAuth.doc('admins/uncreated-uid').get());

await assertSucceeds(
  adminAuth.doc('admins/child-uid').set({
    uid: 'child-uid',
    email: 'child@example.com',
    name: 'Child Admin',
    role: 'admin',
    isActive: true,
    createdBy: 'admin-uid',
  }),
);

// Regular admin can get the admin they created
await assertSucceeds(adminAuth.doc('admins/child-uid').get());
// Other admin cannot get admin created by admin-uid
await assertFails(otherAuth.doc('admins/child-uid').get());
// Regular admin can list admins created by them
await assertSucceeds(
  adminAuth.collection('admins').where('createdBy', '==', 'admin-uid').get(),
);
// Regular admin cannot list all admins without createdBy filter
await assertFails(adminAuth.collection('admins').get());
// Super admin can list all admins
await assertSucceeds(superAuth.collection('admins').get());

await assertFails(
  adminAuth.doc('admins/admin-uid').update({ role: 'superadmin' }),
);

await assertFails(otherAuth.doc('employees/e1').set({ name: 'Nope' }));
await assertFails(otherAuth.doc('locations/l1').set({ name: 'Nope' }));

await assertSucceeds(superAuth.doc('employees/e1').set({ name: 'Member' }));
// Full employees roster is admin-only (AUD-SEC-002).
await assertFails(unauth.collection('employees').get());
await assertFails(unauth.doc('employees/e1').get());
await assertSucceeds(adminAuth.doc('employees/e1').get());

// Public projection for QR typeahead — active-only presence model.
// Unfiltered list is denied; clients must query isActive==true.
await assertFails(unauth.collection('publicMembers').get());
await assertFails(
  unauth.doc('publicMembers/m1').set({
    id: 'm1',
    name: 'Public',
    phone: '9876543210',
    isActive: true,
  }),
);
await assertSucceeds(
  adminAuth.doc('publicMembers/m1').set({
    id: 'm1',
    name: 'Public',
    phone: '9876543210',
    isActive: true,
    updatedAt: '2026-10-09T00:00:00.000',
  }),
);
// Admins cannot write inactive projections (must delete instead).
await assertFails(
  adminAuth.doc('publicMembers/m-inactive-write').set({
    id: 'm-inactive-write',
    name: 'Inactive',
    phone: '9876543219',
    isActive: false,
    updatedAt: '2026-10-09T00:00:00.000',
  }),
);
await assertFails(
  adminAuth.doc('publicMembers/m2').set({
    id: 'm2',
    name: 'Leak',
    phone: '9876543211',
    isActive: true,
    email: 'leak@example.com',
    updatedAt: '2026-10-09T00:00:00.000',
  }),
);
await assertSucceeds(unauth.doc('publicMembers/m1').get());
await assertSucceeds(
  unauth.collection('publicMembers').where('isActive', '==', true).get(),
);
// Seed a legacy inactive projection (rules-disabled) — anonymous must not read it.
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  await ctx.firestore().doc('publicMembers/m-legacy-inactive').set({
    id: 'm-legacy-inactive',
    name: 'Legacy Inactive',
    phone: '9000000099',
    isActive: false,
    updatedAt: '2026-10-09T00:00:00.000',
  });
});
await assertFails(unauth.doc('publicMembers/m-legacy-inactive').get());
await assertSucceeds(adminAuth.doc('publicMembers/m-legacy-inactive').delete());

// Missing isActive must not be anonymously readable.
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  await ctx.firestore().doc('publicMembers/m-missing-active').set({
    id: 'm-missing-active',
    name: 'No Flag',
    phone: '9000000088',
    updatedAt: '2026-10-09T00:00:00.000',
  });
});
await assertFails(unauth.doc('publicMembers/m-missing-active').get());
await assertSucceeds(adminAuth.doc('publicMembers/m-missing-active').delete());

// Unauthenticated clients cannot update/delete publicMembers.
await assertFails(
  unauth.doc('publicMembers/m1').update({ name: 'Hacked' }),
);
await assertFails(unauth.doc('publicMembers/m1').delete());
await assertFails(
  unauth.doc('publicMembers/m1').set({
    id: 'm1',
    name: 'Overwrite',
    phone: '9876543210',
    isActive: true,
    updatedAt: '2026-10-09T00:00:00.000',
  }),
);

// Admin employee CRUD (create already covered); update + delete.
await assertSucceeds(
  adminAuth.doc('employees/e1').update({ name: 'Member Updated', isActive: false }),
);
await assertSucceeds(adminAuth.doc('employees/e1').delete());
await assertFails(unauth.doc('employees/e2').set({ name: 'Nope' }));
await assertSucceeds(
  adminAuth.doc('employees/e2').set({
    id: 'e2',
    name: 'Member Two',
    phone: '9000000000',
    isActive: true,
  }),
);
await assertSucceeds(
  adminAuth.doc('publicMembers/e2').set({
    id: 'e2',
    name: 'Member Two',
    phone: '9000000000',
    isActive: true,
    updatedAt: '2026-10-09T00:00:00.000',
  }),
);
await assertFails(otherAuth.doc('publicMembers/e2').delete());
await assertSucceeds(adminAuth.doc('publicMembers/e2').delete());
await assertSucceeds(adminAuth.doc('employees/e2').delete());

// Check-in create rejects oversized / privileged fields.
await assertFails(
  unauth.doc('checkIns/c2').set({
    userName: 'X',
    userPhone: '+919876543210',
    locationId: 'location_x',
    isAdmin: true,
  }),
);
await assertSucceeds(
  unauth.doc('checkIns/c3').set({
    id: 'c3',
    userName: 'Visitor',
    userPhone: '9876543210',
    locationId: 'location_x',
    locationName: 'Hall',
    type: 'member',
    memberId: 'e2',
  }),
);
await assertFails(unauth.doc('checkIns/c3').get());
await assertSucceeds(adminAuth.doc('checkIns/c3').get());

await assertSucceeds(adminAuth.collection('checkIns').get());
await assertFails(otherAuth.collection('admin_devices').get());
await assertFails(otherAuth.collection('admin_notifications').doc('n1').set({
  title: 'x',
}));

// Face templates + Storage-adjacent collections stay locked.
await assertFails(unauth.doc('faceTemplates/e1').get());
await assertFails(unauth.doc('faceTemplates/e1').set({ memberId: 'e1' }));
await assertSucceeds(
  adminAuth.doc('faceTemplates/e1').set({ memberId: 'e1', updatedAt: 't' }),
);
await assertSucceeds(adminAuth.doc('faceTemplates/e1').delete());
await assertFails(unauth.doc('mail/m1').get());
await assertFails(unauth.doc('admin_password_resets/r1').get());

await testEnv.cleanup();
console.log('firestore rules tests passed');
