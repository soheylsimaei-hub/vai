// VAI Pulse — the homepage "recent highlights". A transparent, deterministic rule, not an editorial or scientific judgement: it only reorders
// what PubMed's OWN metadata says (publication types), and every tier is shown with that PubMed label.
//   1. PubMed-typed guidelines and consensus statements (last 12 months)
//   2. PubMed-typed clinical trials, systematic reviews and meta-analyses (last 30 days, any discipline)
//   3. PubMed-typed reviews, then anything else added in the last 30 days
// Within a tier the newest PubMed entry first (a higher PMID was assigned later). At most `n` records, no duplicates.

import type { RadarRecord } from "./engine/records";
import { comboRecords, type PulseSnapshot } from "./snapshot";
import { ALL_FILTERS } from "./engine/query";

const TIER2 = new Set(["Randomized controlled trial", "Clinical trial", "Systematic review", "Meta-analysis"]);
const byNewest = (a: RadarRecord, b: RadarRecord) => Number(b.pmid) - Number(a.pmid);

export function pickHighlights(s: PulseSnapshot, n = 6): RadarRecord[] {
  const tier1 = comboRecords(s, { view: "guidelines", discipline: "all", period: "365d" }).records.filter((r) => r.evidenceKind === "guideline" || r.evidenceKind === "consensus").sort(byNewest);
  const recent = new Map<string, RadarRecord>();
  for (const f of ALL_FILTERS) for (const r of comboRecords(s, { view: "latest", discipline: f.id, period: "30d" }).records) recent.set(r.pmid, r);
  const pool = [...recent.values()].sort(byNewest);
  const tier2 = pool.filter((r) => r.pubTypes.some((t) => TIER2.has(t)));
  const tier3 = pool.filter((r) => r.pubTypes.includes("Review"));
  const out = new Map<string, RadarRecord>();
  // at most ceil(n/2) guidelines so the section stays a pulse of what is new, not a shelf of the year's guidelines
  for (const r of tier1.slice(0, Math.ceil(n / 2))) out.set(r.pmid, r);
  for (const list of [tier2, tier3, pool]) for (const r of list) { if (out.size >= n) break; if (!out.has(r.pmid)) out.set(r.pmid, r); }
  return [...out.values()].slice(0, n);
}
