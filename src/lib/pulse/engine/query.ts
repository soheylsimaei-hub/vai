// GENERATED COPY - DO NOT EDIT. Source of truth: vai-app/src/lib/scientific-radar/query.ts
// Re-sync with: node scripts/sync-pulse-engine.mjs <path to this directory>   (see ENGINE_MANIFEST.json)
// Scientific Radar — PubMed query construction. Pure and deterministic: (discipline, view, period, page) -> an E-utilities ESearch request.
//
//   term = ( veterinary journal base [ta] )  AND  ( discipline: journals [ta] OR title terms [ti] OR MeSH )  AND  ( view )
//   date = datetype=edat (date the record entered PubMed) with reldate=N days, so "last 7 days" means "newly in PubMed", independent of the
//          month-granular publication dates many journals report. Results are sorted by that same Entrez date (sort=date, newest entry first):
//          sort=pub_date was rejected after live testing because it ranks future-dated journal issues ("2026 Dec") above everything else.
//
// Discipline terms are matched in the TITLE, not the abstract: live testing showed abstract matching surfaced unrelated papers under a
// discipline because a word appeared once in passing. Title matching favours precision, and it keeps the topic tags shown on each card
// (computed locally from the title, see classify.ts) consistent with what the query actually matched.
//
// The "guidelines" view is metadata-first. Tier 1 is PubMed's own publication types (Practice Guideline, Guideline, Consensus Statement,
// Systematic Review, Meta-Analysis). Tier 2 is a deliberately narrow set of title phrases, kept because
// real veterinary guidelines are sometimes typed only as "Review" in PubMed; a Tier 2 record is never labelled a guideline (see classify.ts).

import { CORE_VET_JOURNALS } from "./journals";
import { DISCIPLINES, getDiscipline, type Discipline } from "./disciplines";

export const PERIODS = [
  { id: "7d", days: 7, label: "7 days" },
  { id: "30d", days: 30, label: "30 days" },
  { id: "90d", days: 90, label: "3 months" },
  { id: "365d", days: 365, label: "12 months" },
] as const;
export type RadarPeriod = (typeof PERIODS)[number]["id"];
export const periodDays = (p: RadarPeriod): number => PERIODS.find((x) => x.id === p)!.days;

export const VIEWS = [
  { id: "latest", label: "Latest" },
  { id: "guidelines", label: "Guidelines & Consensus" },
] as const;
export type RadarView = (typeof VIEWS)[number]["id"];

export const PAGE_SIZE = 20;
/** PubMed's own publication types used for the Guidelines & Consensus view (Tier 1, metadata). */
export const GUIDELINE_PUBLICATION_TYPES: readonly string[] = ["Practice Guideline", "Guideline", "Consensus Statement"];
/** Added only when the reader opts in: systematic reviews are ~5x as numerous as guidelines and would otherwise crowd them out. */
export const REVIEW_PUBLICATION_TYPES: readonly string[] = ["Systematic Review", "Meta-Analysis"];
/** Narrow title phrases (Tier 2). A title match only widens what is SHOWN in the view; it never earns a guideline label. */
export const TITLE_MENTION_PHRASES: readonly string[] = [
  "consensus statement", "consensus guidelines", "consensus report", "consensus definition", "consensus definitions",
  "practice guideline", "practice guidelines", "clinical guidelines", "best practice guidelines", "updated guidelines",
  "guidelines for", "guidelines on", "guidelines from", "guideline for",
];

/** `reviews` only has meaning in the guidelines view: include PubMed-typed systematic reviews and meta-analyses. */
export interface RadarRequest { discipline: string; view: RadarView; period: RadarPeriod; page: number; reviews: boolean }
export const DEFAULT_REQUEST: RadarRequest = { discipline: "all", view: "latest", period: "30d", page: 1, reviews: false };
/** Guidelines are sparse (live data: ~10 PubMed-typed guidelines/consensus statements a year across ALL veterinary journals) and stay relevant
 * far longer than ordinary papers, so that view opens on 12 months; per-specialty views over 3 months were mostly empty. */
export const defaultPeriodFor = (view: RadarView): RadarPeriod => (view === "guidelines" ? "365d" : "30d");

// ---- term formatting ---------------------------------------------------------------------------------------------------------
const q = (s: string) => `"${s.replace(/"/g, "")}"`;
const journalClause = (j: string) => `${q(j)}[ta]`;
const meshClause = (m: string) => `${q(m)}[MeSH Terms]`;
/** A single plain word stays bare (so a trailing "*" truncation works); anything with a space or hyphen is a quoted phrase. */
export function termClause(t: string, field: "tiab" | "ti" = "ti"): string {
  return /[\s-]/.test(t) ? `${q(t)}[${field}]` : `${t}[${field}]`;
}
const or = (parts: readonly string[]) => parts.join(" OR ");

export function baseJournalTerm(extra: readonly string[] = []): string {
  const all = [...new Set([...CORE_VET_JOURNALS, ...extra])];
  return or(all.map(journalClause));
}

export function disciplineTerm(d: Discipline): string {
  return or([...d.journals.map(journalClause), ...d.terms.map((t) => termClause(t)), ...d.mesh.map(meshClause)]);
}

export function viewTerm(view: RadarView, reviews = false): string {
  if (view === "latest") return "";
  const types = reviews ? [...GUIDELINE_PUBLICATION_TYPES, ...REVIEW_PUBLICATION_TYPES] : GUIDELINE_PUBLICATION_TYPES;
  return or([...types.map((t) => `${q(t)}[pt]`), ...TITLE_MENTION_PHRASES.map((t) => termClause(t, "ti"))]);
}

export function buildTerm(req: Pick<RadarRequest, "discipline" | "view"> & { reviews?: boolean }, registry: readonly Discipline[] = DISCIPLINES): string {
  const d = req.discipline === "all" ? undefined : registry.find((x) => x.id === req.discipline);
  if (req.discipline !== "all" && !d) throw new Error(`unknown discipline: ${req.discipline}`);
  const parts = [`(${baseJournalTerm(d?.extraJournals)})`];
  if (d) parts.push(`(${disciplineTerm(d)})`);
  const v = viewTerm(req.view, req.reviews);
  if (v) parts.push(`(${v})`);
  // Published errata ("Correction to ...") are noise on a radar: the corrected paper itself is what a reader wants.
  return `${parts.join(" AND ")} NOT ${q("Published Erratum")}[pt]`;
}

export interface ESearchParams { db: "pubmed"; term: string; datetype: "edat"; reldate: number; sort: "date"; retstart: number; retmax: number; retmode: "json" }
/** `pageSize` defaults to the in-app page size; the public vai.vet build asks for a longer single page instead of paginating. */
export function buildESearchParams(req: RadarRequest, pageSize: number = PAGE_SIZE): ESearchParams {
  const page = Math.max(1, Math.floor(req.page));
  return { db: "pubmed", term: buildTerm(req), datetype: "edat", reldate: periodDays(req.period), sort: "date", retstart: (page - 1) * pageSize, retmax: pageSize, retmode: "json" };
}

// ---- request parsing (URL -> a validated request; unknown values fall back to defaults, never throw) -------------------------------
const first = (v: string | string[] | undefined): string | undefined => (Array.isArray(v) ? v[0] : v);
export function parseRadarParams(sp: Record<string, string | string[] | undefined>): RadarRequest {
  const viewRaw = first(sp.v);
  const view: RadarView = viewRaw === "guidelines" ? "guidelines" : "latest";
  const dRaw = first(sp.s);
  const discipline = dRaw && getDiscipline(dRaw) ? dRaw : "all";
  const pRaw = first(sp.p);
  const period: RadarPeriod = PERIODS.some((x) => x.id === pRaw) ? (pRaw as RadarPeriod) : defaultPeriodFor(view);
  const pageN = Number.parseInt(first(sp.page) ?? "1", 10);
  const page = Number.isFinite(pageN) && pageN >= 1 && pageN <= 50 ? pageN : 1;
  const reviews = view === "guidelines" && first(sp.sr) === "1";
  return { discipline, view, period, page, reviews };
}

/** Canonical URL for a request, omitting values equal to their defaults so links stay short and cache keys stay few. */
export function radarHref(req: RadarRequest): string {
  const p = new URLSearchParams();
  if (req.view !== "latest") p.set("v", req.view);
  if (req.discipline !== "all") p.set("s", req.discipline);
  if (req.period !== defaultPeriodFor(req.view)) p.set("p", req.period);
  if (req.view === "guidelines" && req.reviews) p.set("sr", "1");
  if (req.page > 1) p.set("page", String(req.page));
  const s = p.toString();
  return s ? `/scientific-radar?${s}` : "/scientific-radar";
}

export const ALL_FILTERS: readonly { id: string; label: string }[] = [{ id: "all", label: "All" }, ...DISCIPLINES.map((d) => ({ id: d.id, label: d.label }))];
