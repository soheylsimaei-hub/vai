// GENERATED COPY - DO NOT EDIT. Source of truth: vai-app/src/lib/scientific-radar/pubmed.ts
// Re-sync with: node scripts/sync-pulse-engine.mjs <path to this directory>   (see ENGINE_MANIFEST.json)
// Scientific Radar — minimal NCBI E-utilities client (ESearch + ESummary only). Official API, no scraping.
//   * identifies itself with `tool` (and `email` / `api_key` when configured)
//   * serialises requests through a spacing limiter so it never exceeds NCBI's per-second limit from one process
//   * bounded timeout, one short retry for 429/5xx/network errors, typed errors so callers can degrade gracefully
// POST is used because the veterinary journal base makes the query term long.


import { EUTILS_BASE, REQUEST_TIMEOUT_MS, type PubMedConfig } from "./config";
import type { ESearchParams } from "./query";

export class PubMedUnavailableError extends Error { constructor(message: string) { super(message); this.name = "PubMedUnavailableError"; } }
export class PubMedResponseError extends Error { constructor(message: string) { super(message); this.name = "PubMedResponseError"; } }

export interface ESearchResult { count: number; ids: string[]; warnings: string[] }
export interface PubMedClient {
  esearch(params: ESearchParams): Promise<ESearchResult>;
  esummary(ids: readonly string[]): Promise<Record<string, unknown>>;
}
export interface ClientOptions { config: PubMedConfig; fetcher?: typeof fetch; sleep?: (ms: number) => Promise<void>; now?: () => number }

export function createPubMedClient(opts: ClientOptions): PubMedClient {
  const { config } = opts;
  const fetcher = opts.fetcher ?? fetch;
  const sleep = opts.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const now = opts.now ?? Date.now;
  // Acquisition is serialised and measured from each request's ACTUAL start, so a late-waking earlier waiter can never shrink the gap that
  // a later one leaves (fixed pre-reserved slots could). The loop also guards against timers firing marginally early.
  let lastStart = -Infinity;
  let chain: Promise<void> = Promise.resolve();
  const acquire = (): Promise<void> => {
    const turn = chain.then(async () => {
      // bounded: even a broken clock can never make this loop spin forever
      for (let i = 0, wait = lastStart + config.minIntervalMs - now(); wait > 0 && i < 20; i++, wait = lastStart + config.minIntervalMs - now()) await sleep(wait);
      lastStart = now();
    });
    chain = turn.catch(() => undefined);
    return turn;
  };

  async function post(path: string, params: Record<string, string | number>): Promise<unknown> {
    const body = new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)]));
    body.set("tool", config.tool);
    if (config.email) body.set("email", config.email);
    if (config.apiKey) body.set("api_key", config.apiKey);
    let lastError = "unknown error";
    for (let attempt = 0; attempt < 2; attempt++) {
      await acquire();
      try {
        const res = await fetcher(`${EUTILS_BASE}/${path}`, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS), cache: "no-store" });
        if (res.status === 429 || res.status >= 500) { lastError = `HTTP ${res.status}`; await sleep(800); continue; }
        if (!res.ok) throw new PubMedResponseError(`HTTP ${res.status}`);
        try { return await res.json(); } catch { throw new PubMedResponseError("response was not valid JSON"); }
      } catch (e) {
        if (e instanceof PubMedResponseError) throw e;
        lastError = e instanceof Error ? e.message : String(e);
        await sleep(800);
      }
    }
    throw new PubMedUnavailableError(`PubMed unavailable (${lastError})`);
  }

  return {
    async esearch(params) {
      const json = (await post("esearch.fcgi", params as unknown as Record<string, string | number>)) as { esearchresult?: { count?: string; idlist?: string[]; ERROR?: string; warninglist?: Record<string, string[]> }; error?: string };
      const r = json?.esearchresult;
      if (!r || json.error || r.ERROR) throw new PubMedResponseError(`ESearch error: ${json?.error ?? r?.ERROR ?? "no result"}`);
      const warnings = Object.values(r.warninglist ?? {}).flat().filter((w) => typeof w === "string" && w.length > 0);
      return { count: Number.parseInt(r.count ?? "0", 10) || 0, ids: (r.idlist ?? []).filter((id) => /^\d+$/.test(id)), warnings };
    },
    async esummary(ids) {
      if (ids.length === 0) return {};
      const json = (await post("esummary.fcgi", { db: "pubmed", id: ids.join(","), retmode: "json" })) as { result?: Record<string, unknown>; error?: string };
      if (!json?.result || json.error) throw new PubMedResponseError(`ESummary error: ${json?.error ?? "no result"}`);
      return json.result;
    },
  };
}
