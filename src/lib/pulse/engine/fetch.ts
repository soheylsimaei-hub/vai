// GENERATED COPY - DO NOT EDIT. Source of truth: vai-app/src/lib/scientific-radar/fetch.ts
// Re-sync with: node scripts/sync-pulse-engine.mjs <path to this directory>   (see ENGINE_MANIFEST.json)
// Scientific Radar — the pure fetch: PubMed -> RadarResult. Deliberately free of Next.js, `server-only` and environment access so the
// SAME code runs inside app.vai.vet (via service.ts, with the Next data cache) and inside the public vai.vet build (see
// scripts/sync-pulse-engine.mjs, which copies this engine into the vai repo). Keep it that way.

import type { PubMedClient } from "./pubmed";
import { PAGE_SIZE, buildESearchParams, type RadarRequest } from "./query";
import { toRecords, type RadarRecord } from "./records";

export interface RadarResult {
  total: number;
  records: RadarRecord[];
  page: number;
  pageSize: number;
  totalPages: number;
  retrievedAt: string;
  /** PubMed warnings about the query (e.g. an ignored phrase). Surfaced to logs and tests, not to readers. */
  warnings: string[];
}

/** The pure fetch: two E-utilities calls (ESearch for ids, ESummary for metadata). */
export async function fetchRadar(req: RadarRequest, client: PubMedClient, now: () => Date = () => new Date()): Promise<RadarResult> {
  const search = await client.esearch(buildESearchParams(req));
  const summary = await client.esummary(search.ids);
  const page = Math.max(1, Math.floor(req.page));
  return { total: search.count, records: toRecords(search.ids, summary), page, pageSize: PAGE_SIZE, totalPages: Math.max(1, Math.ceil(search.count / PAGE_SIZE)), retrievedAt: now().toISOString(), warnings: search.warnings };
}
