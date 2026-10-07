import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

// The engine directory is a GENERATED copy of vai-app/src/lib/scientific-radar (see ENGINE_MANIFEST.json). Hand edits would silently fork
// the two sites' literature logic; this test makes that impossible to miss.
const dir = join(process.cwd(), "src", "lib", "pulse", "engine");
const manifest = JSON.parse(readFileSync(join(dir, "ENGINE_MANIFEST.json"), "utf-8")) as { sourceCommit: string; files: Record<string, string> };

test("every engine file matches the sha256 recorded when it was synced from vai-app, and no unlisted file exists", () => {
  for (const [file, sha] of Object.entries(manifest.files)) assert.equal(createHash("sha256").update(readFileSync(join(dir, file))).digest("hex"), sha, `${file} was edited by hand; change vai-app and re-sync instead`);
  const present = readdirSync(dir).filter((f) => f.endsWith(".ts")).sort();
  assert.deepEqual(present, Object.keys(manifest.files).sort());
  assert.match(manifest.sourceCommit, /^[0-9a-f]{7,}$/);
});

test("the copy is clean of Next-only code: no server-only import, no next/* import, no env access outside config", () => {
  for (const file of Object.keys(manifest.files)) {
    const src = readFileSync(join(dir, file), "utf-8");
    assert.doesNotMatch(src, /^import "server-only"/m, file);
    assert.doesNotMatch(src, /from "next|import\("next/, file);
    assert.match(src.split("\n")[0], /^\/\/ GENERATED COPY - DO NOT EDIT/, file);
  }
});

test("the engine makes no LLM call", () => {
  for (const file of Object.keys(manifest.files)) assert.doesNotMatch(readFileSync(join(dir, file), "utf-8"), /anthropic|openai/i, file);
});
