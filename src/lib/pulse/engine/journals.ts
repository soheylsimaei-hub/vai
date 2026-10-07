// GENERATED COPY - DO NOT EDIT. Source of truth: vai-app/src/lib/scientific-radar/journals.ts
// Re-sync with: node scripts/sync-pulse-engine.mjs <path to this directory>   (see ENGINE_MANIFEST.json)
// Scientific Radar — the veterinary journal base set, as NLM/PubMed title abbreviations (searched with the [ta] field).
//
// Why an explicit, reviewed list and not a PubMed "veterinary" filter: PubMed has no reliable veterinary subset field, MeSH indexing lags
// new records by weeks (so a MeSH-only definition would miss exactly the "latest" papers a radar exists for), and the NLM Catalog's
// "Veterinary Medicine" subject returns laboratory-science journals while omitting large veterinary titles (e.g. Front Vet Sci). The list
// is versioned so a change is a reviewed code change, and every entry was checked against live PubMed volume (a typo returns 0 records).
//
// Species-agnostic by design: companion, equine, production-animal, exotic/zoo and regional journals all live in the same base.

export const JOURNAL_LIST_VERSION = "2026-10-07.1";

/** Core veterinary journals: the "All" view and the base every discipline filter is intersected with. */
export const CORE_VET_JOURNALS: readonly string[] = [
  // general clinical
  "J Vet Intern Med", "J Small Anim Pract", "J Feline Med Surg", "J Am Vet Med Assoc", "Am J Vet Res", "Vet Rec", "Vet J",
  "J Am Anim Hosp Assoc", "Top Companion Anim Med", "Vet Clin North Am Small Anim Pract", "J Vet Pharmacol Ther", "Res Vet Sci", "Vet Q",
  // disciplines
  "Vet Dermatol", "J Vet Cardiol", "J Vet Emerg Crit Care (San Antonio)", "Vet Surg", "Vet Comp Orthop Traumatol", "Vet Radiol Ultrasound",
  "Vet Anaesth Analg", "Vet Ophthalmol", "J Vet Dent", "Vet Comp Oncol", "Vet Clin Pathol", "Vet Pathol", "J Comp Pathol", "J Vet Diagn Invest",
  // equine, production, exotic, zoo and wildlife
  "Equine Vet J", "J Equine Vet Sci", "Vet Clin North Am Equine Pract", "Vet Clin North Am Food Anim Pract", "Vet Clin North Am Exot Anim Pract",
  "J Avian Med Surg", "J Zoo Wildl Med", "J Wildl Dis", "Avian Dis", "Avian Pathol", "Theriogenology", "Reprod Domest Anim", "Anim Reprod Sci",
  // epidemiology, infectious disease, public health
  "Prev Vet Med", "Transbound Emerg Dis", "Vet Microbiol", "Vet Parasitol", "Vet Immunol Immunopathol", "Vet Res", "Vet Res Commun",
  "Zoonoses Public Health", "Trop Anim Health Prod",
  // regional and open-access veterinary titles
  "Can Vet J", "Can J Vet Res", "Aust Vet J", "N Z Vet J", "J S Afr Vet Assoc", "Onderstepoort J Vet Res", "Acta Vet Scand", "Acta Vet Hung",
  "Vet Ital", "Schweiz Arch Tierheilkd", "Tierarztl Prax Ausg K Kleintiere Heimtiere", "Tierarztl Prax Ausg G Grosstiere Nutztiere",
  "BMC Vet Res", "Vet Med Sci", "Open Vet J", "J Vet Sci", "J Vet Med Sci", "Pol J Vet Sci", "Front Vet Sci", "Vet Sci", "Vet Rec Open",
  "J Vet Med Educ",
];

/** Animal-science journals added ONLY inside the Farm Animal filter. They are high-volume production-science titles that would otherwise
 * dominate the general "All" view, but are exactly what a production-animal reader wants. */
export const FARM_SCIENCE_JOURNALS: readonly string[] = ["J Dairy Sci", "J Anim Sci", "Poult Sci"];
