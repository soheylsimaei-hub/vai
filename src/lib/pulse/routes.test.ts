import { test } from "node:test";
import assert from "node:assert/strict";
import { ALL_FILTERS, PERIODS } from "./engine/query";
import { DEFAULT_PULSE, allRequests, comboKey, isDefaultCombo, parseSlug, pulseHref, staticSlugs, type PulseRequest } from "./routes";

test("the static site pre-renders every view x discipline x period (2 x 15 x 4 = 120) plus the two short defaults", () => {
  assert.equal(allRequests().length, 2 * ALL_FILTERS.length * PERIODS.length);
  assert.equal(allRequests().length, 120);
  assert.equal(staticSlugs().length, 122);
  assert.equal(new Set(staticSlugs()).size, 122);
  assert.equal(new Set(allRequests().map(comboKey)).size, 120);
});

test("the two defaults get the short canonical URLs; everything else gets a full, trailing-slash path", () => {
  assert.equal(pulseHref(DEFAULT_PULSE), "/pulse/");
  assert.equal(pulseHref({ view: "guidelines", discipline: "all", period: "365d" }), "/pulse/guidelines/");
  assert.equal(pulseHref({ view: "latest", discipline: "cardiology", period: "30d" }), "/pulse/latest/cardiology/30d/");
  assert.equal(pulseHref({ view: "latest", discipline: "all", period: "7d" }), "/pulse/latest/all/7d/");
  assert.equal(pulseHref({ view: "guidelines", discipline: "all", period: "30d" }), "/pulse/guidelines/all/30d/", "guidelines default is 12 months, so 30d is not the default");
  assert.ok(isDefaultCombo(DEFAULT_PULSE) && !isDefaultCombo({ ...DEFAULT_PULSE, discipline: "equine" }));
});

test("every link round-trips through parseSlug, and the parser rejects anything outside the registry", () => {
  for (const r of allRequests()) {
    const href = pulseHref(r);
    const slug = href === "/pulse/" ? undefined : href.replace(/^\/pulse\//, "").replace(/\/$/, "");
    assert.deepEqual(parseSlug(slug), r, href);
  }
  assert.deepEqual(parseSlug(undefined), DEFAULT_PULSE);
  for (const bad of ["latest", "latest/nope/30d", "latest/all/99d", "x/all/30d", "latest/all/30d/extra", "../etc/passwd"]) assert.equal(parseSlug(bad), null, bad);
});

test("every route a page links to is one that is actually pre-rendered", () => {
  const rendered = new Set(staticSlugs().map((s) => (s === undefined ? "/pulse/" : `/pulse/${s}/`)));
  for (const r of allRequests()) assert.ok(rendered.has(pulseHref(r)), pulseHref(r));
  const _typecheck: PulseRequest = DEFAULT_PULSE; void _typecheck;
});
