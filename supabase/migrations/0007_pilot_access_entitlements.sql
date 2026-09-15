-- Pilot Access entitlements — Ask VAI / Practice usage caps ahead of WSAVA.
--
-- Does not alter 0001-0006 in any way. Purely additive: new columns (with
-- safe defaults), new tables, new functions/triggers. No existing row is
-- ever mutated or deleted by this migration.
--
-- ARCHITECTURE
-- ------------
-- `veterinarians.access_plan` is the ONLY product-entitlement concept this
-- migration introduces, and it is deliberately a foreign key into
-- `access_plan_limits.access_plan` rather than a CHECK-constrained enum:
-- adding a brand-new plan later (e.g. a real paid tier) is then a pure data
-- change (INSERT a row) with zero migration required. Changing the NUMBERS
-- for an EXISTING plan (e.g. raising WSAVA's limits) is likewise a pure
-- UPDATE, no code or schema change. This is intentionally separate from any
-- future admin/founder AUTHORIZATION concept — there is no admin table, no
-- is_admin flag, nothing here. A founder/demo/test account is simply one
-- whose access_plan happens to be 'unlimited', assigned by a manual
-- service_role UPDATE after this migration lands (see the deployment
-- runbook) — never embedded in migration history.
--
-- SAFE ACTIVATION
-- ---------------
-- Every enforcement point (two triggers, two reservation RPCs) checks
-- `entitlement_settings.enforcement_enabled` FIRST and is a complete no-op
-- when it is false (the default). This migration can land in production,
-- and the application code that calls the new RPCs can be deployed on top
-- of it, with ZERO behavioral change for any existing account, for as long
-- as enforcement stays disabled. Enforcement is switched on later, once
-- founder/demo/test accounts have been manually reassigned, via exactly one
-- function: activate_entitlement_enforcement() (see below) — this is the
-- only supported way to flip it, so there is never a window where
-- enforcement_enabled is true and enforcement_started_at is null.
--
-- GRANDFATHERING
-- --------------
-- Every count this migration enforces (Ask VAI cases, Practice
-- consultations, Ask VAI turn reservations, Practice message reservations)
-- filters on `created_at >= coalesce(enforcement_started_at, '-infinity')`.
-- Usage that happened before activation — all pre-pilot development and
-- testing activity — never counts against the new caps. The one exception
-- is the "at most one active Practice consultation" rule (see
-- enforce_practice_session_start below): that is a concurrency/shape
-- constraint on CURRENT state ("is a session open right now"), not a
-- lifetime usage count, so it is not date-filtered — an explicit,
-- documented choice, not an oversight.
--
-- ATOMICITY
-- ---------
-- Case/session CREATION (ask_vai_cases, practice_attempts inserts) is
-- guarded by BEFORE INSERT triggers, each taking pg_advisory_xact_lock on
-- the veterinarian_id before counting — no Anthropic call precedes either
-- insert, so a rejection here costs nothing. Turn/message CONSUMPTION
-- (Ask VAI reasoning turns, Practice vet messages) instead uses a
-- reservation taken via an explicit RPC (reserve_ask_vai_turn /
-- reserve_practice_message), called by the application BEFORE the
-- Anthropic call — advisory-locked on the case/attempt id — so parallel
-- requests cannot both reserve past the limit. A reservation is not
-- refunded if the Anthropic call subsequently fails (see the RPCs' own
-- comments) — cost-safety is prioritized over giving a failed request a
-- free retry.
--
-- ACCESS
-- ------
-- `access_plan_limits`, `entitlement_settings`, `ask_vai_turn_reservations`,
-- `practice_message_reservations`, and `ai_usage_events` all have RLS
-- enabled with NO policies granted to authenticated/anon — every one is
-- reachable only through a SECURITY DEFINER function (which bypasses RLS
-- under the function owner's privileges) or the service_role key. The
-- browser never becomes part of the enforcement boundary. The one
-- exception is get_my_access_summary(), a narrow, self-scoped read (derives
-- the caller from auth.uid() internally, takes no parameters) granted to
-- `authenticated` specifically so the UI can show "N remaining" without
-- ever seeing the raw limits table.

-- =============================================================================
-- ENFORCEMENT KILL-SWITCH / ACTIVATION TIMESTAMP
-- =============================================================================
create table entitlement_settings (
  id int primary key default 1 check (id = 1),
  enforcement_enabled boolean not null default false,
  enforcement_started_at timestamptz
);
insert into entitlement_settings (id, enforcement_enabled, enforcement_started_at)
values (1, false, null);
alter table entitlement_settings enable row level security;
-- No policies, no grants to authenticated/anon: readable only inside the
-- SECURITY DEFINER functions below, or directly via service_role.

-- =============================================================================
-- ACCESS PLANS — the plan registry AND its limits, in one table
-- =============================================================================
-- access_plan is this table's primary key (not a CHECK list elsewhere) so
-- veterinarians.access_plan can reference it — adding a new plan is then an
-- INSERT here, nothing else. NULL in any limit column means "unlimited" for
-- that dimension.
create table access_plan_limits (
  access_plan text primary key,
  ask_vai_case_limit int,               -- lifetime Ask VAI cases (since activation)
  ask_vai_turn_limit int,                -- reasoning/follow-up turns per case
  practice_session_limit int,            -- lifetime Practice consultations (since activation) — counts ALL attempts, started or not, not just completed
  practice_message_limit int,            -- veterinarian messages per consultation
  practice_max_active_sessions int,      -- concurrently unended consultations allowed
  updated_at timestamptz not null default now()
);
insert into access_plan_limits
  (access_plan, ask_vai_case_limit, ask_vai_turn_limit, practice_session_limit, practice_message_limit, practice_max_active_sessions)
values
  ('pilot',     3, 2, 3, 6, 1),
  ('wsava',     3, 2, 3, 6, 1),   -- same as pilot initially, per explicit instruction — raise later via UPDATE only
  ('unlimited', null, null, null, null, null);
alter table access_plan_limits enable row level security;
-- No policies, no grants to authenticated/anon — see file header.

alter table veterinarians
  add column access_plan text not null default 'pilot'
    references access_plan_limits(access_plan);
-- Deliberately no grant added for `authenticated` on this column (Postgres
-- grants are additive/opt-in — simply not granting UPDATE here means it
-- stays out of reach, the same pattern 0001 already uses for
-- membership_status/stripe_*). Only service_role (or a human via the SQL
-- editor) can ever change a veterinarian's plan.

-- =============================================================================
-- RESERVATION LEDGERS — atomic, pre-Anthropic-call consumption records
-- =============================================================================
-- Deliberately NOT reusing ask_vai_reasoning_outputs / practice_attempts.
-- transcript for this: both already have real, incompatible shape
-- constraints (ask_vai_reasoning_outputs' priority/escalation columns are
-- NOT NULL with no default, by design, per 0003; transcript is a jsonb
-- array of real conversation turns, not a slot for a "pending" placeholder
-- turn). These ledgers hold nothing but which turn/message NUMBER was
-- reserved, when, and its eventual outcome — never any clinical content —
-- so a reservation-table failure can never expose anything sensitive.
create table ask_vai_turn_reservations (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references ask_vai_cases(id) on delete cascade,
  turn_number int not null,
  status text not null default 'reserved' check (status in ('reserved', 'completed', 'failed')),
  reserved_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (case_id, turn_number)
);
alter table ask_vai_turn_reservations enable row level security;
-- No policies, no grants — reachable only via reserve_ask_vai_turn() and a
-- plain service_role status update after the Anthropic call resolves.

create table practice_message_reservations (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references practice_attempts(id) on delete cascade,
  message_number int not null,
  status text not null default 'reserved' check (status in ('reserved', 'completed', 'failed')),
  reserved_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (attempt_id, message_number)
);
alter table practice_message_reservations enable row level security;
-- Same access pattern as ask_vai_turn_reservations above.

-- =============================================================================
-- DURABLE AI COST TELEMETRY
-- =============================================================================
-- Operational metadata only, matching observability.ts's own existing
-- discipline (never logs the API key, prompt text, case narratives, or
-- Practice transcripts) — this table cannot contain clinical content
-- because it is never given any: only ids, model name, token counts,
-- estimated cost, latency, timestamp.
create table ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  veterinarian_id uuid not null references veterinarians(id) on delete cascade,
  feature text not null check (feature in ('ask_vai_extraction', 'ask_vai_reasoning', 'practice_persona', 'practice_feedback')),
  case_id uuid references ask_vai_cases(id) on delete set null,
  attempt_id uuid references practice_attempts(id) on delete set null,
  provider text not null default 'anthropic',
  model text not null,
  input_tokens int not null,
  output_tokens int not null,
  cache_creation_input_tokens int,
  cache_read_input_tokens int,
  estimated_cost_usd numeric(12, 6),
  latency_ms int,
  created_at timestamptz not null default now()
);
alter table ai_usage_events enable row level security;
-- No policies, no grants to authenticated/anon per explicit instruction:
-- reads AND writes are service_role-only for this phase. A future
-- customer-facing usage view is a separate, later design (its own narrow
-- RPC, mirroring get_my_access_summary's pattern) — not this table opened
-- up directly.
create index ai_usage_events_veterinarian_id_idx on ai_usage_events(veterinarian_id);
create index ai_usage_events_case_id_idx on ai_usage_events(case_id);
create index ai_usage_events_attempt_id_idx on ai_usage_events(attempt_id);

-- =============================================================================
-- ENFORCEMENT: Ask VAI case creation
-- =============================================================================
create or replace function public.enforce_ask_vai_case_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_enabled boolean;
  v_started_at timestamptz;
  v_plan text;
  v_limit int;
  v_count int;
begin
  select enforcement_enabled, enforcement_started_at
    into v_enabled, v_started_at
    from public.entitlement_settings where id = 1;

  if not v_enabled then
    return new;
  end if;

  -- Scoped to this user: no cross-user contention.
  perform pg_advisory_xact_lock(hashtext(new.veterinarian_id::text));

  select access_plan into v_plan from public.veterinarians where id = new.veterinarian_id;
  select ask_vai_case_limit into v_limit from public.access_plan_limits where access_plan = v_plan;

  if v_limit is not null then
    select count(*) into v_count
      from public.ask_vai_cases
      where veterinarian_id = new.veterinarian_id
        and created_at >= coalesce(v_started_at, '-infinity'::timestamptz);
    if v_count >= v_limit then
      raise exception 'ask_vai_case_limit_exceeded' using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;
-- Explicit on all three roles, not just public: Supabase's own project-level
-- default privileges separately grant EXECUTE on every new public-schema
-- function to anon, authenticated, and service_role at creation time — a
-- `revoke ... from public` alone does not touch those individually-granted
-- entries. No explicit grant needed for any role: trigger execution does not
-- require the DML-issuing role to have EXECUTE on the trigger function
-- itself; this revoke is defense-in-depth (a direct call would fail anyway,
-- since this function's return type is trigger-only).
revoke execute on function public.enforce_ask_vai_case_limit() from public, anon, authenticated;

create trigger trg_enforce_ask_vai_case_limit
  before insert on ask_vai_cases
  for each row execute function public.enforce_ask_vai_case_limit();

-- =============================================================================
-- ENFORCEMENT: Practice consultation creation
-- =============================================================================
-- Two independent checks, in order, each with its own distinct exception so
-- the application can tell them apart:
--   1. practice_max_active_sessions — is an unended consultation already
--      open right now? This is a concurrency/shape rule on CURRENT state,
--      deliberately NOT filtered by enforcement_started_at (see file header).
--   2. practice_session_limit — counts ALL attempts (active or ended) since
--      activation, not just completed ones. This is the fix for the
--      abandonment loophole: an abandoned, never-ended consultation still
--      consumes one of the 3 slots the moment it is created.
create or replace function public.enforce_practice_session_start()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_enabled boolean;
  v_started_at timestamptz;
  v_plan text;
  v_session_limit int;
  v_max_active int;
  v_active_count int;
  v_total_count int;
begin
  select enforcement_enabled, enforcement_started_at
    into v_enabled, v_started_at
    from public.entitlement_settings where id = 1;

  if not v_enabled then
    return new;
  end if;

  perform pg_advisory_xact_lock(hashtext(new.veterinarian_id::text));

  select access_plan into v_plan from public.veterinarians where id = new.veterinarian_id;
  select practice_session_limit, practice_max_active_sessions
    into v_session_limit, v_max_active
    from public.access_plan_limits where access_plan = v_plan;

  if v_max_active is not null then
    select count(*) into v_active_count
      from public.practice_attempts
      where veterinarian_id = new.veterinarian_id and ended_at is null;
    if v_active_count >= v_max_active then
      raise exception 'practice_active_session_exists' using errcode = 'P0001';
    end if;
  end if;

  if v_session_limit is not null then
    select count(*) into v_total_count
      from public.practice_attempts
      where veterinarian_id = new.veterinarian_id
        and created_at >= coalesce(v_started_at, '-infinity'::timestamptz);
    if v_total_count >= v_session_limit then
      raise exception 'practice_session_limit_exceeded' using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;
-- Same defense-in-depth rationale as enforce_ask_vai_case_limit() above.
revoke execute on function public.enforce_practice_session_start() from public, anon, authenticated;

create trigger trg_enforce_practice_session_start
  before insert on practice_attempts
  for each row execute function public.enforce_practice_session_start();

-- =============================================================================
-- RESERVATION RPCs — called by the application BEFORE the Anthropic call
-- =============================================================================
-- reserve_ask_vai_turn: atomically claims the next turn number for a case,
-- or raises if the plan's turn limit is already reached. The application
-- must call this BEFORE invoking generateReasoning() and must proceed to
-- call Anthropic only if this succeeds. The internal one-bounded-retry
-- already in reasoning.ts happens entirely AFTER this single reservation —
-- a provider-side retry never claims a second reservation, by construction
-- (the retry loop lives inside the caller's use of the one turn number this
-- function already returned). If the Anthropic call ultimately fails (both
-- attempts), the reservation is NOT released — see actions.ts, which marks
-- it 'failed' for observability only, never deletes or refunds it. This is
-- deliberate: refunding a failed reservation is exactly the lever an
-- attacker would use to manufacture unlimited attempts by forcing failures.
create or replace function public.reserve_ask_vai_turn(p_case_id uuid)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_enabled boolean;
  v_started_at timestamptz;
  v_veterinarian_id uuid;
  v_plan text;
  v_limit int;
  v_count int;
  v_next int;
begin
  select enforcement_enabled, enforcement_started_at
    into v_enabled, v_started_at
    from public.entitlement_settings where id = 1;

  select veterinarian_id into v_veterinarian_id from public.ask_vai_cases where id = p_case_id;
  if v_veterinarian_id is null then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  -- Scoped to this case: two follow-up clicks on the SAME case serialize;
  -- turns on different cases (even for the same user) never contend.
  perform pg_advisory_xact_lock(hashtext(p_case_id::text));

  select count(*) into v_count
    from public.ask_vai_turn_reservations
    where case_id = p_case_id
      and reserved_at >= coalesce(v_started_at, '-infinity'::timestamptz);
  v_next := v_count + 1;

  if v_enabled then
    select access_plan into v_plan from public.veterinarians where id = v_veterinarian_id;
    select ask_vai_turn_limit into v_limit from public.access_plan_limits where access_plan = v_plan;
    if v_limit is not null and v_count >= v_limit then
      raise exception 'ask_vai_turn_limit_exceeded' using errcode = 'P0001';
    end if;
  end if;

  insert into public.ask_vai_turn_reservations (case_id, turn_number) values (p_case_id, v_next);
  return v_next;
end;
$$;
-- Explicit on all three roles: Supabase's project-level default privileges
-- separately grant EXECUTE on every new public-schema function to anon and
-- authenticated (in addition to public) at creation time — `revoke ... from
-- public` alone leaves those two individually-granted entries in place.
-- Deliberately NOT granted to authenticated or anon: a client with EXECUTE
-- here could probe or exhaust another user's turn budget by guessing case
-- ids — the app always calls this via the secret client, after its own
-- session-scoped getCase() has already established ownership.
revoke execute on function public.reserve_ask_vai_turn(uuid) from public, anon, authenticated;
grant execute on function public.reserve_ask_vai_turn(uuid) to service_role;

-- reserve_practice_message: same pattern, scoped to a Practice attempt.
create or replace function public.reserve_practice_message(p_attempt_id uuid)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_enabled boolean;
  v_started_at timestamptz;
  v_veterinarian_id uuid;
  v_ended_at timestamptz;
  v_plan text;
  v_limit int;
  v_count int;
  v_next int;
begin
  select enforcement_enabled, enforcement_started_at
    into v_enabled, v_started_at
    from public.entitlement_settings where id = 1;

  select veterinarian_id, ended_at into v_veterinarian_id, v_ended_at
    from public.practice_attempts where id = p_attempt_id;
  if v_veterinarian_id is null then
    raise exception 'attempt_not_found' using errcode = 'P0002';
  end if;
  if v_ended_at is not null then
    raise exception 'attempt_already_ended' using errcode = 'P0003';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_attempt_id::text));

  select count(*) into v_count
    from public.practice_message_reservations
    where attempt_id = p_attempt_id
      and reserved_at >= coalesce(v_started_at, '-infinity'::timestamptz);
  v_next := v_count + 1;

  if v_enabled then
    select access_plan into v_plan from public.veterinarians where id = v_veterinarian_id;
    select practice_message_limit into v_limit from public.access_plan_limits where access_plan = v_plan;
    if v_limit is not null and v_count >= v_limit then
      raise exception 'practice_message_limit_exceeded' using errcode = 'P0001';
    end if;
  end if;

  insert into public.practice_message_reservations (attempt_id, message_number) values (p_attempt_id, v_next);
  return v_next;
end;
$$;
-- Same defense-in-depth rationale as reserve_ask_vai_turn(uuid) above.
revoke execute on function public.reserve_practice_message(uuid) from public, anon, authenticated;
grant execute on function public.reserve_practice_message(uuid) to service_role;

-- =============================================================================
-- SELF-SERVICE ALLOWANCE SUMMARY — the only entitlement data the browser
-- ever sees, and only its own
-- =============================================================================
create or replace function public.get_my_access_summary()
returns table (
  access_plan text,
  ask_vai_cases_used int,
  ask_vai_cases_limit int,
  practice_sessions_used int,
  practice_sessions_limit int,
  has_active_practice_session boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_started_at timestamptz;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select enforcement_started_at into v_started_at from public.entitlement_settings where id = 1;

  return query
  select
    v.access_plan,
    (select count(*)::int from public.ask_vai_cases c
       where c.veterinarian_id = v_uid
         and c.created_at >= coalesce(v_started_at, '-infinity'::timestamptz)),
    l.ask_vai_case_limit,
    (select count(*)::int from public.practice_attempts p
       where p.veterinarian_id = v_uid
         and p.created_at >= coalesce(v_started_at, '-infinity'::timestamptz)),
    l.practice_session_limit,
    exists (select 1 from public.practice_attempts p where p.veterinarian_id = v_uid and p.ended_at is null)
  from public.veterinarians v
  join public.access_plan_limits l on l.access_plan = v.access_plan
  where v.id = v_uid;
end;
$$;
-- Explicit on both public and anon: this function IS intended to be
-- callable by authenticated (its grant below is deliberate and unchanged),
-- but Supabase's project-level default privileges would otherwise leave it
-- separately, silently executable by anon too — anonymous, unauthenticated
-- callers must never reach this, since it reads a real (if scoped) account's
-- usage numbers via auth.uid().
revoke execute on function public.get_my_access_summary() from public, anon;
grant execute on function public.get_my_access_summary() to authenticated;

-- =============================================================================
-- ACTIVATION — the ONLY supported way to turn enforcement on
-- =============================================================================
-- Sets enforcement_enabled and enforcement_started_at in the SAME statement,
-- so there is structurally no interval where one is true and the other is
-- null. The `where enforcement_enabled = false` guard makes a second call
-- a no-op (does not reset an already-set start time). Never called from
-- application code — this is a deliberate, manual, one-time operation run
-- via the Supabase SQL editor (or an equivalent trusted service_role
-- script) once founder/demo/test accounts have been reassigned and
-- verified. See the deployment runbook.
create or replace function public.activate_entitlement_enforcement()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.entitlement_settings
    set enforcement_enabled = true,
        enforcement_started_at = now()
    where id = 1 and enforcement_enabled = false;
end;
$$;
-- Explicit on all three roles — this is the global enforcement kill-switch
-- itself; if Supabase's default per-function grant to authenticated/anon
-- were left unrevoked, any signed-in vet (or any anonymous caller) could
-- invoke this directly and turn enforcement on ahead of the deliberate,
-- manual, founder-controlled activation sequence.
revoke execute on function public.activate_entitlement_enforcement() from public, anon, authenticated;
grant execute on function public.activate_entitlement_enforcement() to service_role;

-- Companion, for symmetry and fast incident rollback (see deployment
-- runbook) — does NOT clear enforcement_started_at, so re-activating later
-- resumes counting from the ORIGINAL activation time, not a new one; the
-- grandfather cutoff never silently moves forward from a disable/re-enable
-- cycle.
create or replace function public.deactivate_entitlement_enforcement()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.entitlement_settings set enforcement_enabled = false where id = 1;
end;
$$;
-- Same rationale as activate_entitlement_enforcement() above — this is the
-- kill-switch's off position; leaving it reachable by authenticated/anon
-- would let any caller disable enforcement for every account.
revoke execute on function public.deactivate_entitlement_enforcement() from public, anon, authenticated;
grant execute on function public.deactivate_entitlement_enforcement() to service_role;
