import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

// Identity guard (founder instruction, 2026-10-10): Academia Europa and the name "Veterinary Academy International" must not appear anywhere on the public site, and the only public email addresses
// are vai@vai.vet and faculty@vai.vet. This reads the shipped source (pages, components, layouts, public files, build helpers), not the documentation that states the rule.

const root = process.cwd();
const files: string[] = [];
const walk = (dir: string) => {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) { if (!["node_modules", "dist", ".git", "pulse-cache"].includes(name)) walk(full); continue; }
    if (/\.(astro|ts|tsx|js|mjs|json|webmanifest|svg|txt|xml|css|html|md)$/.test(name)) files.push(full);
  }
};
for (const dir of ["src", "public"]) walk(join(root, dir));
const shipped = files.filter((f) => !/\.test\.ts$/.test(f));
const read = (f: string) => readFileSync(f, "utf8");

test("no shipped file names Academia Europa, its domain, or Veterinary Academy International", () => {
  const bad = shipped.filter((f) => /academia ?europa|academiaeuropa|veterinary academy international/i.test(read(f))).map((f) => f.replace(root + "/", ""));
  assert.deepEqual(bad, []);
});

test("the only email addresses in the public site are vai@vai.vet and faculty@vai.vet", () => {
  const found = new Set<string>();
  for (const f of shipped) for (const m of read(f).match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g) ?? []) if (!/\.(png|jpe?g|webp|svg)$/i.test(m)) found.add(m.toLowerCase());
  assert.deepEqual([...found].sort(), ["faculty@vai.vet", "vai@vai.vet"]);
});

test("the contact form no longer posts to a placeholder service and names the VAI endpoint and the approved categories", () => {
  const form = read(join(root, "src/components/ContactForm.astro"));
  assert.doesNotMatch(form, /formspree|YOUR_FORMSPREE_ID/i);
  assert.match(form, /https:\/\/app\.vai\.vet\/api\/public-contact/);
  for (const c of ["General Enquiry", "VAI Platform", "VAI Veterinary Academy", "Faculty Collaboration", "Partnerships & Organisations", "Other"]) assert.ok(form.includes(c), c);
  assert.match(form, /name="website"/, "honeypot present");
  assert.match(form, /type="checkbox" required/, "explicit consent required");
});

test("the contact page uses the approved headline and legal identity line, and the live form switch is documented", () => {
  const page = read(join(root, "src/pages/contact.astro"));
  assert.match(page, /title="Let’s Start a Conversation"/);
  assert.match(page, /eyebrow="Contact VAI"/);
  assert.match(page, /operated by <strong[^>]*>Solex Education Unipessoal Lda<\/strong>, a company registered in Portugal/);
  assert.match(page, /const FORM_LIVE = (true|false);/);
  assert.match(page, /550 5\.1\.1/, "the reason the form is gated is recorded next to the switch");
});
