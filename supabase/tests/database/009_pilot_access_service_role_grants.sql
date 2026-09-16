-- pgTAP: service_role privilege correction (migration 0008) for the five
-- tables introduced by 0007_pilot_access_entitlements.sql.
--
-- Uses has_table_privilege() exclusively for the privilege matrix, not
-- destructive DML probes: an earlier version of this file attempted live
-- UPDATE/INSERT/DELETE statements and expected exceptions, but those
-- probes were confounded by real FK/CHECK constraints masking the actual
-- privilege signal (e.g. a DELETE that should have been denied on
-- privilege grounds instead succeeded far enough to hit an unrelated
-- foreign-key violation). has_table_privilege() is a pure, side-effect-
-- free catalog read — unaffected by data, constraints, transaction state,
-- or which role happens to be executing the query (it takes the target
-- role as an explicit argument), so it cannot be confounded the same way.
--
-- Scope: this file proves the service_role matrix ONLY — the actual
-- subject of 0008. It does not re-test anon/authenticated: 008 (as
-- corrected alongside this file) already exhaustively and correctly
-- proves anon/authenticated have no SELECT (via has_table_privilege) and
-- no INSERT/UPDATE/DELETE (via throws_ok on the live operation) on all
-- five tables — repeating that matrix here would be redundant, not
-- protective.
--
-- Run via `supabase test db` — not executed in this environment.

begin;
select plan(29);

-- ---------------------------------------------------------------------------
-- D/E. Enforcement is untouched by 0008 — checked first, before this file
-- activates it locally (rolled back with everything else) for section G.
-- ---------------------------------------------------------------------------
select is(
  (select enforcement_enabled from entitlement_settings where id = 1),
  false,
  '0008 does not change enforcement_enabled — still false'
);
select is(
  (select enforcement_started_at from entitlement_settings where id = 1),
  null,
  '0008 does not change enforcement_started_at — still null'
);

-- ---------------------------------------------------------------------------
-- F. unlimited plan remains NULL-limit based — 0008 is a pure privilege
-- migration and must not have touched access_plan_limits' data.
-- ---------------------------------------------------------------------------
select is((select ask_vai_case_limit from access_plan_limits where access_plan = 'unlimited'), null, 'unlimited.ask_vai_case_limit is still null after 0008');
select is((select ask_vai_turn_limit from access_plan_limits where access_plan = 'unlimited'), null, 'unlimited.ask_vai_turn_limit is still null after 0008');
select is((select practice_session_limit from access_plan_limits where access_plan = 'unlimited'), null, 'unlimited.practice_session_limit is still null after 0008');
select is((select practice_message_limit from access_plan_limits where access_plan = 'unlimited'), null, 'unlimited.practice_message_limit is still null after 0008');
select is((select practice_max_active_sessions from access_plan_limits where access_plan = 'unlimited'), null, 'unlimited.practice_max_active_sessions is still null after 0008');

-- ---------------------------------------------------------------------------
-- Complete service_role privilege matrix: all four privilege types,
-- individually, for all five tables — 20 assertions total. Values must
-- exactly match 0008's intended minimum (see that migration's own header).
-- ---------------------------------------------------------------------------
select is(has_table_privilege('service_role', 'public.entitlement_settings', 'SELECT'), true,  'service_role HAS SELECT on entitlement_settings');
select is(has_table_privilege('service_role', 'public.entitlement_settings', 'INSERT'), false, 'service_role has NO INSERT on entitlement_settings');
select is(has_table_privilege('service_role', 'public.entitlement_settings', 'UPDATE'), false, 'service_role has NO UPDATE on entitlement_settings');
select is(has_table_privilege('service_role', 'public.entitlement_settings', 'DELETE'), false, 'service_role has NO DELETE on entitlement_settings');

select is(has_table_privilege('service_role', 'public.access_plan_limits', 'SELECT'), true,  'service_role HAS SELECT on access_plan_limits');
select is(has_table_privilege('service_role', 'public.access_plan_limits', 'INSERT'), false, 'service_role has NO INSERT on access_plan_limits');
select is(has_table_privilege('service_role', 'public.access_plan_limits', 'UPDATE'), false, 'service_role has NO UPDATE on access_plan_limits');
select is(has_table_privilege('service_role', 'public.access_plan_limits', 'DELETE'), false, 'service_role has NO DELETE on access_plan_limits');

select is(has_table_privilege('service_role', 'public.ask_vai_turn_reservations', 'SELECT'), true,  'service_role HAS SELECT on ask_vai_turn_reservations');
select is(has_table_privilege('service_role', 'public.ask_vai_turn_reservations', 'INSERT'), false, 'service_role has NO INSERT on ask_vai_turn_reservations');
select is(has_table_privilege('service_role', 'public.ask_vai_turn_reservations', 'UPDATE'), true,  'service_role HAS UPDATE on ask_vai_turn_reservations');
select is(has_table_privilege('service_role', 'public.ask_vai_turn_reservations', 'DELETE'), false, 'service_role has NO DELETE on ask_vai_turn_reservations');

select is(has_table_privilege('service_role', 'public.practice_message_reservations', 'SELECT'), true,  'service_role HAS SELECT on practice_message_reservations');
select is(has_table_privilege('service_role', 'public.practice_message_reservations', 'INSERT'), false, 'service_role has NO INSERT on practice_message_reservations');
select is(has_table_privilege('service_role', 'public.practice_message_reservations', 'UPDATE'), true,  'service_role HAS UPDATE on practice_message_reservations');
select is(has_table_privilege('service_role', 'public.practice_message_reservations', 'DELETE'), false, 'service_role has NO DELETE on practice_message_reservations');

select is(has_table_privilege('service_role', 'public.ai_usage_events', 'SELECT'), true,  'service_role HAS SELECT on ai_usage_events');
select is(has_table_privilege('service_role', 'public.ai_usage_events', 'INSERT'), true,  'service_role HAS INSERT on ai_usage_events');
select is(has_table_privilege('service_role', 'public.ai_usage_events', 'UPDATE'), false, 'service_role has NO UPDATE on ai_usage_events');
select is(has_table_privilege('service_role', 'public.ai_usage_events', 'DELETE'), false, 'service_role has NO DELETE on ai_usage_events');

-- ---------------------------------------------------------------------------
-- G. existing entitlement/trigger behavior is unaffected by 0008 — light
-- touch (008 already proves this exhaustively): activate enforcement
-- locally (rolled back with the rest of this transaction, never persists)
-- and confirm the Ask VAI case-limit trigger still fires correctly with
-- the corrected grants in place.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('55555555-5555-5555-5555-555555555555', 'vet-0008-grants-test@example.com');
insert into veterinarians (id, email, name) values
  ('55555555-5555-5555-5555-555555555555', 'vet-0008-grants-test@example.com', 'Vet Grants Test');

select activate_entitlement_enforcement();

set local role service_role;
select set_config('request.jwt.claims', json_build_object('sub', '55555555-5555-5555-5555-555555555555')::text, true);

insert into ask_vai_cases (veterinarian_id, narrative_text) values
  ('55555555-5555-5555-5555-555555555555', 'post-activation case 1'),
  ('55555555-5555-5555-5555-555555555555', 'post-activation case 2'),
  ('55555555-5555-5555-5555-555555555555', 'post-activation case 3');

select is(
  (select count(*)::int from ask_vai_cases where veterinarian_id = '55555555-5555-5555-5555-555555555555'),
  3,
  'the Ask VAI case-limit trigger still counts correctly with the corrected service_role grants in place'
);
select throws_ok(
  $$ insert into ask_vai_cases (veterinarian_id, narrative_text)
     values ('55555555-5555-5555-5555-555555555555', 'post-activation case 4 (should fail)') $$,
  'P0001',
  'ask_vai_case_limit_exceeded',
  'the Ask VAI case-limit trigger still rejects the 4th case — unaffected by the 0008 privilege correction'
);

select * from finish();
rollback;
