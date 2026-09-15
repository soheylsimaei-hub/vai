-- pgTAP: Ask VAI case + reasoning-output isolation, and the reasoning
-- follow-up-is-a-linked-record-not-an-overwrite guarantee.
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

-- Seed one case for each vet, inserted as service_role (bypasses RLS, as a
-- real backend process would when writing on the vet's behalf).
set local role service_role;

insert into ask_vai_cases (id, veterinarian_id, narrative_text, vet_working_theory)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Case A', 'Pancreatitis, maybe'),
  ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'Case B', null);

insert into ask_vai_reasoning_outputs (case_id, turn_number, understanding, confidence_level)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 1, 'Initial reasoning for Case A', 'moderate'),
  ('bbbbbbbb-0000-0000-0000-000000000001', 1, 'Initial reasoning for Case B', 'low');

-- Act as Vet A.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

select results_eq(
  $$ select count(*)::int from ask_vai_cases $$,
  $$ values (1) $$,
  'Vet A sees exactly one case — their own, never Vet B''s'
);

select is(
  (select narrative_text from ask_vai_cases limit 1),
  'Case A',
  'The visible case is Vet A''s own'
);

select results_eq(
  $$ select count(*)::int from ask_vai_reasoning_outputs $$,
  $$ values (1) $$,
  'Vet A sees only the reasoning output linked to their own case, never Vet B''s, via the case-ownership policy'
);

-- Vet A cannot insert a reasoning output against Vet B's case id.
select throws_ok(
  $$ insert into ask_vai_reasoning_outputs (case_id, turn_number, understanding, confidence_level)
     values ('bbbbbbbb-0000-0000-0000-000000000001', 2, 'attempted cross-case write', 'low') $$,
  '42501',
  null,
  'Vet A cannot insert a reasoning output against a case they do not own'
);

-- The follow-up-turn-is-linked-not-overwritten guarantee.
insert into ask_vai_reasoning_outputs (case_id, turn_number, understanding, confidence_level, followup_message)
values ('aaaaaaaa-0000-0000-0000-000000000001', 2, 'Follow-up reasoning for Case A', 'moderate', 'What about X?');

select results_eq(
  $$ select count(*)::int from ask_vai_reasoning_outputs where case_id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  $$ values (2) $$,
  'A follow-up turn adds a second linked reasoning_output row — turn 1 is never overwritten'
);

select is(
  (select understanding from ask_vai_reasoning_outputs where case_id = 'aaaaaaaa-0000-0000-0000-000000000001' and turn_number = 1),
  'Initial reasoning for Case A',
  'The original turn-1 record is unchanged after the follow-up turn is added'
);

select * from finish();
rollback;
