-- Phase 6C production close-out — DATA-SEED ONLY migration.
--
-- Why this is a migration and not a runtime script: practice_scenarios has
-- only ever granted service_role SELECT (0001, re-confirmed 0002) — every
-- prior write to this table (the dental-recommendation-v1 seed in 0004,
-- its taxonomy backfill in 0010) was done as a privileged migration
-- statement, never by the app's service_role key at request time. Running
-- vai-app's scripts/provision-generative-topics.ts against production
-- confirmed this the hard way: "permission denied for table
-- practice_scenarios" (service_role has no INSERT grant). This migration
-- follows that same established precedent rather than opening a new grant.
--
-- What this adds: one practice_scenarios row per Phase 6C generative
-- Difficult Conversations topic (vai-app's src/lib/practice/generative-
-- topics.ts) — six rows total, slugs `generative-<topic>`. These rows
-- carry NO scenario truth (no real patient, owner, or hidden concern):
-- every NOT NULL/formerly-NOT-NULL content column gets an explicit,
-- honest placeholder stating that real content is generated fresh per
-- attempt by vai-app's generative-scenario-service.ts and frozen only on
-- that attempt's own practice_attempts.scenario_variant (jsonb) — never on
-- this shared row. This mirrors exactly how dental-recommendation-v1 is a
-- real, content-bearing row for the one authored scenario; these six are
-- identity/gate anchors only, for the generative scenario, per topic.
--
-- Scope, deliberately narrow — this migration contains ONLY:
--   - one multi-row INSERT into practice_scenarios.
-- It does NOT touch: service_role/authenticated grants, RLS, policies,
-- schema (no ADD/ALTER/DROP COLUMN, no new constraint), triggers,
-- functions, or entitlement logic. It does not UPDATE, UPSERT, or DELETE
-- any row — dental-recommendation-v1 is not referenced anywhere in this
-- file and cannot be touched by it. `slug` is UNIQUE (0001); if any of
-- these six slugs already existed, this plain INSERT would fail cleanly
-- with a unique-violation and write nothing (Supabase wraps each
-- migration in a transaction) — verified via read-only production query
-- immediately before drafting this file that none of the six exist yet.
insert into practice_scenarios (
  slug, title,
  patient, clinical_context, owner_profile,
  stated_concern, hidden_concern,
  disclosure_rules, behavior_rules,
  never_reveal, feedback_reference_points,
  is_active,
  discipline, topic, difficulty,
  scenario_version, validation_status, tags,
  prompt_source, legacy_system_prompt_file,
  clinical_objective_enabled, communication_objective_enabled,
  provenance
) values
  (
    'generative-cost-objection',
    'Generative: Cost Objection',
    '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
    'Generated fresh per attempt — not authored on this row.',
    'Generated fresh per attempt — not authored on this row.',
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '[]'::jsonb,
    '["Generated fresh per attempt — see the attempt''s own frozen scenario_variant."]'::jsonb,
    true,
    'difficult-conversations', 'cost-objection', null,
    1, 'approved', '["generative"]'::jsonb,
    'structured_template', null,
    false, true,
    jsonb_build_object('author', 'VAI product team', 'source', 'Phase 6C generative engine', 'dateAuthored', '2026-09-17')
  ),
  (
    'generative-treatment-refusal',
    'Generative: Treatment Refusal',
    '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
    'Generated fresh per attempt — not authored on this row.',
    'Generated fresh per attempt — not authored on this row.',
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '[]'::jsonb,
    '["Generated fresh per attempt — see the attempt''s own frozen scenario_variant."]'::jsonb,
    true,
    'difficult-conversations', 'treatment-refusal', null,
    1, 'approved', '["generative"]'::jsonb,
    'structured_template', null,
    false, true,
    jsonb_build_object('author', 'VAI product team', 'source', 'Phase 6C generative engine', 'dateAuthored', '2026-09-17')
  ),
  (
    'generative-angry-dissatisfied-owner',
    'Generative: Angry / Dissatisfied Owner',
    '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
    'Generated fresh per attempt — not authored on this row.',
    'Generated fresh per attempt — not authored on this row.',
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '[]'::jsonb,
    '["Generated fresh per attempt — see the attempt''s own frozen scenario_variant."]'::jsonb,
    true,
    'difficult-conversations', 'angry-dissatisfied-owner', null,
    1, 'approved', '["generative"]'::jsonb,
    'structured_template', null,
    false, true,
    jsonb_build_object('author', 'VAI product team', 'source', 'Phase 6C generative engine', 'dateAuthored', '2026-09-17')
  ),
  (
    'generative-end-of-life-discussion',
    'Generative: Euthanasia / End-of-Life Discussion',
    '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
    'Generated fresh per attempt — not authored on this row.',
    'Generated fresh per attempt — not authored on this row.',
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '[]'::jsonb,
    '["Generated fresh per attempt — see the attempt''s own frozen scenario_variant."]'::jsonb,
    true,
    'difficult-conversations', 'end-of-life-discussion', null,
    1, 'approved', '["generative"]'::jsonb,
    'structured_template', null,
    false, true,
    jsonb_build_object('author', 'VAI product team', 'source', 'Phase 6C generative engine', 'dateAuthored', '2026-09-17')
  ),
  (
    'generative-non-adherence',
    'Generative: Non-Adherence / Non-Compliance',
    '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
    'Generated fresh per attempt — not authored on this row.',
    'Generated fresh per attempt — not authored on this row.',
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '[]'::jsonb,
    '["Generated fresh per attempt — see the attempt''s own frozen scenario_variant."]'::jsonb,
    true,
    'difficult-conversations', 'non-adherence', null,
    1, 'approved', '["generative"]'::jsonb,
    'structured_template', null,
    false, true,
    jsonb_build_object('author', 'VAI product team', 'source', 'Phase 6C generative engine', 'dateAuthored', '2026-09-17')
  ),
  (
    'generative-diagnostic-uncertainty',
    'Generative: Diagnostic Uncertainty',
    '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
    'Generated fresh per attempt — not authored on this row.',
    'Generated fresh per attempt — not authored on this row.',
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '"Generated fresh per attempt — see the attempt''s own frozen scenario_variant."'::jsonb,
    '[]'::jsonb,
    '["Generated fresh per attempt — see the attempt''s own frozen scenario_variant."]'::jsonb,
    true,
    'difficult-conversations', 'diagnostic-uncertainty', null,
    1, 'approved', '["generative"]'::jsonb,
    'structured_template', null,
    false, true,
    jsonb_build_object('author', 'VAI product team', 'source', 'Phase 6C generative engine', 'dateAuthored', '2026-09-17')
  );
