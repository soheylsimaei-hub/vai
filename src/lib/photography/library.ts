// VAI PHOTOGRAPHY LIBRARY — manifest.
//
// A curated set of 33 illustrative images of the veterinary profession (educators, clinicians, teaching rooms, diagnostic and clinical settings).
// They are GENERATED imagery, supplied by the founder. They must never be presented as, or captioned as, VAI faculty, experts, team, community
// or members, and must not imply affiliation or endorsement. That is achieved editorially (no copy, caption or alt text assigns the people an identity or
// role), not with a disclaimer under each image.
//
// Files live in /public/photography/library/{id}-{480|800|1024}.webp and are produced by scripts/photo-library/build-library.py from the original
// 1024px square sources. Files are uncropped squares: placements crop in CSS (aspect-ratio + object-position), using the per-image focal points here.
//
// `use` is the image's strongest role; `ready` says whether web files exist (false = reserve, run the build script with --all or --ids to add).
// `note` records why an image was held back, so the next person does not re-litigate it.

export type PhotoUse =
  | 'institutional'   // academic / institutional presence (libraries, professors)
  | 'education'       // teaching, seminars, lecture settings -> Academy
  | 'diagnostic'      // imaging, anatomy, clinical reasoning
  | 'communication'   // consultation / conversation
  | 'profession'      // the people of the profession
  | 'animal'          // animal + veterinarian
  | 'enterprise'      // clinic / organisation / team scale -> VAI for Teams
  | 'authentic'       // real photographs of VAI's own educational work (the only images that may be described as such)
  | 'editorial'       // research / literature -> Pulse
  | 'supporting'      // background / texture, not a lead image
  | 'unsuitable';     // do not use (see note)

export interface PhotoEntry {
  id: string;
  use: PhotoUse;
  ready: boolean;
  /** Describes the scene, never a person's identity or role at VAI. Used wherever the image carries meaning (alt); decorative placements pass alt="". */
  alt: string;
  /** CSS object-position per crop family. portrait = 4:5, landscape = 3:2 / 2:1 / 16:9, square = 1:1. */
  focus: { portrait: string; landscape: string; square?: string };
  note?: string;
  /** Native pixel size and available widths when the file is not one of the standard square 1024px library images (authentic photographs are 16:9). */
  w?: number; h?: number; widths?: readonly number[];
}

export const PHOTO_WIDTHS = [480, 800, 1024] as const;
export const PHOTO_BASE = '/photography/library';
/** Bump when library files are replaced in place: it is appended to every image URL (?v=) so browsers and the CDN fetch the new files instead of serving a cached copy for hours. Last bump: 2026-10-10 (c), surgeon-theatre was replaced with the founder's corrected picture (no horse, canine thorax radiograph). */
export const PHOTO_VERSION = '20261010d';



export const PHOTOS: readonly PhotoEntry[] = [
  // ---- authentic VAI photography (real, from the production of the Trusted Vet Method) ---------------------------------------------
  // Different role from everything below: these document real VAI educational work. They are not founder portraits and are never captioned,
  // named or framed that way. Do not repeat the same one across nearby pages.
  { id: 'trusted-vet-method-teaching-r2', use: 'authentic', ready: true, w: 1672, h: 941, widths: [800, 1280, 1672], alt: 'An educator explaining a point to camera in front of shelves of veterinary textbooks and a microscope', focus: { portrait: '52% 50%', landscape: '50% 38%' }, note: 'Primary authentic image (Academy, educational philosophy). Colour-corrected master supplied 2026-10-08 (design-assets/photography-masters/); small EU / Portuguese desk flags sit at left of frame.' },
  { id: 'trusted-vet-method-desk-r2', use: 'authentic', ready: true, w: 1672, h: 941, widths: [800, 1280, 1672], alt: 'A veterinary educator seated at a desk with a laptop and a veterinary surgery textbook, in a study lined with books', focus: { portrait: '54% 50%', landscape: '50% 42%' }, note: 'Formal / institutional frame. Secondary use only (Academy programme row). Colour-corrected master supplied 2026-10-08; small EU / Portuguese desk flags on the upper-left shelf.' },
  { id: 'trusted-vet-method-flags', use: 'authentic', ready: false, w: 1672, h: 941, widths: [800, 1280, 1672], alt: 'An educator standing in front of a European Union flag and a Portuguese flag', focus: { portrait: '55% 50%', landscape: '50% 30%' }, note: 'RESERVED, deliberately unused: large EU and Portuguese flags could imply governmental or EU affiliation. A colour-corrected master is stored in design-assets/photography-masters/ (not shipped to public/).' },

  // ---- placements (decided 2026-10-07; the library is a SITE-WIDE asset, not an About gallery) ---------------------------------------
  //   /about/            first editorial composition: woman-scrubs-classroom (was imaging-teaching-scrubs), vet-with-dog-classroom, man-library-suit
  //                      breadth: surgeon-theatre (alone; senior-vet-radiograph removed as a near-duplicate subject)      academy: seminar-discussion (placeholder for a real course photo)
  //   homepage Teams     enterprise-clinic-team-r2
  //   /academy/          trusted-vet-method-teaching-r2, trusted-vet-method-desk-r2 (authentic; the -r2 suffix busts the 4-hour CDN/browser cache of the earlier same-named files); academy-expert-led, educator-imaging-screen
//                      (the learning-experience section is deliberately image-free until a suitable professional-education photograph exists)
//   everything else below is processed and RESERVED for future pages. Do not repeat the same person across nearby pages.
  { id: 'enterprise-clinic-team-r2', use: 'enterprise', ready: true, alt: 'A veterinary clinic team of around twenty people in dark scrubs, with two dogs, gathered outside a white-columned building', focus: { portrait: '50% 50%', landscape: '50% 52%', square: '50% 50%' }, note: 'Enterprise / clinic-team asset only. Never on About; never implies the people shown are VAI customers or staff. Supplied by the founder 2026-10-10 as the group picture (replaces the earlier clinic-team image); the -r2 suffix busts the 4-hour CDN/browser cache of the earlier same-named files.' },
  { id: 'scholar-whiteboard', use: 'profession', ready: true, alt: 'A veterinary educator in a white coat standing in front of a teaching board', focus: { portrait: '46% 50%', landscape: '50% 30%' } },
  { id: 'imaging-teaching-scrubs', use: 'diagnostic', ready: true, alt: 'A veterinary clinician in scrubs teaching a group in front of a radiograph', focus: { portrait: '40% 50%', landscape: '50% 24%' } },
  { id: 'woman-scrubs-classroom', use: 'profession', ready: true, alt: 'A woman in navy scrubs smiling with her arms crossed in a lecture room, with students seated behind her', focus: { portrait: '50% 50%', landscape: '50% 9%' }, note: 'Supplied by the founder 2026-10-10 as the large lead image of the About cluster, replacing imaging-teaching-scrubs.' },
  { id: 'educator-heart-model', use: 'diagnostic', ready: true, note: 'Withdrawn from /academy/ (2026-10-08): a posed portrait beside a model does not communicate professional education in practice.', alt: 'An educator beside an anatomical model of a heart in a teaching laboratory', focus: { portrait: '100% 50%', landscape: '50% 45%' } },
  { id: 'lecturer-woman-screen', use: 'education', ready: true, alt: 'A veterinary lecturer addressing a seated class in front of a projected image', focus: { portrait: '64% 50%', landscape: '50% 32%' } },
  { id: 'surgeon-mentor-team', use: 'profession', ready: true, alt: 'An experienced veterinary surgeon in scrubs listening to colleagues in a clinical setting', focus: { portrait: '56% 50%', landscape: '50% 28%' } },
  { id: 'woman-library-black', use: 'institutional', ready: true, alt: 'A professional standing among the shelves of an academic library', focus: { portrait: '52% 50%', landscape: '50% 30%' } },
  { id: 'vet-with-dog-classroom', use: 'animal', ready: true, alt: 'A veterinarian gently holding a dog during a teaching session', focus: { portrait: '62% 50%', landscape: '50% 55%' } },
  { id: 'senior-vet-radiograph', use: 'diagnostic', ready: true, note: 'Withdrawn from /about/ (2026-10-08): reads as the same older man as surgeon-theatre in the adjacent breadth composition.', alt: 'A senior veterinarian in a white coat beside a diagnostic imaging monitor', focus: { portrait: '52% 50%', landscape: '50% 30%' } },
  { id: 'educator-imaging-screen', use: 'diagnostic', ready: true, alt: 'An educator beside a large screen showing diagnostic images', focus: { portrait: '62% 50%', landscape: '50% 38%' } },
  { id: 'educator-laughing-classroom', use: 'profession', ready: true, alt: 'A veterinarian in a white coat smiling in front of a seated class', focus: { portrait: '50% 50%', landscape: '50% 32%' } },
  { id: 'lecturer-lecture-hall', use: 'education', ready: true, alt: 'A veterinary lecturer speaking to a room of students in white coats', focus: { portrait: '36% 50%', landscape: '50% 32%' } },
  { id: 'educator-anatomy-monitor', use: 'diagnostic', ready: true, alt: 'An educator standing by a monitor displaying an anatomical illustration', focus: { portrait: '52% 50%', landscape: '50% 40%' } },
  { id: 'man-whiteboard-classroom', use: 'profession', ready: true, alt: 'A professional leaning against a whiteboard with a busy teaching room behind', focus: { portrait: '62% 50%', landscape: '50% 38%' } },
  { id: 'senior-man-screen', use: 'profession', ready: true, alt: 'A senior professional beside a wall screen showing an anatomical diagram', focus: { portrait: '58% 50%', landscape: '50% 30%' } },
  { id: 'surgeon-theatre', use: 'profession', ready: true, alt: 'A surgeon in scrubs standing with his arms crossed in an operating theatre, with a chest radiograph on a monitor behind him and a clinical team at work', focus: { portrait: '52% 50%', landscape: '50% 32%' }, note: 'Replaced 2026-10-10 with the founder-supplied corrected picture (the horse on the table removed; the monitor shows a canine thorax radiograph with all lettering and arrows removed at the founder request).' },
  { id: 'academy-expert-led', use: 'education', ready: true, alt: 'A veterinarian in a white coat and clinical staff in scrubs gathered around dogs on a clinic floor', focus: { portrait: '50% 30%', landscape: '50% 24%' }, note: 'Supplied by the founder 2026-10-08 as the large image of /academy/ Expert-led education. Same photograph as the library entry clinic-floor-dogs, delivered from the supplied file (design-assets/photography-masters/academy-expert-led-master.webp). No attribution required.' },
  { id: 'professor-seminar', use: 'education', ready: true, alt: 'A professor in a white coat discussing a case with seated students', focus: { portrait: '52% 50%', landscape: '50% 34%' } },
  { id: 'clinic-floor-dogs', use: 'animal', ready: true, alt: 'Veterinary staff and a vet examining dogs together on a clinic floor', focus: { portrait: '44% 50%', landscape: '50% 45%' } },
  { id: 'man-archive-papers', use: 'editorial', ready: true, alt: 'A professional holding papers among stacks of documents in an old library', focus: { portrait: '50% 50%', landscape: '50% 38%' } },
  { id: 'seminar-discussion', use: 'education', ready: true, alt: 'A veterinary educator in a white coat gesturing mid-discussion with students around a seminar table', focus: { portrait: '54% 50%', landscape: '50% 30%' }, note: 'The horse illustration on the screen is deliberately blurred (founder request, 2026-10-10); the title, the educator and the students are sharp.' },

  // ---- reserve: processed on demand (scripts/photo-library/build-library.py --ids ...) ---------------------------------------------
  { id: 'woman-dog-classroom', use: 'animal', ready: false, alt: 'A woman holding a small dog in a teaching room', focus: { portrait: '58% 50%', landscape: '50% 40%' }, note: 'Garbled "Veterinary Class" writing on the board behind her; crop cannot remove it cleanly.' },
  { id: 'woman-flipchart', use: 'unsuitable', ready: false, alt: 'A woman standing beside a flipchart', focus: { portrait: '40% 50%', landscape: '50% 35%' }, note: 'Large garbled text on the flipchart; near-duplicate of other arms-crossed portraits.' },
  { id: 'woman-blazer-classroom', use: 'supporting', ready: false, alt: 'A woman in a dark blazer in a classroom', focus: { portrait: '50% 50%', landscape: '50% 35%' }, note: 'Generic business-portrait feel; heavily blurred room.' },
  { id: 'educator-dog-whiteboard', use: 'animal', ready: false, alt: 'A woman holding a dog beside a whiteboard', focus: { portrait: '0% 50%', landscape: '50% 40%' }, note: 'Readable garbled "Veterinary Class" text on the board.' },
  { id: 'educator-lanyard-whiteboard', use: 'profession', ready: false, alt: 'An educator with a lanyard beside a whiteboard', focus: { portrait: '62% 50%', landscape: '50% 30%' }, note: 'Reserve; near-duplicate of the arms-crossed educator portraits already used.' },
  { id: 'woman-library-smile', use: 'institutional', ready: false, alt: 'A woman smiling in an academic library', focus: { portrait: '52% 50%', landscape: '50% 35%' }, note: 'Near-duplicate of woman-library-black.' },
  { id: 'lecturer-man-screen', use: 'education', ready: false, alt: 'A lecturer in a white coat addressing a class with a projected image behind', focus: { portrait: '30% 50%', landscape: '50% 25%' }, note: 'Near-duplicate of the other lecturer-in-front-of-class frames.' },
  { id: 'man-library-suit', use: 'institutional', ready: true, w: 560, h: 700, widths: [560], alt: 'A man in a dark suit and tie standing in a long academic library', focus: { portrait: '50% 30%', landscape: '50% 30%' }, note: 'Chosen by the founder (2026-10-08) for the right-hand image of the About cluster. Generated archive image, pre-cropped to a 4:5 head-and-shoulders frame (the full frame is a wide library scene). No attribution required.' },
  { id: 'man-suit-anatomy-screen', use: 'profession', ready: false, alt: 'A man in a suit beside a screen showing an anatomical image', focus: { portrait: '62% 50%', landscape: '50% 35%' }, note: 'Appears to be the same subject as man-whiteboard-classroom.' },
  { id: 'man-library-portrait', use: 'unsuitable', ready: false, alt: 'A man in a dark suit in a library', focus: { portrait: '50% 50%', landscape: '50% 35%' }, note: 'Corporate-headshot feel and a repeat of the same subject; not VAI-appropriate.' },
  { id: 'man-whiteboard-text', use: 'unsuitable', ready: false, alt: 'A man beside a whiteboard covered in writing', focus: { portrait: '62% 50%', landscape: '50% 35%' }, note: 'Large garbled "Veterinary CLASS" lettering dominates the frame.' },
  { id: 'woman-whiteboard-smile', use: 'profession', ready: false, alt: 'A smiling woman beside a whiteboard', focus: { portrait: '40% 50%', landscape: '50% 35%' }, note: 'Near-duplicate of the arms-crossed educator portraits.' },
  { id: 'educator-anatomy-sketches', use: 'diagnostic', ready: true, alt: 'An educator beside a wall of anatomical sketches', focus: { portrait: '48% 50%', landscape: '50% 30%' }, note: 'Good anatomy setting; held back because the stream already carries three similar portraits.' },
  { id: 'mentor-trainee-pair', use: 'unsuitable', ready: false, alt: 'Two colleagues posing together in front of a screen', focus: { portrait: '60% 50%', landscape: '50% 30%' }, note: 'Posed pair reads as a real mentor/trainee relationship or a testimonial; risks implying affiliation.' },
];

const BY_ID = new Map(PHOTOS.map((p) => [p.id, p]));

export function getPhoto(id: string): PhotoEntry {
  const p = BY_ID.get(id);
  if (!p) throw new Error(`photography: unknown image id "${id}"`);
  if (!p.ready) throw new Error(`photography: "${id}" is a reserve image with no web files yet (run scripts/photo-library/build-library.py --ids ${id})`);
  return p;
}
