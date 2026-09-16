-- Corrects a real production defect found during post-migration
-- verification of 0007_pilot_access_entitlements.sql: service_role has
-- BYPASSRLS, which bypasses row-level security policies only — it is NOT a
-- substitute for a table-level GRANT. Postgres checks table-level
-- privileges independently of RLS, and 0007 never issued an explicit GRANT
-- to service_role for any of its five new tables. Confirmed live against
-- vai-production immediately after 0007 was applied: every one of the five
-- tables returned `42501 permission denied` for service_role, with
-- Postgres's own hint naming the exact missing grant.
--
-- The RPCs (reserve_ask_vai_turn, reserve_practice_message,
-- activate_/deactivate_entitlement_enforcement, get_my_access_summary) were
-- confirmed UNAFFECTED by this — SECURITY DEFINER functions execute as
-- their owner, never as the calling role — so entitlement/quota
-- enforcement itself was never at risk. What was silently broken:
-- entitlements.ts's markAskVaiTurnReservation()/markPracticeMessageReservation()
-- (direct service_role UPDATE on the reservation tables' status column) and
-- observability.ts's persistAiUsageEvents() (direct service_role INSERT
-- into ai_usage_events) — both already wrapped in try/catch by design, so
-- no user-facing failure occurred, but reservation status never left
-- 'reserved' and AI usage telemetry was never recorded.
--
-- DETERMINISTIC BASELINE, NOT AN ASSUMED ONE: an earlier draft of this
-- migration only granted to service_role without first revoking anything
-- from it, on the assumption that a freshly created table starts with zero
-- privileges for every role. Local disposable-database testing (pgTAP)
-- showed service_role could already perform operations this migration
-- never granted (INSERT/UPDATE/DELETE beyond the intended minimum) — the
-- local environment evidently provides service_role some baseline table
-- privilege on these tables that production does not (the exact mechanism
-- was not asserted here without first confirming it against the live
-- database — see the accompanying verification report). Rather than rely
-- on any environment's ambient defaults being zero, this migration now
-- establishes the SAME deterministic baseline on every table, in every
-- environment: REVOKE ALL from every role that can hold table privileges
-- (public, anon, authenticated, service_role), then GRANT service_role
-- back exactly the minimum the application actually uses. This is
-- unconditionally correct regardless of what any given database's default
-- privileges happen to be.
--
-- MINIMUM PRIVILEGES — traced directly against the actual application code
-- at vai-app commit 60da4c0e93f944bc8dee09dd0de5c3936de3b7b2 (the only
-- direct-table operations anywhere in the codebase against these five
-- tables):
--
--   - ask_vai_turn_reservations / practice_message_reservations: the only
--     direct-table operation is `.update({status, resolved_at}).eq(...)`
--     — an UPDATE with a WHERE clause. Postgres requires SELECT on any
--     column referenced in a WHERE clause IN ADDITION to UPDATE on the
--     columns being set. No direct INSERT (creation is via the reservation
--     RPCs, SECURITY DEFINER) and no direct DELETE (no code path ever
--     deletes a reservation row).
--
--   - ai_usage_events: the only direct-table operation is a plain INSERT
--     (persistAiUsageEvents). SELECT is granted too, deliberately beyond
--     current app code: this table's entire purpose (0007's own header:
--     "durable AI cost telemetry") is later reporting, and an INSERT-only
--     grant would make the data permanently unreadable by anyone —
--     including a trusted server-side script using this same key. No
--     UPDATE/DELETE: nothing ever modifies or removes a usage event.
--
--   - entitlement_settings / access_plan_limits: no current application
--     code path touches either directly (both are read only via
--     get_my_access_summary, a SECURITY DEFINER function, unaffected by
--     this gap). SELECT is granted for legitimate operational/admin
--     verification — reading the kill-switch state and configured plan
--     limits directly is a real, already-demonstrated operational need.
--     No write grant: the "activate_entitlement_enforcement() is the ONLY
--     supported way to turn enforcement on" guarantee from 0007 would be
--     undermined by a parallel direct-UPDATE path.
--
-- No DELETE is granted anywhere: no application code path deletes from any
-- of these five tables. No INSERT on either reservation table or on
-- entitlement_settings/access_plan_limits: those write paths must stay
-- exclusively RPC-mediated.
--
-- Purely additive: no table/column change, no data mutation, no
-- access_plan change, no enforcement activation, no timestamp change, no
-- modification to 0007 or any earlier migration.

revoke all on public.entitlement_settings from public, anon, authenticated, service_role;
grant select on public.entitlement_settings to service_role;

revoke all on public.access_plan_limits from public, anon, authenticated, service_role;
grant select on public.access_plan_limits to service_role;

revoke all on public.ask_vai_turn_reservations from public, anon, authenticated, service_role;
grant select, update on public.ask_vai_turn_reservations to service_role;

revoke all on public.practice_message_reservations from public, anon, authenticated, service_role;
grant select, update on public.practice_message_reservations to service_role;

revoke all on public.ai_usage_events from public, anon, authenticated, service_role;
grant select, insert on public.ai_usage_events to service_role;
