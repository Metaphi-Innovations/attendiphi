/**
 * Safe local unit tests for backfill helpers (no Firebase, no network).
 * Run: node --test scripts/backfill_public_members.test.js
 */
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  parseArgs,
  buildPublicMemberPayload,
  employeeIsActive,
  shouldSkipPayload,
  planPublicMemberOp,
  redactForLog,
  runBackfill,
  MAX_BATCH_SIZE,
} = require('./backfill_public_members.js');

describe('parseArgs', () => {
  it('defaults and dry-run', () => {
    const opts = parseArgs(['--dry-run', '--page-size=50', '--batch-size=999']);
    assert.equal(opts.dryRun, true);
    assert.equal(opts.pageSize, 50);
    assert.equal(opts.batchSize, MAX_BATCH_SIZE);
  });
});

describe('buildPublicMemberPayload / employeeIsActive', () => {
  it('projects only public fields and always sets isActive true', () => {
    const payload = buildPublicMemberPayload('e1', {
      name: '  Rohan  ',
      phone: ' 9876543210 ',
      email: 'secret@example.com',
      photoUrl: 'https://cdn/x.jpg',
      faceEmbedding: [1, 2, 3],
      isActive: false,
    });
    assert.deepEqual(Object.keys(payload).sort(), [
      'id',
      'isActive',
      'name',
      'phone',
      'updatedAt',
    ]);
    assert.equal(payload.name, 'Rohan');
    assert.equal(payload.phone, '9876543210');
    assert.equal(payload.isActive, true);
    assert.equal(payload.email, undefined);
  });

  it('treats missing isActive as active', () => {
    assert.equal(employeeIsActive({}), true);
    assert.equal(employeeIsActive({ isActive: false }), false);
  });
});

describe('planPublicMemberOp', () => {
  it('upserts active employees', () => {
    const plan = planPublicMemberOp('a', {
      name: 'Alice',
      phone: '1111111111',
      isActive: true,
    });
    assert.equal(plan.op, 'upsert');
    assert.equal(plan.payload.isActive, true);
  });

  it('deletes inactive employee projections (cleanup)', () => {
    const plan = planPublicMemberOp('b', {
      name: 'Bob',
      phone: '2222222222',
      isActive: false,
    });
    assert.equal(plan.op, 'delete');
    assert.equal(plan.reason, 'inactive');
  });

  it('deletes empty-name active projections (not discoverable)', () => {
    const plan = planPublicMemberOp('c', { name: '  ', phone: '333' });
    assert.equal(plan.op, 'delete');
    assert.equal(plan.reason, 'empty name');
  });
});

describe('shouldSkipPayload / redactForLog', () => {
  it('skips empty names and redacts phones', () => {
    assert.equal(shouldSkipPayload({ name: '' }), true);
    assert.equal(shouldSkipPayload({ name: 'A' }), false);
    const redacted = redactForLog({
      id: 'e1',
      name: 'Rohan',
      phone: '9876543210',
      isActive: true,
      updatedAt: 't',
    });
    assert.equal(redacted.phone, '[redacted]');
  });
});

function mockCollectionRouter(collections) {
  return {
    collection(name) {
      const impl = collections[name];
      if (!impl) throw new Error(`unexpected collection ${name}`);
      return impl;
    },
    batch() {
      return {
        set() {},
        delete() {},
        async commit() {
          throw new Error('commit should not run in dry-run');
        },
      };
    },
  };
}

describe('runBackfill dry-run with mock db', () => {
  it('pages, deletes inactive, upserts active, cleans orphans, writes nothing', async () => {
    const employeePages = [
      {
        empty: false,
        size: 2,
        docs: [
          { id: 'a', data: () => ({ name: 'Alice', phone: '1111111111' }) },
          {
            id: 'b',
            data: () => ({ name: 'Bob', phone: '2222222222', isActive: false }),
          },
        ],
      },
      {
        empty: false,
        size: 1,
        docs: [{ id: 'c', data: () => ({ name: '', phone: '3333333333' }) }],
      },
      { empty: true, size: 0, docs: [] },
    ];
    const publicPages = [
      {
        empty: false,
        size: 2,
        docs: [
          { id: 'a', data: () => ({ name: 'Alice', isActive: true }) },
          { id: 'orphan-1', data: () => ({ name: 'Ghost', isActive: true }) },
        ],
      },
      { empty: true, size: 0, docs: [] },
    ];

    let empCalls = 0;
    let pubCalls = 0;
    const db = mockCollectionRouter({
      employees: {
        orderBy() {
          return this;
        },
        limit() {
          return this;
        },
        startAfter() {
          return this;
        },
        async get() {
          const page = employeePages[empCalls] || {
            empty: true,
            size: 0,
            docs: [],
          };
          empCalls += 1;
          return page;
        },
      },
      publicMembers: {
        orderBy() {
          return this;
        },
        limit() {
          return this;
        },
        startAfter() {
          return this;
        },
        async get() {
          const page = publicPages[pubCalls] || {
            empty: true,
            size: 0,
            docs: [],
          };
          pubCalls += 1;
          return page;
        },
      },
    });

    const logs = [];
    const summary = await runBackfill({
      db,
      dryRun: true,
      pageSize: 2,
      batchSize: 10,
      log: (m) => logs.push(m),
      warn: () => {},
    });

    assert.equal(summary.scanned, 3);
    assert.equal(summary.wouldWrite, 1);
    assert.equal(summary.wouldDelete, 2); // inactive + empty name
    assert.equal(summary.wouldDeleteOrphans, 1);
    assert.equal(summary.written, 0);
    assert.equal(summary.deleted, 0);
    assert.equal(summary.orphansDeleted, 0);
    assert.ok(logs.some((l) => l.includes('[dry-run] upsert')));
    assert.ok(logs.some((l) => l.includes('[dry-run] delete') && l.includes('orphan')));
    assert.ok(logs.some((l) => l.includes('[redacted]')));
  });

  it('malformed employee with missing phone still upserts when named and active', async () => {
    const plan = planPublicMemberOp('m1', { name: 'Malformed', isActive: true });
    assert.equal(plan.op, 'upsert');
    assert.equal(plan.payload.phone, '');
  });
});
