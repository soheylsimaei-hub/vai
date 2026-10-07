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
