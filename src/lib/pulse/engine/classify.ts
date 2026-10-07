// GENERATED COPY - DO NOT EDIT. Source of truth: vai-app/src/lib/scientific-radar/classify.ts
// Re-sync with: node scripts/sync-pulse-engine.mjs <path to this directory>   (see ENGINE_MANIFEST.json)
// Scientific Radar — labelling from PubMed metadata. Nothing here interprets science. Every label is either a PubMed publication type
// shown as-is, or a deterministic match against the record's title/journal using the same registry the query used.
//
// Guideline honesty: a record is labelled "Guideline" or "Consensus statement" ONLY when PubMed itself typed it that way. A title that
// merely mentions guidelines is shown with a neutral "Title mentions guidelines or consensus" note and is never called a guideline.

import { DISCIPLINES, type Discipline } from "./disciplines";
import { TITLE_MENTION_PHRASES } from "./query";

export type EvidenceKind = "guideline" | "consensus" | "systematic-review" | "meta-analysis" | "title-mention";

export const EVIDENCE_KIND_LABEL: Record<EvidenceKind, string> = {
  guideline: "Guideline",
  consensus: "Consensus statement",
  "systematic-review": "Systematic review",
  "meta-analysis": "Meta-analysis",
  "title-mention": "Title mentions guidelines or consensus",
};

const has = (types: readonly string[], ...names: string[]) => names.some((n) => types.some((t) => t.toLowerCase() === n.toLowerCase()));
const norm = (s: string) => s.toLowerCase().replace(/[‐‑–—-]/g, " ").replace(/\s+/g, " ");

/** Most specific first: a typed guideline outranks a typed consensus statement, which outranks a typed review. */
export function evidenceKind(pubTypes: readonly string[], title: string): EvidenceKind | null {
  if (has(pubTypes, "Practice Guideline", "Guideline")) return "guideline";
  if (has(pubTypes, "Consensus Statement", "Consensus Development Conference")) return "consensus";
  if (has(pubTypes, "Systematic Review")) return "systematic-review";
  if (has(pubTypes, "Meta-Analysis")) return "meta-analysis";
  const t = norm(title);
  if (TITLE_MENTION_PHRASES.some((p) => t.includes(norm(p)))) return "title-mention";
  return null;
}

// ---- publication-type display ----------------------------------------------------------------------------------------------------
const TYPE_DISPLAY: [string, string][] = [
  ["Practice Guideline", "Practice guideline"], ["Guideline", "Guideline"], ["Consensus Statement", "Consensus statement"],
  ["Systematic Review", "Systematic review"], ["Meta-Analysis", "Meta-analysis"], ["Randomized Controlled Trial, Veterinary", "Randomized controlled trial"],
  ["Randomized Controlled Trial", "Randomized controlled trial"], ["Clinical Trial, Veterinary", "Clinical trial"], ["Clinical Trial", "Clinical trial"],
  ["Scoping Review", "Scoping review"], ["Review", "Review"], ["Case Reports", "Case report"], ["Comparative Study", "Comparative study"],
  ["Validation Study", "Validation study"], ["Observational Study, Veterinary", "Observational study"], ["Observational Study", "Observational study"],
  ["Editorial", "Editorial"], ["Comment", "Comment"], ["Letter", "Letter"], ["News", "News"], ["Retraction of Publication", "Retraction notice"],
];
/** Up to two informative PubMed publication types; the generic "Journal Article" is shown only when nothing more specific exists. */
export function displayPubTypes(pubTypes: readonly string[], max = 2): string[] {
  const out: string[] = [];
  for (const [raw, label] of TYPE_DISPLAY) if (has(pubTypes, raw) && !out.includes(label)) out.push(label);
  const shown = out.slice(0, max);
  return shown.length > 0 ? shown : has(pubTypes, "Journal Article") ? ["Journal article"] : [];
}
/** Display labels (from PubMed's own types) that earn the emphasised badge. A title-only match is never in this set. */
export const EMPHASIZED_TYPE_LABELS: ReadonlySet<string> = new Set(["Practice guideline", "Guideline", "Consensus statement", "Systematic review", "Meta-analysis"]);
export const isRetracted = (pubTypes: readonly string[]): boolean => has(pubTypes, "Retracted Publication");

// ---- specialty / topic tags ---------------------------------------------------------------------------------------------------------
/** Registry term -> title regex (single words may end in "*"; spaces and hyphens in phrases match either). */
export function termRegex(term: string): RegExp {
  const escaped = term.toLowerCase().replace(/[.+?^${}()|[\]\\]/g, "\\$&");
  const body = escaped.replace(/[\s-]+/g, "[\\s-]+").replace(/\*/g, "\\w*");
  return new RegExp(`(?<![a-z0-9])${body}${term.endsWith("*") ? "" : "(?![a-z0-9])"}`, "i");
}
const COMPILED = new Map<string, RegExp[]>(DISCIPLINES.map((d) => [d.id, d.terms.map(termRegex)]));

/** Disciplines whose journal list or title terms match. Matches what the PubMed query matched, minus MeSH (not in ESummary). */
export function specialtyTags(title: string, journalAbbrev: string): { id: string; label: string }[] {
  return DISCIPLINES.filter((d: Discipline) => d.journals.includes(journalAbbrev) || COMPILED.get(d.id)!.some((re) => re.test(title))).map((d) => ({ id: d.id, label: d.label }));
}
