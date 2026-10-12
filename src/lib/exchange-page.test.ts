import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

// The public VAI Exchange page and its routing (2026-10-12). Source-level checks: the page exists as a real route, every public Exchange link goes to it, and the page keeps its honesty rules
// (an Expert Preview, an illustration that cannot be mistaken for activity, evidence kept distinct from opinion, no invented scale, working participation routes only).

const root = process.cwd();
const read = (p: string) => readFileSync(join(root, p), "utf8");
const PAGE = read("src/pages/exchange.astro");
const body = PAGE.replace(/^---[\s\S]*?\n---/, ""); // the rendered markup, without the frontmatter code

const srcFiles: string[] = [];
const walk = (dir: string) => { for (const n of readdirSync(dir)) { const f = join(dir, n); if (statSync(f).isDirectory()) walk(f); else if (/\.(astro|ts)$/.test(n) && !/\.test\.ts$/.test(n)) srcFiles.push(f); } };
walk(join(root, "src"));

test("/exchange/ is a real public page with the approved title, description and Expert Preview status", () => {
  assert.match(PAGE, /title="VAI Exchange \| Veterinary Clinical Knowledge & Professional Exchange"/);
  assert.match(PAGE, /description="VAI Exchange brings veterinary professionals together around clinical questions, cases, evidence and professional perspectives within the VAI platform\."/);
  assert.match(body, /<h1[^>]*>\s*Clinical knowledge, shared\.\s*<\/h1>/);
  assert.match(body, />Expert Preview<\/span>/);
});

test("every public Exchange link goes to /exchange/: navigation, footer, Academy ecosystem and the homepage call to action; no homepage anchor remains", () => {
  assert.match(read("src/components/Nav.astro"), /\{ href: '\/exchange\/', label: 'Exchange' \}/);
  assert.match(read("src/components/Footer.astro"), /\{ href: '\/exchange\/', label: 'Exchange' \}/);
  assert.match(read("src/pages/academy.astro"), /l: 'VAI Exchange', href: '\/exchange\/'/);
  assert.match(read("src/pages/index.astro"), /<a href="\/exchange\/" class="btn-brand btn-brand-primary">Explore VAI Exchange/);
  for (const f of srcFiles) assert.doesNotMatch(readFileSync(f, "utf8"), /['"]\/#exchange['"]/, `${f} still links to the homepage Exchange anchor`);
  assert.match(read("src/pages/index.astro"), /<section id="exchange"/, "the homepage still introduces Exchange");
});

test("the page makes no claim of scale or activity: no counts, no member or specialist numbers, no testimonials, no live-activity wording", () => {
  assert.doesNotMatch(body, /\b\d[\d,.]*\s*(members?|clinicians|specialists|cases|veterinarians|discussions|posts)\b/i);
  assert.doesNotMatch(body, /\b(testimonial|trusted by|thousands|hundreds|active community|join(ed)? by|already (live|available)|now live)\b/i);
  assert.doesNotMatch(body, /\b(planned|in planning|we hope|concept|someday|eventually|still being built|nothing is available|not yet available)\b/i);
  assert.doesNotMatch(body, /@\w+/, "no usernames");
});

test("the interface preview is labelled as an illustration, with no names, avatars, timestamps or engagement figures", () => {
  assert.match(body, /Illustrative interface/);
  assert.match(body, /It is not a real case, and these are not real clinicians or real posts\./);
  assert.doesNotMatch(body, /\b(Dr\.?|Prof\.?)\s+[A-Z]/);
  assert.doesNotMatch(body, /\b\d+\s?(min|minutes|hours?|days?)\s+ago\b|\b\d{1,2}:\d{2}\b|\blikes?\b|\breplies\b/i);
});

test("evidence, professional perspective and community discussion are kept distinct, and community content never becomes evidence", () => {
  for (const t of ["Evidence", "Professional perspective", "Community discussion"]) assert.match(body, new RegExp(`>${t}<`), t);
  assert.match(body, /never presented as evidence/i);
  assert.match(body, /never treated as validated evidence/i);
  assert.match(body, /Content shared in Exchange is not added to Ask VAI(&rsquo;|’)s evidence base/);
  assert.match(body, /does not treat a consensus as clinical truth/);
  assert.match(body, /It does not provide a diagnosis, and it does not replace the judgement of the clinician responsible for the patient/);
});

test("participation uses a working route only: email to vai@vai.vet, and the app's Exchange for those with access; no form, no dead button", () => {
  assert.match(PAGE, /const JOIN_HREF = 'mailto:vai@vai\.vet\?subject=/);
  assert.match(PAGE, /const OPEN_EXCHANGE = 'https:\/\/app\.vai\.vet\/exchange'/);
  assert.doesNotMatch(body, /<form|<button|href="#"/);
  assert.equal((body.match(/Join the Expert Preview/g) ?? []).length, 2);
});

test("the ecosystem lists the five capabilities in order, with the platform's existing names", () => {
  const order = [...PAGE.matchAll(/\{ w: '(\w+)', l: '([^']+)'/g)].map((m) => `${m[1]}|${m[2]}`);
  assert.deepEqual(order, ["Evidence|VAI Pulse", "Reason|Ask VAI", "Practise|VAI Practice", "Exchange|VAI Exchange", "Develop|VAI Veterinary Academy"]);
});

test("house copy rules hold on the page: no em-dashes, no exclamation marks, nothing about a forum, no VIN", () => {
  assert.doesNotMatch(body, /—|&mdash;|!<|! /);
  assert.doesNotMatch(PAGE, /\bVIN\b|vin\.com/i);
  assert.doesNotMatch(body, /\bforum\b|\bReddit\b|\bFacebook\b/i);
});
