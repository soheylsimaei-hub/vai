// GENERATED COPY - DO NOT EDIT. Source of truth: vai-app/src/lib/scientific-radar/disciplines.ts
// Re-sync with: node scripts/sync-pulse-engine.mjs <path to this directory>   (see ENGINE_MANIFEST.json)
// Scientific Radar — discipline registry. Each discipline (a clinical specialty OR a species group) is data, not code: adding "Parasitology",
// "Aquatic animals" or "Public health" later is one new entry here, with no change to the query builder, the UI filter bar or the tests'
// structural checks. Species groups and specialties share one shape on purpose so the product is never architected around companion animals.
//
// A record matches a discipline when it is in the veterinary base AND (it appears in one of the discipline's own journals OR its title
// contains one of the terms OR it is indexed under one of the MeSH headings). MeSH is a supplement, never the only criterion, because MeSH
// indexing trails publication and the radar is about recent papers.
//
// Term rules (enforced by tests): a single word may end in "*" (PubMed truncation, at least 4 letters before it); a phrase (contains a space)
// must not contain "*" because PubMed disables truncation inside quoted phrases.

export type DisciplineKind = "specialty" | "species";

export interface Discipline {
  id: string;
  label: string;
  kind: DisciplineKind;
  /** NLM title abbreviations; every article in these journals matches the discipline. */
  journals: readonly string[];
  /** Title terms (searched in the [ti] field). */
  terms: readonly string[];
  /** MeSH headings (exploded), searched with [MeSH Terms]. */
  mesh: readonly string[];
  /** Journals searched only inside this discipline (outside the core "All" base). */
  extraJournals?: readonly string[];
}

export const DISCIPLINES: readonly Discipline[] = [
  {
    id: "internal-medicine", label: "Internal Medicine", kind: "specialty",
    journals: ["J Vet Intern Med"],
    terms: ["internal medicine", "gastroenter*", "hepat*", "pancrea*", "nephro*", "renal", "kidney", "urinary", "endocrin*", "diabet*", "hypothyroid*", "hyperthyroid*", "hyperadrenocortic*", "Cushing", "Addison", "hematolog*", "haematolog*", "anemia", "anaemia", "enteropathy", "immune-mediated", "thrombocytopen*", "pancreatitis", "cholangitis", "colitis"],
    mesh: ["Kidney Diseases", "Gastrointestinal Diseases", "Endocrine System Diseases", "Hematologic Diseases", "Liver Diseases"],
  },
  {
    id: "dermatology", label: "Dermatology", kind: "specialty",
    journals: ["Vet Dermatol"],
    terms: ["dermat*", "skin", "cutaneous", "pruritus", "pruritic", "pyoderma", "otitis", "alopecia", "atopic", "allergic", "flea", "ear disease"],
    mesh: ["Skin Diseases", "Ear Diseases"],
  },
  {
    id: "cardiology", label: "Cardiology", kind: "specialty",
    journals: ["J Vet Cardiol"],
    terms: ["cardiac", "cardio*", "heart", "mitral", "valvular", "arrhythmia*", "echocardiograph*", "murmur", "pulmonary hypertension", "systemic hypertension", "cardiomyopathy", "pericardial"],
    mesh: ["Heart Diseases", "Cardiovascular Diseases"],
  },
  {
    id: "oncology", label: "Oncology", kind: "specialty",
    journals: ["Vet Comp Oncol"],
    terms: ["cancer", "tumor", "tumors", "tumour", "tumours", "neoplas*", "carcinoma", "sarcoma", "lymphoma", "mast cell", "chemotherap*", "oncolog*", "metasta*", "radiotherapy", "melanoma", "leukemia", "leukaemia"],
    mesh: ["Neoplasms"],
  },
  {
    id: "neurology", label: "Neurology", kind: "specialty",
    journals: [],
    terms: ["neurolog*", "seizure*", "epilep*", "intervertebral disc", "myelopath*", "encephal*", "spinal cord", "cognitive dysfunction", "neuropath*", "vestibular", "meningo*", "paralysis", "ataxia"],
    mesh: ["Nervous System Diseases"],
  },
  {
    id: "emergency-critical-care", label: "Emergency & Critical Care", kind: "specialty",
    journals: ["J Vet Emerg Crit Care (San Antonio)"],
    terms: ["emergency", "critical care", "critically ill", "resuscitation", "cardiopulmonary arrest", "sepsis", "septic", "shock", "transfusion", "trauma", "intensive care", "fluid therapy", "toxicosis", "poisoning"],
    mesh: ["Critical Care", "Emergency Treatment", "Shock"],
  },
  {
    id: "surgery", label: "Surgery", kind: "specialty",
    journals: ["Vet Surg", "Vet Comp Orthop Traumatol"],
    terms: ["surgery", "surgical", "postoperative", "orthop*", "fracture*", "cruciate", "osteotomy", "arthroscop*", "laparoscop*", "hip dysplasia", "wound", "arthroplasty", "castration", "ovariohysterectomy"],
    mesh: ["Surgical Procedures, Operative", "Orthopedic Procedures"],
  },
  {
    id: "diagnostic-imaging", label: "Diagnostic Imaging", kind: "specialty",
    journals: ["Vet Radiol Ultrasound"],
    terms: ["radiograph*", "radiolog*", "ultrasound", "ultrasonograph*", "computed tomography", "computed tomographic", "magnetic resonance", "MRI", "imaging", "scintigraphy", "fluoroscop*", "sonograph*"],
    mesh: ["Diagnostic Imaging"],
  },
  {
    id: "anesthesia", label: "Anesthesia", kind: "specialty",
    journals: ["Vet Anaesth Analg"],
    terms: ["anesthe*", "anaesthe*", "analges*", "sedation", "sedative", "nerve block", "opioid*", "local anesthetic", "local anaesthetic", "pain management", "ketamine", "propofol", "dexmedetomidine"],
    mesh: ["Anesthesia", "Analgesia"],
  },
  {
    id: "ophthalmology", label: "Ophthalmology", kind: "specialty",
    journals: ["Vet Ophthalmol"],
    terms: ["ophthalm*", "ocular", "cornea*", "uveitis", "glaucoma", "cataract*", "retina*", "conjunctiv*", "keratitis", "intraocular", "keratoconjunctivitis"],
    mesh: ["Eye Diseases"],
  },
  {
    id: "dentistry", label: "Dentistry", kind: "specialty",
    journals: ["J Vet Dent"],
    terms: ["dental", "dentistry", "tooth", "teeth", "periodont*", "oral disease", "stomatitis", "gingiv*", "tooth resorption", "oral health"],
    mesh: ["Tooth Diseases", "Periodontal Diseases", "Mouth Diseases"],
  },
  // ---- species groups -------------------------------------------------------------------------------------------------------
  {
    id: "equine", label: "Equine", kind: "species",
    journals: ["Equine Vet J", "J Equine Vet Sci", "Vet Clin North Am Equine Pract"],
    terms: ["horse", "horses", "equine", "foal", "foals", "mare", "mares", "stallion*", "gelding*", "laminitis", "donkey*"],
    mesh: ["Horses", "Horse Diseases"],
  },
  {
    id: "farm-animal", label: "Farm Animal", kind: "species",
    journals: ["Vet Clin North Am Food Anim Pract", "Tierarztl Prax Ausg G Grosstiere Nutztiere", "Avian Dis", "Avian Pathol", "J Dairy Sci", "Poult Sci"],
    terms: ["cattle", "cow", "cows", "calf", "calves", "bovine", "dairy", "swine", "pigs", "piglet*", "porcine", "sheep", "ovine", "lamb", "lambs", "goat", "goats", "caprine", "poultry", "chicken*", "livestock", "farm animal", "farm animals", "ruminant*", "broiler*", "turkey", "turkeys"],
    mesh: ["Cattle", "Cattle Diseases", "Swine", "Swine Diseases", "Sheep", "Goats", "Poultry", "Livestock", "Ruminants"],
    extraJournals: ["J Dairy Sci", "J Anim Sci", "Poult Sci"],
  },
  {
    id: "exotics", label: "Exotics", kind: "species",
    journals: ["Vet Clin North Am Exot Anim Pract", "J Avian Med Surg", "J Zoo Wildl Med"],
    terms: ["exotic animal", "exotic animals", "exotic pet", "exotic pets", "reptile*", "tortoise*", "turtle*", "snake*", "lizard*", "guinea pig", "guinea pigs", "ferret*", "rabbits", "rabbit", "pet bird", "pet birds", "psittacine*", "parrot*", "small mammal", "small mammals", "amphibian*", "chinchilla*", "hedgehog*", "zoo animal", "zoo animals", "avian medicine"],
    mesh: ["Reptiles", "Lagomorpha", "Ferrets", "Guinea Pigs", "Amphibians"],
  },
];

export const DISCIPLINE_IDS: readonly string[] = DISCIPLINES.map((d) => d.id);
export const getDiscipline = (id: string): Discipline | undefined => DISCIPLINES.find((d) => d.id === id);
