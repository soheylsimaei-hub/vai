// Test fixtures shared by the Pulse unit tests (not imported by the site).
import type { PubMedClient } from "./engine/pubmed";

export const item = (uid: string, over: Record<string, unknown> = {}) => ({
  uid, title: `Paper ${uid}.`, source: "J Vet Intern Med", fulljournalname: "Journal of veterinary internal medicine", pubdate: "2026 Oct 1",
  authors: [{ name: "Smith A", authtype: "Author" }], pubtype: ["Journal Article"], articleids: [{ idtype: "doi", value: `10.1000/${uid}` }], ...over,
});

/** A fake PubMed: every combination returns `perCombo` ids; ids overlap heavily across combinations (as real data does). */
export function fakePubMed(opts: { perCombo?: number; failEsearchWhen?: (n: number) => boolean; failEsummary?: boolean; itemFor?: (id: string) => Record<string, unknown> } = {}) {
  const log = { esearch: 0, esummary: 0, summaryBatches: [] as string[][] };
  const client: PubMedClient = {
    async esearch() {
      const n = ++log.esearch;
      if (opts.failEsearchWhen?.(n)) throw new Error("simulated NCBI failure");
      const k = opts.perCombo ?? 3;
      return { count: 100 + n, ids: Array.from({ length: k }, (_, i) => String(42000000 + ((n + i) % 10))), warnings: [] };
    },
    async esummary(ids) {
      log.esummary++; log.summaryBatches.push([...ids]);
      if (opts.failEsummary) throw new Error("simulated esummary failure");
      return Object.fromEntries(ids.map((id) => [id, (opts.itemFor ?? ((x: string) => item(x)))(id)]));
    },
  };
  return { client, log };
}
