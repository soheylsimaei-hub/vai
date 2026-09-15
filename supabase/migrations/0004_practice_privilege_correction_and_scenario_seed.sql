-- PRIVILEGE (approved): RLS's ownership join only verifies WHICH row a
-- client can reach, never WHETHER its content is genuine. transcript is
-- later relied on by the deterministic quote-verification gate as ground
-- truth; quote_verification_status is the schema's most safety-critical
-- field. Both move to service_role-only writes; authenticated keeps
-- SELECT (existing RLS policies, unchanged).
revoke insert, update on practice_attempts from authenticated;
revoke insert on practice_feedback from authenticated;

-- SCHEMA CORRECTION: disclosure_rules/behavior_rules were written to hold
-- a structured representation of scenario behavior that has never existed
-- for this scenario — the real behavior rules are prose inside the frozen
-- prompt (src/prompts/practice-persona-diane-biscuit.v1.md), and the
-- disclosure-gate mechanic is universal code (src/lib/practice/hidden-
-- state.ts), not scenario-specific data. Forcing NOT NULL here would
-- require inventing a second, partially-reconstructed representation of
-- already-authoritative content — rejected. Made nullable instead: NULL
-- honestly means "not modeled in the current architecture," which is the
-- truth, rather than a placeholder pretending otherwise.
alter table practice_scenarios
  alter column disclosure_rules drop not null,
  alter column behavior_rules drop not null;

-- SEED: one-time administrative insert (run here, not via the app's
-- service_role key, which only ever gets SELECT on this table) — matches
-- the table's own "scenario content is authored out-of-band" design.
-- Every value below is copied verbatim from src/lib/practice/scenario.ts
-- (dianeBiscuitScenario) — nothing invented. disclosure_rules/
-- behavior_rules are omitted (left NULL) rather than populated with
-- placeholder content.
insert into practice_scenarios (
  slug, title, patient, clinical_context, owner_profile,
  stated_concern, hidden_concern, never_reveal, feedback_reference_points, is_active
) values (
  'dental-recommendation-v1',
  'The Dental Recommendation',
  '{"species": "Canine", "breed": "Cavalier King Charles Spaniel", "age": "7-year-old", "sex": "Neutered male"}'::jsonb,
  '{"reasonForVisit": "Recheck following dental assessment", "relevantHistory": "Moderate periodontal disease noted at last visit; dental cleaning with likely extractions recommended, under general anaesthesia."}'::jsonb,
  '{"name": "Diane Whitfield"}'::jsonb,
  'Cost',
  'A previous dog died under anaesthesia years ago, at a different clinic, for an unrelated procedure — never fully processed.',
  '["That this is a simulation or that she is an AI", "The scoring/trust/disclosure-gate mechanic", "Any admission of \"testing\" the veterinarian", "The hidden concern before the disclosure gate genuinely opens"]'::jsonb,
  '["Whether the vet asked an open, non-assumptive question about the hesitation itself before addressing cost", "Whether the vet accepted \"it''s about cost\" at face value and moved straight to reassurance/payment plans", "The specific turn where Diane''s responses lengthen (opening) or shorten (closing)", "Whether a surfaced concern was met with genuine attentiveness or reassurance-by-statistics"]'::jsonb,
  true
);
