-- pgTAP: veterinarian profile-onboarding column grants (migration 0005).
-- Run via `supabase test db` (requires the local Supabase CLI + Docker —
-- not available in the environment this was written in; see
-- supabase/README.md "Test execution status", same as every other file
-- in this directory).

begin;
select plan(4);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com');

insert into veterinarians (id, email, name) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com', 'vet-a@example.com');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

-- A vet can complete their own onboarding — the exact write
-- completeOnboardingAction performs.
update veterinarians
  set title = 'Dr', first_name = 'Jane', last_name = 'Vet'
  where id = '11111111-1111-1111-1111-111111111111';

select results_eq(
  $$ select title, first_name, last_name from veterinarians where id = '11111111-1111-1111-1111-111111111111' $$,
  $$ values ('Dr'::text, 'Jane'::text, 'Vet'::text) $$,
  'A vet can set their own title/first_name/last_name via the new column-scoped UPDATE grant'
);

-- The title check constraint rejects anything outside the restrained,
-- founder-approved set (or NULL) — a client cannot write an arbitrary
-- freeform title even though first_name/last_name are unconstrained text.
select throws_ok(
  $$ update veterinarians set title = 'Lord' where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514',
  null,
  'An invalid title is rejected by the check constraint, not silently accepted'
);

-- Completing onboarding still cannot smuggle a commercial-field write into
-- the same statement — the new grant is additive and column-scoped
-- exactly like every other profile-field grant in 0001; it does not
-- widen what a vet can touch on their own row.
select throws_ok(
  $$ update veterinarians set first_name = 'Jane', membership_status = 'active' where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501',
  null,
  'A vet cannot ride along a membership_status write on the same statement as a legitimate onboarding update'
);

-- Vet A still cannot reach Vet B's row to onboard on their behalf — RLS
-- from 0001 is untouched by this migration.
--
-- Fixture setup needs the elevated pgTAP context, not the `authenticated`
-- session line 16 downgraded to — `authenticated` correctly has no INSERT
-- grant on auth.users (that schema is GoTrue-managed), so creating Vet B's
-- rows must happen after resetting role, not by widening that grant.
reset role;

insert into auth.users (id, email) values
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com');
insert into veterinarians (id, email, name) values
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com', 'vet-b@example.com');

-- Restore Vet A's authenticated session before the actual cross-user
-- assertion below — it must run as Vet A, not as the elevated fixture role,
-- for RLS to be the thing actually being tested.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

update veterinarians set first_name = 'Hacked' where id = '22222222-2222-2222-2222-222222222222';
select is_empty(
  $$ select first_name from veterinarians where id = '22222222-2222-2222-2222-222222222222' $$,
  'Vet A''s onboarding update against Vet B''s row affects zero rows (row invisible under RLS, not just unauthorized)'
);

select * from finish();
rollback;
