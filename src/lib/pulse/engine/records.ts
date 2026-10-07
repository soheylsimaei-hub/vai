// GENERATED COPY - DO NOT EDIT. Source of truth: vai-app/src/lib/scientific-radar/records.ts
// Re-sync with: node scripts/sync-pulse-engine.mjs <path to this directory>   (see ENGINE_MANIFEST.json)
// Scientific Radar — ESummary JSON -> a display record. Bibliographic metadata only: no abstract, no full text, no interpretation.

import { displayPubTypes, evidenceKind, isRetracted, specialtyTags, type EvidenceKind } from "./classify";

export interface RadarRecord {
  pmid: string;
  title: string;
  journal: string;
  journalAbbrev: string;
  /** Display date exactly as PubMed reports it ("2026 Sep", "2026 Sep 28"). */
  pubDate: string;
  authors: string;
  pubTypes: string[];
  evidenceKind: EvidenceKind | null;
  specialties: { id: string; label: string }[];
  doi: string | null;
  pmcid: string | null;
  pubmedUrl: string;
  doiUrl: string | null;
  /** Present only when PubMed lists a PMC copy. Absence means "not indicated", never "not open access". */
  freeFullTextUrl: string | null;
  retracted: boolean;
}

const ENTITIES: Record<string, string> = { "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&#39;": "'", "&apos;": "'", "&nbsp;": " " };
/** PubMed titles may carry inline markup (<i>, <sup>) and entities. We render text only, never HTML. */
export function cleanTitle(raw: string): string {
  let t = raw.replace(/<[^>]*>/g, "").replace(/&(?:amp|lt|gt|quot|#39|apos|nbsp);/g, (m) => ENTITIES[m]).replace(/\s+/g, " ").trim();
  if (/^\[.*\]\.?$/.test(t)) t = t.replace(/^\[/, "").replace(/\]\.?$/, ""); // "[translated title]." convention
  return t.replace(/\.$/, "");
}

export function compactAuthors(authors: readonly { name?: string; authtype?: string }[] | undefined, max = 3): string {
  const names = (authors ?? []).filter((a) => a.name && (!a.authtype || a.authtype === "Author" || a.authtype === "CollectiveName")).map((a) => a.name!.trim());
  if (names.length === 0) return "";
  return names.length <= max ? names.join(", ") : `${names.slice(0, max).join(", ")}, et al.`;
}

/** NLM journal names carry a place-and-year suffix such as "(London, England : 1997)"; it is catalogue noise for a reader. */
export const cleanJournal = (raw: string): string => raw.replace(/\s*\([^)]*:\s*\d{4}\)\s*$/, "").replace(/\.$/, "").trim();

const DOI_RE = /^10\.\d{4,9}\/\S+$/;
const PMCID_RE = /PMC\d+/;
interface ESummaryItem {
  uid?: string; title?: string; source?: string; fulljournalname?: string; pubdate?: string; epubdate?: string; elocationid?: string;
  authors?: { name?: string; authtype?: string }[]; pubtype?: string[]; articleids?: { idtype?: string; value?: string }[];
}

export function toRecord(uid: string, item: ESummaryItem | undefined): RadarRecord | null {
  if (!item || !item.title || !/^\d+$/.test(uid)) return null;
  const ids = item.articleids ?? [];
  const doiRaw = ids.find((i) => i.idtype === "doi")?.value ?? /^doi:\s*(\S+)/i.exec(item.elocationid ?? "")?.[1] ?? null;
  const doi = doiRaw && DOI_RE.test(doiRaw.trim()) ? doiRaw.trim() : null;
  const pmcid = ids.map((i) => (i.idtype === "pmc" || i.idtype === "pmcid" ? PMCID_RE.exec(i.value ?? "")?.[0] : undefined)).find(Boolean) ?? null;
  const pubTypes = item.pubtype ?? [];
  const title = cleanTitle(item.title);
  const journalAbbrev = item.source ?? "";
  return {
    pmid: uid, title, journalAbbrev, journal: cleanJournal(item.fulljournalname ?? journalAbbrev),
    pubDate: item.pubdate ?? item.epubdate ?? "", authors: compactAuthors(item.authors),
    pubTypes: displayPubTypes(pubTypes), evidenceKind: evidenceKind(pubTypes, title), specialties: specialtyTags(title, journalAbbrev),
    doi, pmcid, pubmedUrl: `https://pubmed.ncbi.nlm.nih.gov/${uid}/`, doiUrl: doi ? `https://doi.org/${doi}` : null,
    freeFullTextUrl: pmcid ? `https://pmc.ncbi.nlm.nih.gov/articles/${pmcid}/` : null, retracted: isRetracted(pubTypes),
  };
}

/** Preserves the ESearch order (the caller's sort), drops uids ESummary could not describe. */
export function toRecords(ids: readonly string[], result: Record<string, unknown> | undefined): RadarRecord[] {
  return ids.map((id) => toRecord(id, (result as Record<string, ESummaryItem> | undefined)?.[id])).filter((r): r is RadarRecord => r !== null);
}
