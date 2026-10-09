#!/usr/bin/env node
/**
 * Idempotent backfill/cleanup: employees → publicMembers (active only).
 *
 * Model: presence in publicMembers means the member is active for QR typeahead.
 * Inactive employees keep full records on `employees` only; their publicMembers
 * docs are deleted (including legacy isActive:false projections).
 *
 * Usage:
 *   node scripts/backfill_public_members.js --dry-run
 *   node scripts/backfill_public_members.js --dry-run --page-size=200
 *   node scripts/backfill_public_members.js
 *
 * Options:
 *   --dry-run          No writes; prints redacted planned upserts/deletes
 *   --page-size=N      Employees page size (default 300)
 *   --batch-size=N     Ops per Firestore batch (default 400, max 450)
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS or Application Default Credentials.
 * Do not commit service account JSON. Do not run against production without approval.
 * Safe to re-run: active upserts merge; inactive/empty-name/orphan deletes are idempotent.
 * Never writes or deletes documents in `employees`.
 *
 * Orphan cleanup: after syncing from employees, deletes publicMembers/{id} when
 * no employees/{id} exists (stale leftovers). Approve before production runs.
 */

const DEFAULT_PAGE_SIZE = 300;
const DEFAULT_BATCH_SIZE = 400;
const MAX_BATCH_SIZE = 450;

function parseArgs(argv = process.argv.slice(2)) {
  const opts = {
    dryRun: false,
    pageSize: DEFAULT_PAGE_SIZE,
    batchSize: DEFAULT_BATCH_SIZE,
  };
  for (const arg of argv) {
    if (arg === '--dry-run') opts.dryRun = true;
    else if (arg.startsWith('--page-size=')) {
      opts.pageSize = Math.max(1, Number(arg.split('=')[1]) || DEFAULT_PAGE_SIZE);
    } else if (arg.startsWith('--batch-size=')) {
      const n = Number(arg.split('=')[1]) || DEFAULT_BATCH_SIZE;
      opts.batchSize = Math.min(MAX_BATCH_SIZE, Math.max(1, n));
    }
  }
  return opts;
}

/** Build publicMembers payload for an active employee only. */
function buildPublicMemberPayload(docId, data = {}) {
  return {
    id: String(docId),
    name: String(data.name || '').trim(),
    phone: String(data.phone || '').trim(),
    isActive: true,
    updatedAt: new Date().toISOString(),
  };
}

function employeeIsActive(data = {}) {
  return data.isActive !== false;
}

function shouldSkipPayload(payload) {
  return !payload.name;
}

/**
 * Plan one employee → publicMembers op.
 * Empty-name actives are deleted from publicMembers (not discoverable).
 * @returns {{ op: 'upsert'|'delete', id: string, payload?: object, reason?: string }}
 */
function planPublicMemberOp(docId, data = {}) {
  const id = String(docId);
  if (!employeeIsActive(data)) {
    return { op: 'delete', id, reason: 'inactive' };
  }
  const payload = buildPublicMemberPayload(id, data);
  if (shouldSkipPayload(payload)) {
    return { op: 'delete', id, reason: 'empty name' };
  }
  return { op: 'upsert', id, payload };
}

function redactForLog(payload) {
  return {
    id: payload.id,
    name: payload.name,
    phone: payload.phone ? '[redacted]' : '',
    isActive: payload.isActive,
    updatedAt: payload.updatedAt,
  };
}

/**
 * @param {object} options
 * @param {FirebaseFirestore.Firestore} options.db
 * @param {boolean} options.dryRun
 * @param {number} options.pageSize
 * @param {number} options.batchSize
 * @param {(msg: string) => void} [options.log]
 * @param {(msg: string) => void} [options.warn]
 */
async function runBackfill({
  db,
  dryRun,
  pageSize = DEFAULT_PAGE_SIZE,
  batchSize = DEFAULT_BATCH_SIZE,
  log = console.log,
  warn = console.warn,
}) {
  const summary = {
    scanned: 0,
    publicScanned: 0,
    wouldWrite: 0,
    wouldDelete: 0,
    wouldDeleteOrphans: 0,
    written: 0,
    deleted: 0,
    orphansDeleted: 0,
    skipped: 0,
    pages: 0,
    publicPages: 0,
    batches: 0,
    errors: [],
    dryRun: !!dryRun,
  };

  /** Every employees/{id} seen — used to detect orphan publicMembers. */
  const employeeIds = new Set();
  let lastDoc = null;
  let pending = [];

  async function flushPending() {
    if (pending.length === 0) return;
    if (dryRun) {
      for (const item of pending) {
        if (item.op === 'upsert') {
          summary.wouldWrite += 1;
          log(
            `[dry-run] upsert publicMembers/${item.id} ${JSON.stringify(redactForLog(item.payload))}`,
          );
        } else if (item.op === 'delete') {
          if (item.reason === 'orphan') {
            summary.wouldDeleteOrphans += 1;
          } else {
            summary.wouldDelete += 1;
          }
          log(`[dry-run] delete publicMembers/${item.id} (${item.reason || 'inactive'})`);
        }
      }
      pending = [];
      return;
    }

    const chunkSize = Math.min(batchSize, MAX_BATCH_SIZE);
    for (let i = 0; i < pending.length; i += chunkSize) {
      const slice = pending.slice(i, i + chunkSize);
      const batch = db.batch();
      let upserts = 0;
      let deletes = 0;
      for (const item of slice) {
        const ref = db.collection('publicMembers').doc(item.id);
        if (item.op === 'upsert') {
          batch.set(ref, item.payload, { merge: true });
          upserts += 1;
        } else if (item.op === 'delete') {
          batch.delete(ref);
          deletes += 1;
        }
      }
      try {
        await batch.commit();
        summary.written += upserts;
        let orphanDeletes = 0;
        for (const item of slice) {
          if (item.op === 'delete' && item.reason === 'orphan') orphanDeletes += 1;
        }
        summary.orphansDeleted += orphanDeletes;
        summary.deleted += deletes - orphanDeletes;
        summary.batches += 1;
        log(
          `Committed batch ${summary.batches} (upsert=${upserts} delete=${deletes}; written=${summary.written} deleted=${summary.deleted} orphansDeleted=${summary.orphansDeleted})`,
        );
      } catch (err) {
        const message = err && err.message ? err.message : String(err);
        summary.errors.push({
          batchIndex: summary.batches + 1,
          count: slice.length,
          message,
          ids: slice.map((s) => s.id),
        });
        warn(
          `Batch failed after scanned=${summary.scanned} written=${summary.written} deleted=${summary.deleted}: ${message}`,
        );
        pending = [];
        throw err;
      }
    }
    pending = [];
  }

  log(
    `Starting publicMembers backfill (active upsert / inactive delete) dryRun=${dryRun} pageSize=${pageSize} batchSize=${batchSize}`,
  );

  // eslint-disable-next-line no-constant-condition
  while (true) {
    let query = db.collection('employees').orderBy('__name__').limit(pageSize);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) break;

    summary.pages += 1;
    summary.scanned += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];

    for (const doc of snap.docs) {
      employeeIds.add(doc.id);
      const plan = planPublicMemberOp(doc.id, doc.data() || {});
      pending.push(plan);
      if (pending.length >= batchSize) {
        await flushPending();
      }
    }

    log(
      [
        `Employees page ${summary.pages}:`,
        `scanned=${summary.scanned}`,
        `written=${summary.written}`,
        `deleted=${summary.deleted}`,
        `wouldWrite=${summary.wouldWrite}`,
        `wouldDelete=${summary.wouldDelete}`,
      ].join(' '),
    );

    if (snap.size < pageSize) break;
  }

  await flushPending();

  // Phase 2: remove publicMembers with no matching employees/{id} (orphans).
  // Does not modify the employees collection.
  log(`Scanning publicMembers for orphans (known employees=${employeeIds.size})…`);
  lastDoc = null;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    let query = db.collection('publicMembers').orderBy('__name__').limit(pageSize);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) break;

    summary.publicPages += 1;
    summary.publicScanned += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];

    for (const doc of snap.docs) {
      if (employeeIds.has(doc.id)) continue;
      pending.push({ op: 'delete', id: doc.id, reason: 'orphan' });
      if (pending.length >= batchSize) {
        await flushPending();
      }
    }

    log(
      `publicMembers page ${summary.publicPages}: publicScanned=${summary.publicScanned} orphansDeleted=${summary.orphansDeleted} wouldDeleteOrphans=${summary.wouldDeleteOrphans}`,
    );

    if (snap.size < pageSize) break;
  }

  await flushPending();

  log(
    [
      'Summary:',
      `  dryRun=${summary.dryRun}`,
      `  pages=${summary.pages}`,
      `  scannedEmployees=${summary.scanned}`,
      `  publicPages=${summary.publicPages}`,
      `  publicScanned=${summary.publicScanned}`,
      `  written=${summary.written}`,
      `  deleted=${summary.deleted}`,
      `  orphansDeleted=${summary.orphansDeleted}`,
      `  wouldWrite=${summary.wouldWrite}`,
      `  wouldDelete=${summary.wouldDelete}`,
      `  wouldDeleteOrphans=${summary.wouldDeleteOrphans}`,
      `  batches=${summary.batches}`,
      `  errors=${summary.errors.length}`,
    ].join('\n'),
  );

  if (summary.errors.length > 0) {
    warn('Partial progress — fix credentials/quota and re-run (upsert/delete are idempotent).');
  }

  return summary;
}

async function main() {
  const admin = require('firebase-admin');
  const opts = parseArgs();
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  const db = admin.firestore();
  try {
    await runBackfill({ db, ...opts });
  } catch (err) {
    console.error('Backfill aborted with partial progress. Re-run after fixing the error.');
    console.error(err && err.message ? err.message : err);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  parseArgs,
  buildPublicMemberPayload,
  employeeIsActive,
  shouldSkipPayload,
  planPublicMemberOp,
  redactForLog,
  runBackfill,
  DEFAULT_PAGE_SIZE,
  DEFAULT_BATCH_SIZE,
  MAX_BATCH_SIZE,
};
