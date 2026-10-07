// GENERATED COPY - DO NOT EDIT. Source of truth: vai-app/src/lib/scientific-radar/config.ts
// Re-sync with: node scripts/sync-pulse-engine.mjs <path to this directory>   (see ENGINE_MANIFEST.json)
// Scientific Radar — NCBI/PubMed access configuration. Read from the environment; never hard-coded, never a personal address.
//
//   VAI_PUBMED_CONTACT_EMAIL  (recommended) a VAI operational mailbox NCBI can contact if the traffic misbehaves. Not set by default: when
//                             unset the `email` parameter is simply omitted (NCBI only needs it to reach the developer before blocking).
//   NCBI_API_KEY              (optional)  raises the NCBI limit from 3 to 10 requests/second. Not required: the cache keeps volume tiny.


export const RADAR_TOOL = "vai-scientific-radar";
export const CONTACT_EMAIL_ENV = "VAI_PUBMED_CONTACT_EMAIL";
export const API_KEY_ENV = "NCBI_API_KEY";
export const EUTILS_BASE = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils";

/** NCBI allows 3 requests/second without a key (10 with one). Stay safely under both. */
export const MIN_INTERVAL_MS_NO_KEY = 400;
export const MIN_INTERVAL_MS_WITH_KEY = 150;
export const REQUEST_TIMEOUT_MS = 6000;
/** Server-side cache lifetime. PubMed adds records daily; hours-level freshness is ample for a literature radar. */
export const RADAR_REVALIDATE_SECONDS = 3 * 60 * 60;
/** After a failed upstream call, skip PubMed for this long (serve stale/unavailable) so an outage is never hammered or made slow. */
export const BREAKER_COOLDOWN_MS = 60_000;

export interface PubMedConfig { tool: string; email: string | null; apiKey: string | null; minIntervalMs: number }

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
export function readPubMedConfig(env: Record<string, string | undefined> = process.env): PubMedConfig {
  const email = env[CONTACT_EMAIL_ENV]?.trim();
  const apiKey = env[API_KEY_ENV]?.trim();
  return {
    tool: RADAR_TOOL,
    email: email && EMAIL_RE.test(email) ? email : null,
    apiKey: apiKey || null,
    minIntervalMs: apiKey ? MIN_INTERVAL_MS_WITH_KEY : MIN_INTERVAL_MS_NO_KEY,
  };
}
