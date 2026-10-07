// VAI Pulse — the build-time data layer. vai.vet is static (GitHub Pages): there is no server to cache PubMed responses at request time, so the
// site is rebuilt on a schedule and each build takes ONE snapshot of PubMed. That snapshot is the cache:
//   * all 120 view x discipline x period combinations are fetched by the synced Scientific Radar engine (same queries and labelling as app.vai.vet)
//   * the engine's request limiter keeps the build under NCBI's per-second limit; ESummary is batched over the UNIQUE ids across combinations
//   * a failed combination is recorded, not hidden; an outage (consecutive failures) or a missing primary view throws
//   * a successful snapshot is written to .pulse-cache/ (restored between CI runs); on failure the last good snapshot is used and flagged as such
// Never touches the network at page-view time: visitors only ever receive static HTML.

import { mkdirSync, readFileSync, renameSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { readPubMedConfig } from "./engine/config";
import { createPubMedClient, type PubMedClient } from "./engine/pubmed";
import { buildESearchParams } from "./engine/query";
import { toRecords, type RadarRecord } from "./engine/records";
import { allRequests, comboKey, DEFAULT_PULSE, type PulseRequest } from "./routes";

/** Records shown per page. Pulse is "what's new", not a database: the page states the total and links nothing deeper. */
export const PULSE_PAGE_SIZE = 40;
export const SNAPSHOT_VERSION = 1;
export const FRESH_MS = 60 * 60 * 1000; // a cached snapshot younger than this is reused instead of refetched (repeat local builds)
export const MAX_STALE_MS = 14 * 24 * 60 * 60 * 1000; // beyond this a cached snapshot is too old to show at all
export const MAX_FAILED_COMBOS_FRACTION = 0.1;
export const OUTAGE_AFTER_CONSECUTIVE_FAILURES = 3;
const ESUMMARY_BATCH = 100;

export interface PulseCombo { total: number; ids: string[]; ok: boolean }
export interface PulseSnapshot { version: number; generatedAt: string; pageSize: number; combos: Record<string, PulseCombo>; records: Record<string, RadarRecord> }
export type SnapshotSource = "live" | "cached" | "unavailable";
export interface LoadedSnapshot { source: SnapshotSource; snapshot: PulseSnapshot | null }

export class PulseUnavailableError extends Error { constructor(message: string) { super(message); this.name = "PulseUnavailableError"; } }

export async function buildSnapshot(client: PubMedClient, now: () => Date = () => new Date(), log: (m: string) => void = () => {}): Promise<PulseSnapshot> {
  const requests = allRequests();
  const combos: Record<string, PulseCombo> = {};
  let consecutive = 0;
  let failed = 0;
  for (const r of requests) {
    try {
      const s = await client.esearch(buildESearchParams({ ...r, page: 1, reviews: false }, PULSE_PAGE_SIZE));
      combos[comboKey(r)] = { total: s.count, ids: s.ids, ok: true };
      consecutive = 0;
    } catch (e) {
      failed++; consecutive++;
      combos[comboKey(r)] = { total: 0, ids: [], ok: false };
      log(`combo ${comboKey(r)} failed: ${e instanceof Error ? e.message : e}`);
      if (consecutive >= OUTAGE_AFTER_CONSECUTIVE_FAILURES) throw new PulseUnavailableError(`PubMed unreachable (${consecutive} consecutive failures)`);
    }
  }
  if (failed / requests.length > MAX_FAILED_COMBOS_FRACTION) throw new PulseUnavailableError(`${failed}/${requests.length} combinations failed`);
  const primary = combos[comboKey(DEFAULT_PULSE)];
  if (!primary?.ok || primary.ids.length === 0) throw new PulseUnavailableError("the primary Latest view returned nothing");

  const unique = [...new Set(Object.values(combos).flatMap((c) => c.ids))];
  const records: Record<string, RadarRecord> = {};
  for (let i = 0; i < unique.length; i += ESUMMARY_BATCH) {
    const batch = unique.slice(i, i + ESUMMARY_BATCH);
    let result: Record<string, unknown>;
    try { result = await client.esummary(batch); } catch (e) { throw new PulseUnavailableError(`ESummary failed: ${e instanceof Error ? e.message : e}`); }
    for (const rec of toRecords(batch, result)) records[rec.pmid] = rec;
  }
  for (const c of Object.values(combos)) c.ids = c.ids.filter((id) => records[id]);
  return { version: SNAPSHOT_VERSION, generatedAt: now().toISOString(), pageSize: PULSE_PAGE_SIZE, combos, records };
}

// ---- cache file --------------------------------------------------------------------------------------------------------------
export const CACHE_FILE = join(".pulse-cache", "snapshot.json");
export function writeCache(snapshot: PulseSnapshot, path = CACHE_FILE): void {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.tmp`;
  writeFileSync(tmp, JSON.stringify(snapshot));
  renameSync(tmp, path);
}
export function readCache(path = CACHE_FILE): PulseSnapshot | null {
  if (!existsSync(path)) return null;
  try {
    const s = JSON.parse(readFileSync(path, "utf-8")) as PulseSnapshot;
    return s?.version === SNAPSHOT_VERSION && s.combos && s.records && s.generatedAt ? s : null;
  } catch { return null; }
}

export interface LoadDeps { client?: PubMedClient; now?: () => Date; cachePath?: string; log?: (m: string) => void }

/** live (fresh build, or a cache younger than FRESH_MS) -> cached (last good snapshot after a failure) -> unavailable. Never throws. */
export async function loadSnapshotUncached(deps: LoadDeps = {}): Promise<LoadedSnapshot> {
  const now = deps.now ?? (() => new Date());
  const log = deps.log ?? ((m: string) => console.warn(`[pulse] ${m}`));
  const cachePath = deps.cachePath ?? CACHE_FILE;
  const cached = readCache(cachePath);
  const ageMs = cached ? now().getTime() - new Date(cached.generatedAt).getTime() : Infinity;
  if (cached && ageMs >= 0 && ageMs < FRESH_MS) return { source: "live", snapshot: cached };
  try {
    const client = deps.client ?? createPubMedClient({ config: readPubMedConfig() });
    const snapshot = await buildSnapshot(client, now, log);
    writeCache(snapshot, cachePath);
    return { source: "live", snapshot };
  } catch (e) {
    log(`snapshot failed: ${e instanceof Error ? e.message : e}`);
    if (cached && ageMs < MAX_STALE_MS) { log(`using the cached snapshot from ${cached.generatedAt}`); return { source: "cached", snapshot: cached }; }
    return { source: "unavailable", snapshot: null };
  }
}

/** One snapshot per build process, shared by getStaticPaths, every page and the homepage section (stored on globalThis so separately
 * bundled chunks of the Astro build cannot each trigger their own fetch). */
const KEY = Symbol.for("vai.pulse.snapshot");
export function loadSnapshot(): Promise<LoadedSnapshot> {
  const g = globalThis as unknown as Record<symbol, Promise<LoadedSnapshot> | undefined>;
  return (g[KEY] ??= loadSnapshotUncached());
}

export function comboRecords(s: PulseSnapshot, r: PulseRequest): { total: number; records: RadarRecord[]; ok: boolean } {
  const c = s.combos[comboKey(r)];
  if (!c) return { total: 0, records: [], ok: false };
  return { total: c.total, ok: c.ok, records: c.ids.map((id) => s.records[id]).filter(Boolean) };
}
