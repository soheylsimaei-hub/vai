import { test } from "node:test";
import assert from "node:assert/strict";
import { toRecord } from "./engine/records";
import { pickHighlights } from "./highlights";
import { item } from "./fixtures";
import { comboKey, type PulseRequest } from "./routes";
import type { PulseSnapshot } from "./snapshot";

const rec = (uid: number, pubtype: string[], title = `Paper ${uid}`) => toRecord(String(uid), item(String(uid), { pubtype: ["Journal Article", ...pubtype], title }))!;
function snap(combos: Record<string, number[]>, records: ReturnType<typeof rec>[]): PulseSnapshot {
  return { version: 1, generatedAt: "2026-10-07T12:00:00Z", pageSize: 40, combos: Object.fromEntries(Object.entries(combos).map(([k, ids]) => [k, { total: ids.length, ids: ids.map(String), ok: true }])), records: Object.fromEntries(records.map((r) => [r.pmid, r])) };
}
const K = (r: PulseRequest) => comboKey(r);

test("highlights: typed guidelines/consensus first (capped at 3 of 6), then trials/systematic reviews, then reviews, then the rest; newest first inside a tier", () => {
  const records = [
    rec(100, ["Practice Guideline"]), rec(101, ["Consensus Statement"]), rec(102, ["Practice Guideline"]), rec(103, ["Practice Guideline"]),
    rec(200, ["Randomized Controlled Trial, Veterinary"]), rec(201, ["Systematic Review"]), rec(202, ["Meta-Analysis"]),
    rec(300, ["Review"]), rec(400, []), rec(401, []),
    rec(500, [], "Updated guidelines for X"), // title mention only: must NOT be treated as a guideline
  ];
  const s = snap({
    [K({ view: "guidelines", discipline: "all", period: "365d" })]: [100, 101, 102, 103, 500],
    [K({ view: "latest", discipline: "all", period: "30d" })]: [200, 300, 400, 401, 500],
    [K({ view: "latest", discipline: "cardiology", period: "30d" })]: [201, 202],
  }, records);
  const out = pickHighlights(s, 6).map((r) => r.pmid);
  assert.deepEqual(out, ["103", "102", "101", "202", "201", "200"]);
  assert.ok(!out.includes("500") || out.indexOf("500") > 2, "a title-only mention never counts as tier 1");
});

test("highlights: no duplicates, never more than n, fills from the general pool when there are few typed records, and tolerates an empty snapshot", () => {
  const records = [rec(10, []), rec(11, []), rec(12, [])];
  const s = snap({ [K({ view: "latest", discipline: "all", period: "30d" })]: [10, 11, 12, 10] }, records);
  assert.deepEqual(pickHighlights(s, 6).map((r) => r.pmid), ["12", "11", "10"]);
  assert.equal(pickHighlights(s, 2).length, 2);
  assert.deepEqual(pickHighlights(snap({}, []), 6), []);
});
