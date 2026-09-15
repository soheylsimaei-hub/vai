-- pgTAP: field-level constraints — nullable vet_working_theory,
-- confidence_level enum enforcement, membership_status default,
-- quote_verification_status persistence.
-- Run via `supabase test db` — not executed in this environment; see
-- supabase/README.md.

begin;
select plan(6);

insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com');
insert into veterinarians (id, email, name) values ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com', 'Vet A');

-- membership_status defaults to 'trial' without being specified.
select is(
  (select membership_status from veterinarians where id = '11111111-1111-1111-1111-111111111111'),
  'trial',
  'A new veterinarian row defaults to membership_status = trial without it being set explicitly'
);

set local role service_role;

-- vet_working_theory is genuinely nullable — a case with no theory provided
-- must insert cleanly, per Change 1/4 (optional, never mandatory).
insert into ask_vai_cases (id, veterinarian_id, narrative_text, vet_working_theory)
values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Case with no theory', null);

select is(
  (select vet_working_theory from ask_vai_cases where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  null,
  'vet_working_theory is nullable — omitting it does not block case creation'
);

-- ...and it persists correctly when provided.
insert into ask_vai_cases (id, veterinarian_id, narrative_text, vet_working_theory)
values ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Case with a theory', 'Pyometra');

select is(
  (select vet_working_theory from ask_vai_cases where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  'Pyometra',
  'vet_working_theory persists correctly when the vet provides one'
);

-- confidence_level is a real enum constraint, not free text.
select throws_ok(
  $$ insert into ask_vai_reasoning_outputs (case_id, turn_number, understanding, confidence_level)
     values ('aaaaaaaa-0000-0000-0000-000000000001', 1, 'x', 'very confident indeed') $$,
  '23514',
  null,
  'confidence_level rejects any value outside low/moderate/high — it is a real structured field, not rendered-prose-only'
);

insert into ask_vai_reasoning_outputs (case_id, turn_number, understanding, confidence_level, uncertainty_flagged)
values ('aaaaaaaa-0000-0000-0000-000000000001', 1, 'Reasoning text', 'low', true);

select is(
  (select uncertainty_flagged from ask_vai_reasoning_outputs where case_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  true,
  'uncertainty_flagged persists as a real boolean, queryable without re-parsing prose'
);

-- quote_verification_status persists structured, per-claim data (the single
-- most safety-critical field in the schema).
insert into practice_scenarios (
  id, slug, title, patient, clinical_context, owner_profile,
  stated_concern, hidden_concern, disclosure_rules, behavior_rules, feedback_reference_points
) values (
  'cccccccc-0000-0000-0000-000000000001', 'test-scenario', 'Test Scenario',
  '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, 'x', 'y', '{}'::jsonb, '{}'::jsonb, '{}'::jsonb
);
insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('dddddddd-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1);
insert into practice_feedback (attempt_id, quote_verification_status)
values ('dddddddd-0000-0000-0000-000000000001', '[{"claim": "quoted text", "verified": true}, {"claim": "invented text", "verified": false}]'::jsonb);

select is(
  (select quote_verification_status -> 1 ->> 'verified' from practice_feedback where attempt_id = 'dddddddd-0000-0000-0000-000000000001'),
  'false',
  'Per-claim quote-verification results persist as structured, queryable data — a failed claim is recorded, not silently dropped or overwritten'
);

select * from finish();
rollback;
