-- pgTAP: Pilot Access entitlement enforcement — case/session/turn/message
-- limits, the active-Practice-session rule, grandfathering, the
-- enforcement_enabled kill-switch, and grant/RLS boundaries on the new
-- objects from 0007_pilot_access_entitlements.sql.
-- Run via `supabase test db` — not executed in this environment; see
-- supabase/README.md. True concurrent-connection races cannot be expressed
-- inside one pgTAP transaction — see vai-app/scripts/pilot-concurrency-test.ts
-- for the parallel-request abuse test, which needs a live database.

begin;
select plan(86);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com');

insert into veterinarians (id, email, name) values
  ('11111111-1111-1111-1111-111111111111', 'vet-a@example.com', 'Vet A'),
  ('22222222-2222-2222-2222-222222222222', 'vet-b@example.com', 'Vet B');

-- Both vets default to 'pilot' (the column default) — confirm that first.
select is(
  (select access_plan from veterinarians where id = '11111111-1111-1111-1111-111111111111'),
  'pilot',
  'New veterinarians default to the pilot access_plan'
);

-- ---------------------------------------------------------------------------
-- Enforcement is OFF by default: nothing restricts Vet A yet.
-- ---------------------------------------------------------------------------
select is(
  (select enforcement_enabled from entitlement_settings where id = 1),
  false,
  'Enforcement is disabled by default'
);

set local role service_role;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

-- 4 cases while disabled must all succeed (would exceed the limit of 3 if
-- enforcement were on) — proves the kill-switch genuinely no-ops.
--
-- created_at is set explicitly, deterministically earlier than activation,
-- rather than left to its `default now()` — this whole file runs inside one
-- pgTAP transaction, and Postgres's now() is transaction-scoped (the same
-- fixed instant for every statement in the transaction), so activation's own
-- enforcement_started_at := now() below would otherwise land on the exact
-- same instant as these rows' default created_at, defeating the
-- created_at >= enforcement_started_at grandfathering comparison entirely.
-- In real production usage this never comes up — historical rows and a real
-- activation call are genuinely separate transactions at genuinely
-- different wall-clock times.
insert into ask_vai_cases (veterinarian_id, narrative_text, created_at) values
  ('11111111-1111-1111-1111-111111111111', 'pre-activation case 1', now() - interval '1 hour'),
  ('11111111-1111-1111-1111-111111111111', 'pre-activation case 2', now() - interval '1 hour'),
  ('11111111-1111-1111-1111-111111111111', 'pre-activation case 3', now() - interval '1 hour'),
  ('11111111-1111-1111-1111-111111111111', 'pre-activation case 4', now() - interval '1 hour');

select is(
  (select count(*)::int from ask_vai_cases where veterinarian_id = '11111111-1111-1111-1111-111111111111'),
  4,
  'With enforcement disabled, a 4th case is NOT blocked (kill-switch genuinely no-ops)'
);

-- ---------------------------------------------------------------------------
-- Activate enforcement. Pre-activation usage above must be grandfathered —
-- it must NOT count against the fresh 3-case allowance.
-- ---------------------------------------------------------------------------
select activate_entitlement_enforcement();

select is(
  (select enforcement_enabled from entitlement_settings where id = 1),
  true,
  'activate_entitlement_enforcement() turns enforcement on'
);

select isnt(
  (select enforcement_started_at from entitlement_settings where id = 1),
  null,
  'activate_entitlement_enforcement() sets enforcement_started_at in the same call'
);

-- Grandfathering: Vet A already has 4 historical cases, but 0 of them are
-- "since activation" — they must be allowed a fresh 3.
insert into ask_vai_cases (veterinarian_id, narrative_text) values
  ('11111111-1111-1111-1111-111111111111', 'post-activation case 1'),
  ('11111111-1111-1111-1111-111111111111', 'post-activation case 2'),
  ('11111111-1111-1111-1111-111111111111', 'post-activation case 3');

select is(
  (select count(*)::int from ask_vai_cases where veterinarian_id = '11111111-1111-1111-1111-111111111111'),
  7,
  '3 post-activation cases succeed on top of 4 grandfathered ones (7 total) — historical usage was not counted'
);

-- The 4th post-activation case must now fail.
select throws_ok(
  $$ insert into ask_vai_cases (veterinarian_id, narrative_text)
     values ('11111111-1111-1111-1111-111111111111', 'post-activation case 4 (should fail)') $$,
  'P0001',
  'ask_vai_case_limit_exceeded',
  'A 4th post-activation Ask VAI case is rejected once enforcement is active'
);

-- ---------------------------------------------------------------------------
-- Ask VAI turn reservation: 2 succeed, 3rd fails; failed calls insert nothing.
-- ---------------------------------------------------------------------------
select is(
  reserve_ask_vai_turn((select id from ask_vai_cases where veterinarian_id = '11111111-1111-1111-1111-111111111111' and narrative_text = 'post-activation case 1')),
  1,
  'First reasoning-turn reservation for a case returns turn 1'
);
select is(
  reserve_ask_vai_turn((select id from ask_vai_cases where veterinarian_id = '11111111-1111-1111-1111-111111111111' and narrative_text = 'post-activation case 1')),
  2,
  'Second reservation for the same case returns turn 2'
);
select throws_ok(
  $$ select reserve_ask_vai_turn((select id from ask_vai_cases where narrative_text = 'post-activation case 1')) $$,
  'P0001',
  'ask_vai_turn_limit_exceeded',
  'A 3rd reasoning-turn reservation for the same case is rejected'
);

-- ---------------------------------------------------------------------------
-- Practice: abandonment loophole is closed — an UNENDED attempt still
-- consumes one of the 3 slots, and blocks starting another while active.
-- ---------------------------------------------------------------------------
insert into practice_scenarios (
  id, slug, title, patient, clinical_context, owner_profile,
  stated_concern, hidden_concern, feedback_reference_points
) values (
  'cccccccc-1111-0000-0000-000000000001', 'entitlement-test-scenario', 'Entitlement Test',
  '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, 'Cost', 'n/a', '[]'::jsonb
);

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('dddddddd-1111-0000-0000-000000000001', 'cccccccc-1111-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1);
-- Left UNENDED on purpose — this is the abandonment case.

select throws_ok(
  $$ insert into practice_attempts (scenario_id, veterinarian_id, attempt_number)
     values ('cccccccc-1111-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 2) $$,
  'P0001',
  'practice_active_session_exists',
  'A second Practice consultation cannot start while the first is still unended'
);

-- End it, then confirm the abandoned one still counted toward the 3-total.
update practice_attempts set ended_at = now() where id = 'dddddddd-1111-0000-0000-000000000001';

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('dddddddd-1111-0000-0000-000000000002', 'cccccccc-1111-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 2);
update practice_attempts set ended_at = now() where id = 'dddddddd-1111-0000-0000-000000000002';

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('dddddddd-1111-0000-0000-000000000003', 'cccccccc-1111-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 3);
update practice_attempts set ended_at = now() where id = 'dddddddd-1111-0000-0000-000000000003';

-- That is 3 total (including the abandoned one) — a 4th must now fail, even
-- though only 2 of the 3 were ever "completed" the old (loophole) way.
select throws_ok(
  $$ insert into practice_attempts (scenario_id, veterinarian_id, attempt_number)
     values ('cccccccc-1111-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 4) $$,
  'P0001',
  'practice_session_limit_exceeded',
  'A 4th Practice consultation is rejected — the abandoned session correctly consumed one of the 3 slots'
);

-- ---------------------------------------------------------------------------
-- Practice message reservation: 6 succeed, 7th fails.
--
-- Uses a DEDICATED vet and consultation, not Vet A's own attempts above.
-- Vet A's 3 consultations are all deliberately ended by the
-- abandonment-loophole test just above, and Vet A has no remaining
-- lifetime budget for a 4th (proven by the throws_ok immediately before
-- this block) — so this boundary test needs its own fixture with a
-- genuinely open consultation, independent of that narrative.
-- ---------------------------------------------------------------------------
-- auth.users is GoTrue-managed — service_role has no INSERT grant on it
-- either (only the pgTAP harness's own elevated default role does), so
-- fixture creation must happen under a reset role, not under service_role.
reset role;

insert into auth.users (id, email) values
  ('44444444-4444-4444-4444-444444444444', 'vet-message-limit@example.com');
insert into veterinarians (id, email, name) values
  ('44444444-4444-4444-4444-444444444444', 'vet-message-limit@example.com', 'Vet Message Limit');

-- Restore the service_role context the rest of this block needs —
-- practice_attempts INSERT (0002) and reserve_practice_message() EXECUTE
-- (0007) are both service_role-only, matching entitlements.ts's own use of
-- the secret client for this exact call in production.
set local role service_role;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('dddddddd-4444-0000-0000-000000000001', 'cccccccc-1111-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 1);
-- Left UNENDED on purpose — this attempt exists solely for the
-- message-reservation boundary check below.

do $$
declare v_attempt_id uuid := 'dddddddd-4444-0000-0000-000000000001';
declare v_n int;
begin
  for i in 1..6 loop
    v_n := reserve_practice_message(v_attempt_id);
    if v_n <> i then
      raise exception 'expected reservation number %, got %', i, v_n;
    end if;
  end loop;
end $$;

select throws_ok(
  $$ select reserve_practice_message('dddddddd-4444-0000-0000-000000000001'::uuid) $$,
  'P0001',
  'practice_message_limit_exceeded',
  'A 7th veterinarian-message reservation for the same consultation is rejected'
);

-- Reserving a message on an already-ended attempt is also rejected, on a
-- distinct error, independent of the message-count limit.
select throws_ok(
  $$ select reserve_practice_message('dddddddd-1111-0000-0000-000000000003'::uuid) $$,
  'P0003',
  'attempt_already_ended',
  'A message reservation on an ended consultation is rejected regardless of remaining allowance'
);

-- ---------------------------------------------------------------------------
-- UNLIMITED PLAN: this is the plan the two founder-controlled WSAVA demo
-- accounts will be manually assigned. With enforcement already active (it
-- was activated above), prove this account is genuinely exempt from every
-- pilot limit — going through the real triggers/RPCs, never bypassing them.
-- ---------------------------------------------------------------------------
-- Same reset-role requirement as the message-limit vet fixture above —
-- service_role has no INSERT grant on the GoTrue-managed auth.users table.
reset role;

insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'vet-unlimited@example.com');

insert into veterinarians (id, email, name, access_plan) values
  ('33333333-3333-3333-3333-333333333333', 'vet-unlimited@example.com', 'Vet Unlimited', 'unlimited');

-- Restore service_role for the ask_vai_cases / practice_attempts inserts
-- and reserve_ask_vai_turn() / reserve_practice_message() RPC calls below.
set local role service_role;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

select is(
  (select access_plan from veterinarians where id = '33333333-3333-3333-3333-333333333333'),
  'unlimited',
  'Test veterinarian is assigned the unlimited access_plan'
);

-- Ask VAI case limit (pilot cap: 3) — a 4th case must succeed.
insert into ask_vai_cases (veterinarian_id, narrative_text) values
  ('33333333-3333-3333-3333-333333333333', 'unlimited case 1'),
  ('33333333-3333-3333-3333-333333333333', 'unlimited case 2'),
  ('33333333-3333-3333-3333-333333333333', 'unlimited case 3'),
  ('33333333-3333-3333-3333-333333333333', 'unlimited case 4');

select is(
  (select count(*)::int from ask_vai_cases where veterinarian_id = '33333333-3333-3333-3333-333333333333'),
  4,
  'unlimited: a 4th Ask VAI case succeeds via trg_enforce_ask_vai_case_limit — exceeds the pilot 3-case limit'
);

-- Ask VAI turn-reservation limit (pilot cap: 2) — a 3rd reservation must
-- succeed, through the real reserve_ask_vai_turn() RPC.
select is(
  reserve_ask_vai_turn((select id from ask_vai_cases where veterinarian_id = '33333333-3333-3333-3333-333333333333' and narrative_text = 'unlimited case 1')),
  1,
  'unlimited: first reasoning-turn reservation returns turn 1'
);
select is(
  reserve_ask_vai_turn((select id from ask_vai_cases where veterinarian_id = '33333333-3333-3333-3333-333333333333' and narrative_text = 'unlimited case 1')),
  2,
  'unlimited: second reasoning-turn reservation returns turn 2'
);
select is(
  reserve_ask_vai_turn((select id from ask_vai_cases where veterinarian_id = '33333333-3333-3333-3333-333333333333' and narrative_text = 'unlimited case 1')),
  3,
  'unlimited: a 3rd reasoning-turn reservation succeeds via reserve_ask_vai_turn() — exceeds the pilot 2-turn limit'
);

-- One-active-Practice-session restriction (pilot cap: 1 concurrent) — two
-- simultaneously UNENDED consultations must both succeed, through the real
-- trg_enforce_practice_session_start trigger.
insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('eeeeeeee-3333-0000-0000-000000000001', 'cccccccc-1111-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 1);

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('eeeeeeee-3333-0000-0000-000000000002', 'cccccccc-1111-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 2);
-- Both left UNENDED on purpose.

select is(
  (select count(*)::int from practice_attempts where veterinarian_id = '33333333-3333-3333-3333-333333333333' and ended_at is null),
  2,
  'unlimited: 2 simultaneously active Practice consultations succeed — exceeds the pilot 1-active-session restriction'
);

-- Practice consultation (lifetime) limit (pilot cap: 3) — a 4th consultation
-- must succeed.
insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('eeeeeeee-3333-0000-0000-000000000003', 'cccccccc-1111-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 3);

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('eeeeeeee-3333-0000-0000-000000000004', 'cccccccc-1111-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 4);

select is(
  (select count(*)::int from practice_attempts where veterinarian_id = '33333333-3333-3333-3333-333333333333'),
  4,
  'unlimited: a 4th Practice consultation succeeds via trg_enforce_practice_session_start — exceeds the pilot 3-consultation limit'
);

-- Practice message-reservation limit (pilot cap: 6) — a 7th reservation on
-- one still-unended consultation must succeed, through the real
-- reserve_practice_message() RPC. Loop mirrors the existing 6-succeed check
-- above (lines ~162-172) for the pilot plan; a mismatch raises a plain
-- exception and aborts the run, exactly like that pattern.
do $$
declare v_attempt_id uuid := 'eeeeeeee-3333-0000-0000-000000000001';
declare v_n int;
begin
  for i in 1..7 loop
    v_n := reserve_practice_message(v_attempt_id);
    if v_n <> i then
      raise exception 'expected reservation number % for unlimited plan, got %', i, v_n;
    end if;
  end loop;
end $$;

select pass(
  'unlimited: a 7th Practice message reservation succeeds via reserve_practice_message() — exceeds the pilot 6-message limit'
);

-- Give Vet B some usage, distinct from Vet A's (3 cases / 3 consultations),
-- so the cross-user isolation checks below prove real per-caller scoping
-- rather than two accounts coincidentally reading the same numbers.
insert into ask_vai_cases (veterinarian_id, narrative_text) values
  ('22222222-2222-2222-2222-222222222222', 'vet b case 1');

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('ffffffff-2222-0000-0000-000000000001', 'cccccccc-1111-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 1);
update practice_attempts set ended_at = now() where id = 'ffffffff-2222-0000-0000-000000000001';

insert into practice_attempts (id, scenario_id, veterinarian_id, attempt_number)
values ('ffffffff-2222-0000-0000-000000000002', 'cccccccc-1111-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 2);
update practice_attempts set ended_at = now() where id = 'ffffffff-2222-0000-0000-000000000002';

-- ---------------------------------------------------------------------------
-- Grant / RLS boundary checks: `authenticated` can reach none of the raw
-- tables or the two reservation RPCs directly.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

select is(
  (select count(*)::int from access_plan_limits),
  0,
  'authenticated cannot read access_plan_limits directly (no RLS policy grants any rows)'
);

select throws_ok(
  $$ select reserve_ask_vai_turn('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501',
  null,
  'authenticated has no EXECUTE grant on reserve_ask_vai_turn'
);

select throws_ok(
  $$ select reserve_practice_message('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501',
  null,
  'authenticated has no EXECUTE grant on reserve_practice_message'
);

select throws_ok(
  $$ select activate_entitlement_enforcement() $$,
  '42501',
  null,
  'authenticated has no EXECUTE grant on activate_entitlement_enforcement'
);

select throws_ok(
  $$ select deactivate_entitlement_enforcement() $$,
  '42501',
  null,
  'authenticated has no EXECUTE grant on deactivate_entitlement_enforcement'
);

-- ---------------------------------------------------------------------------
-- anon: the fully unauthenticated role must be blocked from every
-- service_role-only RPC, and from get_my_access_summary() too — that
-- function reads a real account's usage numbers via auth.uid() and must
-- never be reachable without a session at all. Every assertion below must
-- fail at the privilege boundary (42501), never reach the function body —
-- an application-level error (case_not_found, attempt_not_found,
-- attempt_already_ended) would mean the call was actually executed, which
-- is exactly the defect this section exists to rule out.
-- ---------------------------------------------------------------------------
set local role anon;

select throws_ok(
  $$ select reserve_ask_vai_turn('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501',
  null,
  'anon has no EXECUTE grant on reserve_ask_vai_turn'
);

select throws_ok(
  $$ select reserve_practice_message('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501',
  null,
  'anon has no EXECUTE grant on reserve_practice_message'
);

select throws_ok(
  $$ select activate_entitlement_enforcement() $$,
  '42501',
  null,
  'anon has no EXECUTE grant on activate_entitlement_enforcement'
);

select throws_ok(
  $$ select deactivate_entitlement_enforcement() $$,
  '42501',
  null,
  'anon has no EXECUTE grant on deactivate_entitlement_enforcement'
);

select throws_ok(
  $$ select * from get_my_access_summary() $$,
  '42501',
  null,
  'anon has no EXECUTE grant on get_my_access_summary'
);

-- Restore authenticated as Vet A before continuing the existing boundary
-- and cross-user-isolation checks below.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

select * from get_my_access_summary();
select is(
  (select access_plan from get_my_access_summary()),
  'pilot',
  'get_my_access_summary() is callable by authenticated and returns the caller''s own plan'
);

-- ---------------------------------------------------------------------------
-- GET_MY_ACCESS_SUMMARY cross-user isolation: still authenticated as Vet A
-- (3 post-activation Ask VAI cases, 3 Practice consultations — see above).
-- ---------------------------------------------------------------------------
select is(
  (select ask_vai_cases_used from get_my_access_summary()),
  3,
  'get_my_access_summary() under Vet A returns Vet A''s own Ask VAI case count (3), not any other account''s'
);
select is(
  (select practice_sessions_used from get_my_access_summary()),
  3,
  'get_my_access_summary() under Vet A returns Vet A''s own Practice consultation count (3), not any other account''s'
);

-- No alternative invocation exists that lets Vet A request Vet B's summary:
-- get_my_access_summary() takes no parameters at all, so calling it with an
-- id argument fails at the "function does not exist" level, before any
-- policy or RLS check would even be reached.
select throws_ok(
  $$ select * from get_my_access_summary('22222222-2222-2222-2222-222222222222'::uuid) $$,
  '42883',
  null,
  'get_my_access_summary() accepts no parameters — there is no alternative invocation that can request another account''s summary'
);

-- Repeat under Vet B (1 Ask VAI case, 2 Practice consultations — seeded
-- above) to prove the isolation is symmetric, not a one-off coincidence of
-- Vet A's numbers.
select set_config('request.jwt.claims', json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text, true);

select is(
  (select access_plan from get_my_access_summary()),
  'pilot',
  'get_my_access_summary() under Vet B returns Vet B''s own plan'
);
select is(
  (select ask_vai_cases_used from get_my_access_summary()),
  1,
  'get_my_access_summary() under Vet B returns Vet B''s own Ask VAI case count (1), unaffected by Vet A''s usage'
);
select is(
  (select practice_sessions_used from get_my_access_summary()),
  2,
  'get_my_access_summary() under Vet B returns Vet B''s own Practice consultation count (2), unaffected by Vet A''s usage'
);

-- =============================================================================
-- RAW TABLE ACCESS BOUNDARY — exhaustive per-table, per-role, per-operation
-- coverage for every table 0007 introduces, plus a re-confirmation of
-- access_plan_limits. Closes the gap identified in the final pre-production
-- gate: 0007's header claims "no policies, no grants to authenticated/anon"
-- for these tables, but that had only been directly exercised for
-- access_plan_limits (SELECT, authenticated only). Every check below
-- verifies the ACTUAL effective boundary against a live query, not the
-- migration's prose.
--
-- SELECT is asserted via row count rather than throws_ok: whether the
-- underlying mechanism is "no SELECT grant at all" (query would throw
-- 42501) or "a table-level grant exists but RLS with zero policies hides
-- every row" (query succeeds, returns zero rows), the already-executed and
-- passing access_plan_limits/authenticated check earlier in this file
-- proves THIS project's actual behavior is the latter for an identically
-- configured table (RLS enabled, zero policies, no explicit grant) — so
-- that is the pattern used here too. If any of these instead abort with an
-- uncaught 42501 partway through the run, that itself is a meaningful,
-- reportable difference in privilege posture from access_plan_limits, not
-- a bug in this test file.
--
-- INSERT is asserted via throws_ok(..., '42501', ...): RLS's implicit
-- WITH CHECK (false, no policy) means a new row always fails the check, and
-- Postgres has no choice but to raise an error — there is no "insert zero
-- rows" outcome.
--
-- UPDATE/DELETE are asserted differently, and deliberately NOT via
-- throws_ok: RLS's implicit USING (false, no policy) filters the
-- candidate-row set to EMPTY before the write ever runs. Postgres then
-- executes the UPDATE/DELETE against that empty set and it completes
-- normally — zero rows affected, no exception. This is documented,
-- version-independent PostgreSQL row-security behavior, not a defect: an
-- earlier version of this section wrongly expected 42501 for UPDATE/DELETE
-- too, which produced 20 false failures against a live disposable database
-- — diagnosed, and corrected here to assert the actually-correct signal:
-- zero rows affected by an `UPDATE/DELETE ... RETURNING` CTE.
--
-- That CTE cannot live inside is()'s argument list directly — Postgres
-- requires "a WITH clause containing a data-modifying statement" to be at
-- the TOP LEVEL of its own query, not nested inside another statement's
-- subquery (this produced a second defect, caught on the very next run:
-- "WITH clause containing a data-modifying statement must be at the top
-- level"). Each check is therefore split into two top-level statements: a
-- DO block runs the data-modifying WITH as its own top-level query,
-- capturing the affected-row count into a transaction-local GUC (pgTAP
-- itself only registers a result from a top-level `select`, so the DO
-- block contributes no TAP line of its own); the following `select is(...)`
-- reads that GUC back and is the one statement pgTAP actually counts —
-- preserving exactly one assertion per check, same as before.
--
-- For entitlement_settings and access_plan_limits specifically — the two
-- tables where an actual mutation would be most consequential — the
-- adversarial statement targets a genuinely different value than the
-- current one (so a real change would be observable), and a follow-up
-- read-back via a privileged role confirms the real row is byte-for-byte
-- unchanged afterward, not merely that the write reported zero rows.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

-- ask_vai_turn_reservations
select is(
  (select count(*)::int from ask_vai_turn_reservations),
  0,
  'authenticated cannot read any row from ask_vai_turn_reservations'
);
select throws_ok(
  $$ insert into ask_vai_turn_reservations (case_id, turn_number) values ('00000000-0000-0000-0000-000000000000'::uuid, 1) $$,
  '42501', null,
  'authenticated cannot INSERT into ask_vai_turn_reservations'
);
do $$
declare v_count int;
begin
  with attempt as (
    update ask_vai_turn_reservations set status = 'completed' where true returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated UPDATE on ask_vai_turn_reservations affects zero rows (no RLS policy grants visibility)'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from ask_vai_turn_reservations returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated DELETE on ask_vai_turn_reservations affects zero rows (no RLS policy grants visibility)'
);

-- practice_message_reservations
select is(
  (select count(*)::int from practice_message_reservations),
  0,
  'authenticated cannot read any row from practice_message_reservations'
);
select throws_ok(
  $$ insert into practice_message_reservations (attempt_id, message_number) values ('00000000-0000-0000-0000-000000000000'::uuid, 1) $$,
  '42501', null,
  'authenticated cannot INSERT into practice_message_reservations'
);
do $$
declare v_count int;
begin
  with attempt as (
    update practice_message_reservations set status = 'completed' where true returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated UPDATE on practice_message_reservations affects zero rows (no RLS policy grants visibility)'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from practice_message_reservations returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated DELETE on practice_message_reservations affects zero rows (no RLS policy grants visibility)'
);

-- ai_usage_events
select is(
  (select count(*)::int from ai_usage_events),
  0,
  'authenticated cannot read any row from ai_usage_events'
);
select throws_ok(
  $$ insert into ai_usage_events (veterinarian_id, feature, model, input_tokens, output_tokens)
     values ('00000000-0000-0000-0000-000000000000'::uuid, 'ask_vai_extraction', 'test-model', 0, 0) $$,
  '42501', null,
  'authenticated cannot INSERT into ai_usage_events'
);
do $$
declare v_count int;
begin
  with attempt as (
    update ai_usage_events set model = 'tampered' where true returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated UPDATE on ai_usage_events affects zero rows (no RLS policy grants visibility)'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from ai_usage_events returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated DELETE on ai_usage_events affects zero rows (no RLS policy grants visibility)'
);

-- entitlement_settings — the global kill-switch itself. The adversarial
-- UPDATE targets false specifically because enforcement is already true at
-- this point in the suite (activated earlier) — attempting to flip it to
-- false is a genuinely consequential attack, not a same-value no-op.
select is(
  (select count(*)::int from entitlement_settings),
  0,
  'authenticated cannot read any row from entitlement_settings'
);
select throws_ok(
  $$ insert into entitlement_settings (id, enforcement_enabled) values (1, true) $$,
  '42501', null,
  'authenticated cannot INSERT into entitlement_settings'
);
do $$
declare v_count int;
begin
  with attempt as (
    update entitlement_settings set enforcement_enabled = false where id = 1 returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated UPDATE on entitlement_settings (attempting to disable enforcement) affects zero rows'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from entitlement_settings where id = 1 returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated DELETE on entitlement_settings affects zero rows'
);
-- Read back the REAL row via a privileged role to prove the attempted
-- UPDATE/DELETE above did not actually change anything, not merely that
-- each write reported zero affected rows.
reset role;
select is(
  (select enforcement_enabled from entitlement_settings where id = 1),
  true,
  'entitlement_settings.enforcement_enabled is still true after authenticated''s attempted UPDATE — enforcement was NOT disabled'
);
select is(
  (select count(*)::int from entitlement_settings where id = 1),
  1,
  'entitlement_settings row 1 still exists after authenticated''s attempted DELETE'
);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

-- access_plan_limits — SELECT/authenticated already proven earlier in this
-- file; re-confirming the write boundary here (a client rewriting its own
-- plan's limits would be a total bypass of every enforcement mechanism).
select throws_ok(
  $$ insert into access_plan_limits (access_plan, ask_vai_case_limit) values ('rogue_plan', 999) $$,
  '42501', null,
  'authenticated cannot INSERT into access_plan_limits'
);
do $$
declare v_count int;
begin
  with attempt as (
    update access_plan_limits set ask_vai_case_limit = 999999 where access_plan = 'pilot' returning access_plan
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated UPDATE on access_plan_limits (attempting to raise the pilot case limit) affects zero rows'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from access_plan_limits where access_plan = 'pilot' returning access_plan
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'authenticated DELETE on access_plan_limits (pilot row) affects zero rows'
);
reset role;
select is(
  (select ask_vai_case_limit from access_plan_limits where access_plan = 'pilot'),
  3,
  'access_plan_limits.pilot.ask_vai_case_limit is still 3 after authenticated''s attempted UPDATE — not raised to 999999'
);
select is(
  (select count(*)::int from access_plan_limits where access_plan = 'pilot'),
  1,
  'access_plan_limits pilot row still exists after authenticated''s attempted DELETE'
);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);

-- ---------------------------------------------------------------------------
-- Same full matrix, under anon — the fully unauthenticated role must be
-- blocked identically, with no exception.
-- ---------------------------------------------------------------------------
set local role anon;

select is(
  (select count(*)::int from ask_vai_turn_reservations),
  0,
  'anon cannot read any row from ask_vai_turn_reservations'
);
select throws_ok(
  $$ insert into ask_vai_turn_reservations (case_id, turn_number) values ('00000000-0000-0000-0000-000000000000'::uuid, 1) $$,
  '42501', null,
  'anon cannot INSERT into ask_vai_turn_reservations'
);
do $$
declare v_count int;
begin
  with attempt as (
    update ask_vai_turn_reservations set status = 'completed' where true returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon UPDATE on ask_vai_turn_reservations affects zero rows (no RLS policy grants visibility)'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from ask_vai_turn_reservations returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon DELETE on ask_vai_turn_reservations affects zero rows (no RLS policy grants visibility)'
);

select is(
  (select count(*)::int from practice_message_reservations),
  0,
  'anon cannot read any row from practice_message_reservations'
);
select throws_ok(
  $$ insert into practice_message_reservations (attempt_id, message_number) values ('00000000-0000-0000-0000-000000000000'::uuid, 1) $$,
  '42501', null,
  'anon cannot INSERT into practice_message_reservations'
);
do $$
declare v_count int;
begin
  with attempt as (
    update practice_message_reservations set status = 'completed' where true returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon UPDATE on practice_message_reservations affects zero rows (no RLS policy grants visibility)'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from practice_message_reservations returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon DELETE on practice_message_reservations affects zero rows (no RLS policy grants visibility)'
);

select is(
  (select count(*)::int from ai_usage_events),
  0,
  'anon cannot read any row from ai_usage_events'
);
select throws_ok(
  $$ insert into ai_usage_events (veterinarian_id, feature, model, input_tokens, output_tokens)
     values ('00000000-0000-0000-0000-000000000000'::uuid, 'ask_vai_extraction', 'test-model', 0, 0) $$,
  '42501', null,
  'anon cannot INSERT into ai_usage_events'
);
do $$
declare v_count int;
begin
  with attempt as (
    update ai_usage_events set model = 'tampered' where true returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon UPDATE on ai_usage_events affects zero rows (no RLS policy grants visibility)'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from ai_usage_events returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon DELETE on ai_usage_events affects zero rows (no RLS policy grants visibility)'
);

select is(
  (select count(*)::int from entitlement_settings),
  0,
  'anon cannot read any row from entitlement_settings'
);
select throws_ok(
  $$ insert into entitlement_settings (id, enforcement_enabled) values (1, true) $$,
  '42501', null,
  'anon cannot INSERT into entitlement_settings'
);
do $$
declare v_count int;
begin
  with attempt as (
    update entitlement_settings set enforcement_enabled = false where id = 1 returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon UPDATE on entitlement_settings (attempting to disable enforcement) affects zero rows'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from entitlement_settings where id = 1 returning id
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon DELETE on entitlement_settings affects zero rows'
);
reset role;
select is(
  (select enforcement_enabled from entitlement_settings where id = 1),
  true,
  'entitlement_settings.enforcement_enabled is still true after anon''s attempted UPDATE — enforcement was NOT disabled'
);
select is(
  (select count(*)::int from entitlement_settings where id = 1),
  1,
  'entitlement_settings row 1 still exists after anon''s attempted DELETE'
);
set local role anon;

select is(
  (select count(*)::int from access_plan_limits),
  0,
  'anon cannot read any row from access_plan_limits'
);
select throws_ok(
  $$ insert into access_plan_limits (access_plan, ask_vai_case_limit) values ('rogue_plan', 999) $$,
  '42501', null,
  'anon cannot INSERT into access_plan_limits'
);
do $$
declare v_count int;
begin
  with attempt as (
    update access_plan_limits set ask_vai_case_limit = 999999 where access_plan = 'pilot' returning access_plan
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon UPDATE on access_plan_limits (attempting to raise the pilot case limit) affects zero rows'
);
do $$
declare v_count int;
begin
  with attempt as (
    delete from access_plan_limits where access_plan = 'pilot' returning access_plan
  )
  select count(*) into v_count from attempt;
  perform set_config('pgtap.tmp_count', v_count::text, true);
end $$;
select is(
  current_setting('pgtap.tmp_count')::int,
  0,
  'anon DELETE on access_plan_limits (pilot row) affects zero rows'
);
reset role;
select is(
  (select ask_vai_case_limit from access_plan_limits where access_plan = 'pilot'),
  3,
  'access_plan_limits.pilot.ask_vai_case_limit is still 3 after anon''s attempted UPDATE — not raised to 999999'
);
select is(
  (select count(*)::int from access_plan_limits where access_plan = 'pilot'),
  1,
  'access_plan_limits pilot row still exists after anon''s attempted DELETE'
);

select * from finish();
rollback;
