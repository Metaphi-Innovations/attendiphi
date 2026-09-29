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
await assertSucceeds(adminAuth.collection('checkIns').get());
await assertFails(otherAuth.collection('admin_devices').get());
await assertFails(otherAuth.collection('admin_notifications').doc('n1').set({
  title: 'x',
}));

await testEnv.cleanup();
console.log('firestore rules tests passed');
