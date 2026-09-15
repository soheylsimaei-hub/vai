-- pgTAP: veterinarian extended-profile column grants (migration 0006).
-- Run via `supabase test db` (requires the local Supabase CLI + Docker —
-- not available in the environment this was written in; see
-- supabase/README.md "Test execution status", same as every other file
-- in this directory).

begin;
select plan(5);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com');
insert into veterinarians (id, email, name) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com', 'vet-a@example.com');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

-- A full Account-page-style save: every editable profile column in one
-- statement — spanning the 0001 grant (role, country), the 0005 grant
-- (title, first_name, last_name), and this migration's new grant (city,
-- address, postal_code, organization_name) — is exactly the write
-- pattern the real Account UI will perform.
update veterinarians set
  title = 'Dr',
  first_name = 'Jane',
  last_name = 'Vet',
  role = 'Veterinarian',
  country = 'United Kingdom',
  city = 'London',
  address = '1 Example Street',
  postal_code = 'SW1A 1AA',
  organization_name = 'Example Veterinary Practice'
where id = '11111111-1111-1111-1111-111111111111';

select results_eq(
  $$ select city, address, postal_code, organization_name from veterinarians where id = '11111111-1111-1111-1111-111111111111' $$,
  $$ values ('London'::text, '1 Example Street'::text, 'SW1A 1AA'::text, 'Example Veterinary Practice'::text) $$,
  'A vet can save a full professional profile (all nine editable columns, across three migrations'' grants) in one statement'
);

select is(
  (select role from veterinarians where id = '11111111-1111-1111-1111-111111111111'),
  'Veterinarian',
  'Pre-existing grants (role, from 0001) are unaffected by this migration — still updatable alongside the new columns'
);

-- The new columns are free text with no check constraint (unlike title) —
-- an empty-but-present value is a legitimate "cleared this field" state,
-- consistent with "do not make address fields mandatory."
update veterinarians set address = '' where id = '11111111-1111-1111-1111-111111111111';
select is(
  (select address from veterinarians where id = '11111111-1111-1111-1111-111111111111'),
  '',
  'address has no check constraint — clearing it to an empty string is accepted, not rejected as invalid'
);

-- Still cannot smuggle a commercial-field write into the same statement —
-- the new grant is additive and column-scoped exactly like every other
-- profile-field grant in 0001/0005; it does not widen what a vet can
-- touch on their own row.
select throws_ok(
  $$ update veterinarians set city = 'Paris', membership_status = 'active' where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501',
  null,
  'A vet cannot ride along a membership_status write on the same statement as a legitimate profile update'
);

-- Vet A still cannot reach Vet B's row — RLS ownership isolation from
-- 0001 is completely untouched by this migration.
insert into auth.users (id, email) values
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com');
insert into veterinarians (id, email, name) values
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com', 'vet-b@example.com');

update veterinarians set city = 'Hacked' where id = '22222222-2222-2222-2222-222222222222';
select results_eq(
  $$ select city from veterinarians where id = '22222222-2222-2222-2222-222222222222' $$,
  $$ values (null::text) $$,
  'Vet A''s update against Vet B''s row affects zero rows (row invisible under RLS, not just unauthorized)'
);

select * from finish();
rollback;
