-- pgTAP: veterinarian profile isolation.
-- Run via `supabase test db` (requires the local Supabase CLI + Docker —
-- not available in the environment this was written in; see
-- supabase/README.md "Test execution status").

begin;
select plan(5);

-- Two real auth users, minimal.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com');

insert into veterinarians (id, email, name) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com', 'Vet A'),
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com', 'Vet B');

-- Act as Vet A.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

select results_eq(
  $$ select count(*)::int from veterinarians $$,
  $$ values (1) $$,
  'Vet A sees exactly their own profile row, never Vet B''s'
);

select is(
  (select name from veterinarians limit 1),
  'Vet A',
  'The one visible row is Vet A''s own'
);

-- Vet A cannot update Vet B's row (RLS blocks the row from matching at all).
update veterinarians set name = 'Hacked' where id = '22222222-2222-2222-2222-222222222222';
select results_eq(
  $$ select name from veterinarians where id = '22222222-2222-2222-2222-222222222222' $$,
  $$ values (null::text) $$,
  'Vet A''s update against Vet B''s row affects zero rows (row invisible under RLS, not just unauthorized)'
);

-- Vet A cannot insert a row claiming to be Vet B.
select throws_ok(
  $$ insert into veterinarians (id, email, name) values ('33333333-3333-3333-3333-333333333333', 'x@example.com', 'x') $$,
  '42501',
  null,
  'Vet A cannot insert a profile row for a different id (RLS insert check fails)'
);

-- Vet A cannot grant themselves an active subscription by updating their own
-- row directly — column-level grants restrict authenticated writes to
-- profile fields only; membership_status is service_role-only.
select throws_ok(
  $$ update veterinarians set membership_status = 'active' where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501',
  null,
  'Vet A cannot set their own membership_status — column-level grant blocks this even on their own row'
);

select * from finish();
rollback;
