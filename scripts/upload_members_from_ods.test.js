/**
 * Safe unit tests for ODS upload helpers (no Firebase, no network, no SA).
 * Run: node --test scripts/upload_members_from_ods.test.js
 */
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { normalizePhone, queueEmployeeAndPublicMember } = require('./upload_members_from_ods.js');

describe('normalizePhone', () => {
  it('strips country code and non-digits', () => {
    assert.equal(normalizePhone('+91 98765-43210'), '9876543210');
    assert.equal(normalizePhone('09876543210'), '9876543210');
  });
});

describe('queueEmployeeAndPublicMember', () => {
  it('batches employee merge + publicMembers upsert for active members', () => {
    const ops = [];
    const batch = {
      set(ref, data, opts) {
        ops.push({ type: 'set', path: ref.path, data, opts });
      },
      delete(ref) {
        ops.push({ type: 'delete', path: ref.path });
      },
    };
    const db = {
      collection(name) {
        return {
          doc(id) {
            return { path: `${name}/${id}`, id };
          },
        };
      },
    };

    const plan = queueEmployeeAndPublicMember(batch, db, {
      id: 'e1',
      isActive: true,
      employeeFields: { name: 'Alice', phone: '9876543210', isActive: true },
    });

    assert.equal(plan.op, 'upsert');
    assert.equal(ops.length, 2);
    assert.equal(ops[0].path, 'employees/e1');
    assert.equal(ops[1].path, 'publicMembers/e1');
    assert.equal(ops[1].data.isActive, true);
    assert.equal(ops[1].data.email, undefined);
  });

  it('batches employee merge + publicMembers delete for inactive members', () => {
    const ops = [];
    const batch = {
      set(ref, data) {
        ops.push({ type: 'set', path: ref.path, data });
      },
      delete(ref) {
        ops.push({ type: 'delete', path: ref.path });
      },
    };
    const db = {
      collection(name) {
        return {
          doc(id) {
            return { path: `${name}/${id}`, id };
          },
        };
      },
    };

    const plan = queueEmployeeAndPublicMember(batch, db, {
      id: 'e2',
      isActive: false,
      employeeFields: { name: 'Bob', phone: '9000000000', isActive: false },
    });

    assert.equal(plan.op, 'delete');
    assert.ok(ops.some((o) => o.type === 'delete' && o.path === 'publicMembers/e2'));
  });
});
