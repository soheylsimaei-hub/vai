-- pgTAP: Practice attempt/feedback isolation, scenario confidentiality, and
-- attempt-number relationship correctness.
-- Run via `supabase test db` — not executed in this environment; see
-- supabase/README.md.

begin;
select plan(6);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com');

insert into veterinarians (id, email, name) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com', 'Vet A'),
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com', 'Vet B');

set local role service_role;

insert into practice_scenarios (
  id, slug, title, patient, clinical_context, owner_profile,
  stated_concern, hidden_concern, disclosure_rules, behavior_rules, feedback_reference_points
) values (
  'cccccccc-0000-0000-0000-000000000001', 'dental-recommendation', 'The Dental Recommendation',
  '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
  'Cost', 'Anaesthesia fear from a prior loss', '{}'::jsonb, '{}'::jsonb, '{}'::jsonb
);

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values
  ('dddddddd-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1),
  ('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 1);

insert into practice_feedback (attempt_id, what_you_noticed, quote_verification_status)
values
  ('dddddddd-0000-0000-0000-000000000001', 'Feedback for Vet A''s attempt', '[]'::jsonb),
  ('eeeeeeee-0000-0000-0000-000000000001', 'Feedback for Vet B''s attempt', '[]'::jsonb);

-- Act as Vet A.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

select results_eq(
  $$ select count(*)::int from practice_attempts $$,
  $$ values (1) $$,
  'Vet A sees exactly one Practice attempt — their own, never Vet B''s'
);

select results_eq(
  $$ select count(*)::int from practice_feedback $$,
  $$ values (1) $$,
  'Vet A sees only the feedback linked to their own attempt'
);

select is(
  (select what_you_noticed from practice_feedback limit 1),
  'Feedback for Vet A''s attempt',
  'The visible feedback is Vet A''s own'
);

-- Vet A cannot insert an attempt claiming to be Vet B.
select throws_ok(
  $$ insert into practice_attempts (scenario_id, veterinarian_id, attempt_number)
     values ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 2) $$,
  '42501',
  null,
  'Vet A cannot insert a Practice attempt on Vet B''s behalf'
);

-- The scenario's hidden state is never client-readable, by anyone, even the
-- scenario's own participant — this is the deliberate design decision noted
-- in the migration: no select policy exists for authenticated users at all.
select is(
  (select count(*)::int from practice_scenarios),
  0,
  'No authenticated user can read practice_scenarios directly — hidden_concern and behavior_rules are never client-exposed (service-role/API-route only)'
);

-- attempt_number + scenario + vet uniqueness holds (Vet A re-inserting their
-- own attempt_number=1 is an RLS-permitted insert that must still fail on
-- the unique constraint, not silently duplicate).
select throws_ok(
  $$ insert into practice_attempts (scenario_id, veterinarian_id, attempt_number)
     values ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1) $$,
  '23505',
  null,
  'A duplicate (scenario, vet, attempt_number) for Vet A''s own row is rejected by the unique constraint, not silently duplicated'
);

select * from finish();
rollback;
