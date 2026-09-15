-- pgTAP: Expert Opinion isolation, case-linkage correctness, and the
-- no-client-update guarantee (only the service role may set specialist
-- fields / the response).
-- Run via `supabase test db` — not executed in this environment; see
-- supabase/README.md.

begin;
select plan(5);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com');

insert into veterinarians (id, email, name) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com', 'Vet A'),
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com', 'Vet B');

set local role service_role;

insert into ask_vai_cases (id, veterinarian_id, narrative_text) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Case A'),
  ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'Case B');

insert into expert_opinion_requests (id, case_id, veterinarian_id, specialty, question_text, case_package)
values
  ('ffffffff-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Cardiology', 'Is this MMVD progression?', '{}'::jsonb),
  ('11223344-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'Dermatology', 'Q', '{}'::jsonb);

-- Act as Vet A.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

select results_eq(
  $$ select count(*)::int from expert_opinion_requests $$,
  $$ values (1) $$,
  'Vet A sees exactly one Expert Opinion request — their own, never Vet B''s'
);

select is(
  (select specialty from expert_opinion_requests limit 1),
  'Cardiology',
  'The visible request is Vet A''s own'
);

-- Vet A cannot request against Vet B's case.
select throws_ok(
  $$ insert into expert_opinion_requests (case_id, veterinarian_id, specialty, question_text, case_package)
     values ('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'X', 'X', '{}'::jsonb) $$,
  '42501',
  null,
  'Vet A cannot open an Expert Opinion request against a case they do not own'
);

-- No authenticated user, including the request's own owner, can set
-- specialist_name / response_text / status — no update policy exists.
select throws_ok(
  $$ update expert_opinion_requests set status = 'responded', response_text = 'forged response' where id = 'ffffffff-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'Vet A cannot self-assign a specialist response on their own request — only the service role (internal admin process) may update this table'
);

-- The service role can still complete the flow (the real, intended path).
set local role service_role;
update expert_opinion_requests
  set status = 'responded', specialist_name = 'Dr. Real Specialist', response_text = 'Genuine response text', responded_at = now()
  where id = 'ffffffff-0000-0000-0000-000000000001';

select is(
  (select status from expert_opinion_requests where id = 'ffffffff-0000-0000-0000-000000000001'),
  'responded',
  'The service-role path (the real internal admin process) can complete a request, confirming the block above is RLS-specific, not a broken table'
);

select * from finish();
rollback;
