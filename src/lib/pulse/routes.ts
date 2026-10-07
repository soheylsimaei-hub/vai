// VAI Pulse — the static URL scheme. vai.vet is a static site, so every filter combination is its own pre-rendered page:
//   /pulse/                              Latest, All, 30 days            (default)
//   /pulse/guidelines/                   Guidelines & Consensus, All, 12 months (default)
//   /pulse/{view}/{discipline}/{period}/ every other combination (also reachable for the defaults, canonicalised to the short URLs)
// Pure and dependency-free apart from the synced engine's registries, so it is unit-tested without a build.

import { ALL_FILTERS, PERIODS, VIEWS, defaultPeriodFor, type RadarPeriod, type RadarView } from "./engine/query";

export interface PulseRequest { view: RadarView; discipline: string; period: RadarPeriod }
export const DEFAULT_PULSE: PulseRequest = { view: "latest", discipline: "all", period: "30d" };

export const isDefaultCombo = (r: PulseRequest): boolean => r.discipline === "all" && r.period === defaultPeriodFor(r.view);

export function pulseHref(r: PulseRequest): string {
  if (isDefaultCombo(r)) return r.view === "latest" ? "/pulse/" : "/pulse/guidelines/";
  return `/pulse/${r.view}/${r.discipline}/${r.period}/`;
}

export const comboKey = (r: PulseRequest): string => `${r.view}|${r.discipline}|${r.period}`;

export function allRequests(): PulseRequest[] {
  const out: PulseRequest[] = [];
  for (const v of VIEWS) for (const f of ALL_FILTERS) for (const p of PERIODS) out.push({ view: v.id, discipline: f.id, period: p.id });
  return out;
}

/** The short default URLs (and only those) belong in the sitemap and are the canonical address of their content. */
export const canonicalHref = (r: PulseRequest): string => pulseHref(r);

export function parseSlug(slug: string | undefined): PulseRequest | null {
  if (!slug) return DEFAULT_PULSE;
  if (slug === "guidelines") return { view: "guidelines", discipline: "all", period: defaultPeriodFor("guidelines") };
  const [view, discipline, period, ...rest] = slug.split("/");
  if (rest.length > 0) return null;
  if (!VIEWS.some((v) => v.id === view) || !ALL_FILTERS.some((f) => f.id === discipline) || !PERIODS.some((p) => p.id === period)) return null;
  return { view: view as RadarView, discipline, period: period as RadarPeriod };
}

/** getStaticPaths entries for src/pages/pulse/[...slug].astro: the two short defaults plus every full combination. */
export function staticSlugs(): (string | undefined)[] {
  return [undefined, "guidelines", ...allRequests().map((r) => `${r.view}/${r.discipline}/${r.period}`)];
}

export const periodLabel = (p: RadarPeriod): string => PERIODS.find((x) => x.id === p)!.label;
export const disciplineLabel = (id: string): string => ALL_FILTERS.find((f) => f.id === id)?.label ?? "All";
