#!/usr/bin/env node
// Post-build verification for VAI Pulse (runs in CI after `astro build`, and locally). Fails the deploy if the generated site is not sound.
//   node scripts/verify-pulse-build.mjs [distDir]
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const dist = process.argv[2] ?? "dist";
// Escape hatch for an urgent site deploy while PubMed is down AND no cached snapshot exists (workflow_dispatch input allow_degraded).
if (process.env.PULSE_ALLOW_DEGRADED === "1") { console.log("VAI Pulse verification SKIPPED (PULSE_ALLOW_DEGRADED=1): the degraded Pulse pages will be published as built."); process.exit(0); }
const failures = [];
const check = (ok, msg) => { if (!ok) failures.push(msg); };
const read = (p) => readFileSync(join(dist, p), "utf-8");
const walk = (dir) => readdirSync(dir).flatMap((n) => { const p = join(dir, n); return statSync(p).isDirectory() ? walk(p) : [p]; });

const pulseDir = join(dist, "pulse");
check(existsSync(pulseDir), "dist/pulse is missing");
const pages = existsSync(pulseDir) ? walk(pulseDir).filter((p) => p.endsWith("index.html")) : [];
check(pages.length === 122, `expected 122 Pulse pages (2 defaults + 120 combinations), found ${pages.length}`);

let cards = 0, pmcLinks = 0, emptyPages = 0, unavailablePages = 0;
for (const file of pages) {
  const html = readFileSync(file, "utf-8");
  const rel = file.replace(dist, "");
  const isIndexable = rel === "/pulse/index.html" || rel === "/pulse/guidelines/index.html";
  check(/<h1[^>]*>VAI Pulse<\/h1>/.test(html), `${rel}: missing H1 "VAI Pulse"`);
  check(html.includes("What&#39;s new in veterinary medicine.") || html.includes("What’s new in veterinary medicine.") || html.includes("What&rsquo;s new in veterinary medicine."), `${rel}: missing tagline`);
  check(!/Scientific Radar/i.test(html), `${rel}: internal name "Scientific Radar" leaked into the public page`);
  check(!/undefined|\[object Object\]|NaN/.test(html.replace(/<script[\s\S]*?<\/script>/g, "")), `${rel}: contains undefined/[object Object]/NaN`);
  check(isIndexable ? !/<meta name="robots" content="[^"]*noindex/.test(html) : /<meta name="robots" content="[^"]*noindex/.test(html), `${rel}: wrong robots directive (defaults indexable, combinations noindex)`);
  check(/aria-label="Pulse view"/.test(html) && /aria-label="Discipline"/.test(html) && /aria-label="Time period"/.test(html), `${rel}: filters missing`);
  const chips = (html.match(/aria-label="Discipline"[\s\S]*?<\/nav>/) ?? [""])[0].match(/<li>/g)?.length ?? 0;
  check(chips === 15, `${rel}: expected 15 discipline filters, found ${chips}`);
  const articles = html.match(/<article/g)?.length ?? 0;
  cards += articles;
  const pubmedLinks = html.match(/href="https:\/\/pubmed\.ncbi\.nlm\.nih\.gov\/\d+\/"/g)?.length ?? 0;
  check(pubmedLinks >= articles * 2 || articles === 0, `${rel}: every card needs PubMed links (${articles} cards, ${pubmedLinks} links)`);
  pmcLinks += html.match(/href="https:\/\/pmc\.ncbi\.nlm\.nih\.gov\/articles\/PMC\d+\/"/g)?.length ?? 0;
  // only Pulse's own card links (the site footer's pre-existing LinkedIn link is out of scope here)
  for (const art of html.match(/<article[\s\S]*?<\/article>/g) ?? []) for (const m of art.matchAll(/<a [^>]*target="_blank"[^>]*>/g)) check(/rel="noopener noreferrer"/.test(m[0]), `${rel}: card link without rel=noopener noreferrer`);
  if (articles === 0) { if (/No papers match this selection/.test(html)) emptyPages++; else if (/PubMed isn(?:&rsquo;|&#39;|’|')t responding/.test(html)) unavailablePages++; else failures.push(`${rel}: no cards and no empty/unavailable state`); }
  check(!/api_key|NCBI_API_KEY|VAI_PUBMED_CONTACT_EMAIL|tool=vai-/.test(html), `${rel}: leaks NCBI configuration`);
}
check(cards > 500, `suspiciously few cards across Pulse pages: ${cards}`);
check(pages.length === 0 || unavailablePages < pages.length * 0.1, `${unavailablePages} Pulse pages are in the unavailable state`);

// the default pages must have real content
for (const p of ["pulse/index.html", "pulse/guidelines/index.html"]) if (existsSync(join(dist, p))) check((read(p).match(/<article/g)?.length ?? 0) >= 5, `${p}: fewer than 5 records`);

// spacing tiers: every sec-* class used in the HTML must exist in the built CSS (a missing rule silently collapses a section's padding to 0)
{
  const css = readdirSync(join(dist, "_astro")).filter((f) => f.endsWith(".css")).map((f) => readFileSync(join(dist, "_astro", f), "utf-8")).join("\n");
  const used = new Set([...read("index.html").matchAll(/\bsec-(hero|feature|standard|compact)\b/g)].map((m) => m[1]));
  for (const tier of used) check(new RegExp(`\\.sec-${tier}\\{padding-block:`).test(css), `spacing tier sec-${tier} is used on the homepage but missing from the built CSS`);
  check(used.size >= 3, "homepage uses fewer than 3 spacing tiers");
}

// texture system: decorative only (hidden from assistive tech), no raster images or scripts, every placement class defined in the built CSS
{
  const home = read("index.html");
  const css = readdirSync(join(dist, "_astro")).filter((f) => f.endsWith(".css")).map((f) => readFileSync(join(dist, "_astro", f), "utf-8")).join("\n");
  const layers = [...home.matchAll(/<div class="tx tx--[a-z]+ tx-p-([a-z]+)"[^>]*>/g)];
  check(layers.length >= 8, `homepage has ${layers.length} texture layers (expected 8+)`);
  for (const m of layers) {
    check(/aria-hidden="true"/.test(m[0]), `texture layer tx-p-${m[1]} is not aria-hidden`);
    check(new RegExp(`\\.tx-p-${m[1]}\\{`).test(css), `placement tx-p-${m[1]} is used but missing from the built CSS`);
  }
  check(/\.tx\{[^}]*pointer-events:none/.test(css), "texture layers must be pointer-events:none");
  const decorativeSvgs = home.match(/<svg[^>]*aria-hidden="true"[^>]*focusable="false"/g) ?? [];
  check(decorativeSvgs.length === layers.length, "every texture SVG must be aria-hidden and not focusable");
  check(!/<svg[^>]*aria-hidden="true"[^>]*>(?:(?!<\/svg>)[\s\S])*?<(title|desc|text|image)\b/.test(home), "texture SVGs must contain no title/desc/text/image");
  check(!/background(-image)?:[^;"]*url\([^)]*(png|jpe?g|webp|gif)/.test(css.split(".tx")[1] ?? ""), "texture must not use raster backgrounds");
}

// About page + photography: institutional positioning, honest imagery, no layout shift, no accessibility regression
{
  const about = read("about/index.html");
  const css = readdirSync(join(dist, "_astro")).filter((f) => f.endsWith(".css")).map((f) => readFileSync(join(dist, "_astro", f), "utf-8")).join("\n");
  check(!/Simaei|founder-portrait|Founder-led|Founder &amp; Academic|leadership note/i.test(about), "about: founder-centric content has returned");
  check(!/VAI (faculty|experts?|team|members|community)\b/i.test(about.replace(/The people shown are not VAI faculty, team or members\./g, "")), "about: imagery or copy implies VAI faculty/team/members");
  const imgs = [...about.matchAll(/<img\b[^>]*>/g)].map((m) => m[0]).filter((t) => /photography\/library/.test(t));
  check(imgs.length >= 5 && imgs.length <= 9, `about: photography must stay restrained (5-9 library images), found ${imgs.length}`);
  check(!/enterprise-clinic-team/.test(about), "about: the clinic-team image is reserved for Enterprise / VAI for Teams");
  for (const h of ["Built around how veterinary", "Veterinary knowledge is growing", "From evidence to capability", "Professional trust has to be earned", "The evidence keeps moving", "A professional system that learns", "Bring the case that"]) {
    const sec = about.split("<section").find((x) => x.includes(h)) ?? "";
    check(sec !== "" && !/photography\/library/.test(sec), `about: the section "${h}" must carry no photography`);
  }
  for (const t of imgs) {
    check(/\bwidth="\d+"/.test(t) && /\bheight="\d+"/.test(t), "about: image without width/height (layout shift)");
    check(/loading="lazy"/.test(t), "about: library image is not lazy-loaded");
    check(/\balt(=|\s|>)/.test(t), "about: image without an alt attribute (decorative images render a bare alt, which is an empty alt)");
  }
  check(/Illustrative imagery generated for VAI\./.test(about), "about: photography disclosure missing");
  check(!/ph-track|ph-drift/.test(css + about), "photography must be static (no moving stream)");
  check(/\.font-brand-serif\{/.test(css) && /\.eyebrow-brand\{/.test(css), "css: .font-brand-serif / .eyebrow-brand missing from the build (premature comment terminator?)");
  const leadership = read("about/leadership/index.html");
  check(/http-equiv="refresh"[^>]*url=\/about\//.test(leadership) && /noindex/.test(leadership), "about/leadership must be a noindex redirect to /about/");
  check(!/about\/leadership/.test(existsSync(join(dist, "sitemap-0.xml")) ? read("sitemap-0.xml") : ""), "sitemap: retired /about/leadership/ is still listed");
}

// Academy (temporary in-site presentation) + routing
{
  const academy = read("academy/index.html");
  const text = academy.replace(/<script[\s\S]*?<\/script>/g, "").replace(/<style[\s\S]*?<\/style>/g, "");
  check((academy.match(/<h1[\s>]/g) ?? []).length === 1, "academy: expected exactly one h1");
  check(/Education for the decisions that matter\./.test(academy), "academy: hero headline missing");
  check(!/Simaei|founder|Founder|Academic Director|Academia Europa/.test(text), "academy: founder-centric or Academia Europa content");
  check(!/Coming soon|coming soon|Enrol|enrol|Buy now|Add to cart|\u20ac\s?\d|\$\s?\d|accredit|CPD|ratings?\b|students enrolled|learners/i.test(text), "academy: unsupported commercial / accreditation / numbers claim");
  check(!/VAI (faculty|experts?|instructors?|students|customers|community)\b/i.test(text.replace(/The people shown are not VAI faculty, team or members\./g, "")), "academy: generated imagery implied to be VAI faculty/experts/students");
  const imgs = [...academy.matchAll(/<img\b[^>]*>/g)].map((m) => m[0]).filter((t) => /photography\/library/.test(t));
  check(imgs.length >= 4 && imgs.length <= 8, `academy: photography must stay curated (4-8 images), found ${imgs.length}`);
  check(imgs.some((t) => /trusted-vet-method-teaching/.test(t)), "academy: the authentic teaching photograph is missing");
  check(!/trusted-vet-method-flags/.test(academy + about_html()), "the flags photograph is reserved and must not be used");
  check(!/enterprise-clinic-team/.test(academy), "academy: the clinic-team image is reserved for Enterprise");
  for (const t of imgs) { check(/\bwidth="\d+"/.test(t) && /\bheight="\d+"/.test(t), "academy: image without width/height"); check(/loading="lazy"/.test(t), "academy: image not lazy"); }
  check(/<link rel="canonical" href="https:\/\/www\.vai\.vet\/academy\/"/.test(academy), "academy: canonical must be https://www.vai.vet/academy/");
  check(!/<meta name="robots" content="[^"]*noindex/.test(academy), "academy: must be indexable");
  check(/application\/ld\+json/.test(academy) && /EducationalOrganization/.test(academy), "academy: structured data missing");
  for (const f of ["index.html", "about/index.html", "academy/index.html", "pulse/index.html"]) {
    check(!/href="https:\/\/academy\.vai\.vet/.test(read(f)), `${f}: still links to the external Academy`);
    check(/href="\/academy\/"/.test(read(f)), `${f}: missing the internal /academy/ link`);
  }
}
function about_html() { return read("about/index.html"); }

// homepage
const home = read("index.html");
const homeSection = home.match(/<section id="pulse"[\s\S]*?<\/section>/)?.[0] ?? "";
check(homeSection !== "", "homepage: Pulse section missing");
const homeCards = homeSection.match(/<article/g)?.length ?? 0;
check(homeCards >= 3 && homeCards <= 6, `homepage: expected 3-6 highlights, found ${homeCards}`);
check(/Explore VAI Pulse/.test(homeSection) && /href="\/pulse\/"/.test(homeSection), "homepage: missing 'Explore VAI Pulse' link to /pulse/");
check(/What(’|&#39;|&rsquo;)s new in veterinary medicine\./.test(homeSection), "homepage: missing tagline");
check(/Stay current with the latest veterinary research, guidelines and consensus\s+statements\./.test(homeSection.replace(/\s+/g, " ")) || /Stay current with the latest veterinary research, guidelines and consensus statements\./.test(homeSection.replace(/\s+/g, " ")), "homepage: missing description");
check(!/<script[^>]*src="[^"]*pulse/.test(home), "homepage: unexpected Pulse client script");
// navigation
check(/<nav[^>]*>[\s\S]*?href="\/pulse\/"[^>]*>Pulse<\/a>/.test(home), "nav: 'Pulse' link missing");
// sitemap: only the two defaults
const sitemap = existsSync(join(dist, "sitemap-0.xml")) ? read("sitemap-0.xml") : "";
check(/https:\/\/www\.vai\.vet\/pulse\/<\/loc>/.test(sitemap), "sitemap: /pulse/ missing");
check(/https:\/\/www\.vai\.vet\/pulse\/guidelines\/<\/loc>/.test(sitemap), "sitemap: /pulse/guidelines/ missing");
check(!/\/pulse\/(latest|guidelines)\/[^<]+\//.test(sitemap), "sitemap: filter combinations must not be listed");

if (failures.length) { console.error(`VAI Pulse verification FAILED (${failures.length}):\n - ${failures.slice(0, 40).join("\n - ")}`); process.exit(1); }
console.log(`VAI Pulse verification passed: ${pages.length} pages, ${cards} cards (${pmcLinks} PMC links), ${emptyPages} empty-state pages, ${homeCards} homepage highlights.`);
