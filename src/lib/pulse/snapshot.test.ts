import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fakePubMed } from "./fixtures";
import { FRESH_MS, MAX_STALE_MS, PULSE_PAGE_SIZE, PulseUnavailableError, buildSnapshot, comboRecords, loadSnapshotUncached, readCache, writeCache } from "./snapshot";
import { DEFAULT_PULSE, comboKey } from "./routes";

const tmpCache = () => join(mkdtempSync(join(tmpdir(), "pulse-")), "snapshot.json");
const T0 = new Date("2026-10-07T12:00:00Z");

test("a snapshot covers all 120 combinations with ONE esearch each, and esummary runs only over the unique ids (dedupe)", async () => {
  const f = fakePubMed({ perCombo: 3 });
  const s = await buildSnapshot(f.client, () => T0);
  assert.equal(f.log.esearch, 120);
  assert.equal(Object.keys(s.combos).length, 120);
  const unique = new Set(Object.values(s.combos).flatMap((c) => c.ids));
  assert.equal(unique.size, 10, "ids overlap across combinations in the fixture");
  assert.equal(f.log.summaryBatches.flat().length, 10, "no id is summarised twice");
  assert.equal(s.generatedAt, "2026-10-07T12:00:00.000Z");
  assert.equal(s.pageSize, PULSE_PAGE_SIZE);
  assert.equal(comboRecords(s, DEFAULT_PULSE).records.length, 3);
});

test("esummary is batched (<=100 ids per request)", async () => {
  let n = 0;
  const f = fakePubMed({ perCombo: 40 });
  f.client.esearch = async () => ({ count: 999, ids: Array.from({ length: 40 }, (_, i) => String(1000 + n * 40 + i + (n++ & 0))), warnings: [] });
  const s = await buildSnapshot(f.client, () => T0);
  assert.ok(f.log.summaryBatches.every((b) => b.length <= 100));
  assert.ok(f.log.summaryBatches.length > 1);
  assert.ok(Object.keys(s.records).length > 100);
});

test("an outage is detected after 3 consecutive failures instead of grinding through every combination", async () => {
  const f = fakePubMed({ failEsearchWhen: () => true });
  await assert.rejects(buildSnapshot(f.client, () => T0), PulseUnavailableError);
  assert.equal(f.log.esearch, 3);
});

test("a few isolated failures are tolerated and recorded; too many abort the build", async () => {
  const some = fakePubMed({ failEsearchWhen: (n) => n === 50 || n === 90 });
  const s = await buildSnapshot(some.client, () => T0);
  assert.equal(Object.values(s.combos).filter((c) => !c.ok).length, 2);
  const many = fakePubMed({ failEsearchWhen: (n) => n % 5 === 0 && n > 5 });
  await assert.rejects(buildSnapshot(many.client, () => T0), /combinations failed/);
});

test("the primary Latest view must have content; an esummary failure aborts", async () => {
  const f = fakePubMed({ failEsearchWhen: (n) => n === 0 });
  f.client.esearch = async () => ({ count: 0, ids: [], warnings: [] });
  await assert.rejects(buildSnapshot(f.client, () => T0), /primary Latest view/);
  await assert.rejects(buildSnapshot(fakePubMed({ failEsummary: true }).client, () => T0), /ESummary failed/);
});

test("ids PubMed could not describe are dropped from the combinations that listed them", async () => {
  const f = fakePubMed({ perCombo: 3 });
  const base = f.client.esummary;
  f.client.esummary = async (ids) => { const r = (await base(ids)) as Record<string, unknown>; delete r["42000003"]; return r; };
  const s = await buildSnapshot(f.client, () => T0);
  assert.ok(!Object.values(s.combos).some((c) => c.ids.includes("42000003")));
});

test("cache lifecycle: live -> written; fresh cache reused without any network; stale cache refreshed", async () => {
  const path = tmpCache();
  const f1 = fakePubMed();
  const first = await loadSnapshotUncached({ client: f1.client, now: () => T0, cachePath: path, log: () => {} });
  assert.equal(first.source, "live");
  assert.ok(readCache(path));
  const f2 = fakePubMed();
  const second = await loadSnapshotUncached({ client: f2.client, now: () => new Date(T0.getTime() + FRESH_MS - 1000), cachePath: path, log: () => {} });
  assert.equal(second.source, "live");
  assert.equal(f2.log.esearch, 0, "a fresh cache means zero PubMed calls");
  const f3 = fakePubMed();
  await loadSnapshotUncached({ client: f3.client, now: () => new Date(T0.getTime() + FRESH_MS + 1000), cachePath: path, log: () => {} });
  assert.equal(f3.log.esearch, 120);
});

test("outage behaviour: last good snapshot is served and flagged 'cached'; no cache -> 'unavailable'; an ancient cache is not shown", async () => {
  const path = tmpCache();
  await loadSnapshotUncached({ client: fakePubMed().client, now: () => T0, cachePath: path, log: () => {} });
  const down = fakePubMed({ failEsearchWhen: () => true });
  const later = new Date(T0.getTime() + 6 * 3600 * 1000);
  const r = await loadSnapshotUncached({ client: down.client, now: () => later, cachePath: path, log: () => {} });
  assert.equal(r.source, "cached");
  assert.equal(r.snapshot?.generatedAt, T0.toISOString());
  const none = await loadSnapshotUncached({ client: down.client, now: () => later, cachePath: tmpCache(), log: () => {} });
  assert.deepEqual(none, { source: "unavailable", snapshot: null });
  const ancient = await loadSnapshotUncached({ client: down.client, now: () => new Date(T0.getTime() + MAX_STALE_MS + 1000), cachePath: path, log: () => {} });
  assert.equal(ancient.source, "unavailable");
});

test("a corrupt or wrong-version cache file is ignored, never trusted", () => {
  const p = tmpCache();
  writeFileSync(p, "{not json");
  assert.equal(readCache(p), null);
  writeFileSync(p, JSON.stringify({ version: 999, combos: {}, records: {}, generatedAt: "x" }));
  assert.equal(readCache(p), null);
  assert.equal(readCache(join(tmpdir(), "does-not-exist.json")), null);
});

test("comboRecords handles a failed or unknown combination without throwing", async () => {
  const s = await buildSnapshot(fakePubMed({ failEsearchWhen: (n) => n === 7 }).client, () => T0);
  const failed = Object.entries(s.combos).find(([, c]) => !c.ok)!;
  assert.equal(failed[1].ids.length, 0);
  assert.deepEqual(comboRecords(s, { view: "latest", discipline: "nope", period: "30d" }), { total: 0, records: [], ok: false });
  void comboKey; void writeCache;
});
