-- VAI Veterinary — foundation schema, WSAVA scope.
--
-- Replaces `0001_professional_record_schema.sql` (deleted, never committed,
-- never applied to any real database — see supabase/README.md for the full
-- reconciliation record). That file was written against the superseded
-- VAI-Professional-Record-Architecture-v1.0.md ("Debrief", automatic
-- Specialist Response on every case). This migration is written against the
-- current governing documents:
--   VAI-Veterinary-MVP-Master-Blueprint-v1.0.md (Part 12, data model)
--   VAI-Veterinary-WSAVA-Screen-Specification-v1.0.md
--   VAI-Architecture-Decision-and-MVP-Execution-v1.0.md (Part C.2, minimum
--     Reasoning Memory capture, including vet_working_theory)
--
-- Scope: exactly what Implementation Action 1 approved — Account, Ask VAI,
-- Commercial Core (P0A), Practice, minimum Expert Opinion foundation (P0B).
-- Entries is deliberately NOT included here — see supabase/README.md for why
-- (a real discrepancy between the Blueprint and this action's explicit scope
-- list, flagged rather than silently resolved either way).
--
-- Not included, on purpose, per the Architecture Decision's own deferred
-- list: capability_profiles / Patterns (the old migration's derived layer —
-- a genuinely good governance pattern, service-role-write-only, noted here
-- for reuse once Patterns is actually built, not built now), concept
-- tagging, peer benchmarking, certification, PIMS integration, voice
-- persistence, enterprise architecture.
--
-- `leads` (pre-relationship marketing contact capture) is intentionally
-- untouched — different concern, unrelated to this product's data model.

create extension if not exists "pgcrypto";

-- =============================================================================
-- VETERINARIANS
-- =============================================================================
-- One row per authenticated veterinarian. id matches auth.users.id (Supabase
-- Auth). Renamed from the old migration's `professionals` — this project is
-- specifically for veterinarians, not a cross-profession platform; the old
-- generic name was a leftover from an earlier, broader framing.
--
-- Commercial-core fields (membership_status, stripe_*) live directly on this
-- row rather than a separate subscriptions table: at WSAVA scale, one vet has
-- one current subscription state, not a history of many — a separate table
-- would be complexity without a corresponding need. Revisit only if/when
-- real subscription-history tracking becomes a genuine requirement.

create table veterinarians (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  name text not null,
  country text,
  role text check (role in ('Veterinarian', 'Veterinary Nurse', 'Other')),
  years_qualified text,
  species_focus text,
  practice_type text check (practice_type in ('General Practice', 'Referral', 'Both', '')),
  membership_status text not null default 'trial'
    check (membership_status in ('trial', 'active', 'cancelled', 'expired')),
  stripe_customer_id text,
  stripe_subscription_id text,
  created_at timestamptz not null default now()
);

alter table veterinarians enable row level security;

create policy "veterinarians read own" on veterinarians
  for select using (auth.uid() = id);
create policy "veterinarians update own" on veterinarians
  for update using (auth.uid() = id);
create policy "veterinarians insert own" on veterinarians
  for insert with check (auth.uid() = id);

-- Phase 1 (Data API grants): "Automatically expose new tables" was
-- disabled when this project was created, so no default
-- SELECT/INSERT/UPDATE grants exist for `authenticated`/`anon` on any
-- table in this schema — RLS policies alone are not reachable without an
-- underlying SQL-level grant. Every grant in this file is derived from
-- the actual application code path (src/server/ask-vai/store.ts,
-- src/server/practice/store.ts, and the actions that call them), not
-- guessed. No DELETE is granted anywhere — no code path deletes a row
-- from any table here. No `anon` grant appears anywhere — every table in
-- this schema holds authenticated-only private clinical content.
grant select on veterinarians to authenticated;

-- INSERT is column-scoped for the same reason UPDATE is below: RLS's
-- `with check (auth.uid() = id)` on "veterinarians insert own" only
-- constrains which `id` a new row may use — it says nothing about the
-- other column values in that same INSERT statement. An unrestricted
-- table-level INSERT grant would let a newly authenticated user insert
-- their own profile row with membership_status='active' or a fabricated
-- stripe_customer_id/stripe_subscription_id in the same statement,
-- bypassing Stripe before the row even exists. Restricting INSERT to the
-- profile-only columns closes this: omitting membership_status/stripe_*/
-- created_at from an INSERT lets their column defaults apply normally
-- ('trial', null, null, now()) — the grant only blocks a client from
-- explicitly setting them, never blocks the insert itself.
revoke insert on veterinarians from authenticated;
grant insert (
  id,
  email,
  name,
  country,
  role,
  years_qualified,
  species_focus,
  practice_type
) on veterinarians to authenticated;

-- SECURITY: RLS policies control which ROWS are reachable, not which
-- COLUMNS can be changed within a reachable row. Without an explicit
-- column-level grant, "veterinarians update own" above would let any
-- authenticated vet set their OWN membership_status to 'active' directly,
-- bypassing Stripe entirely. Column-level GRANT/REVOKE closes this: the
-- authenticated role may only ever write profile fields, never the
-- commercial-state columns — those are service_role only (the future
-- Stripe-webhook handler). Flagged explicitly for Andrei's review, not a
-- silent assumption.
revoke update on veterinarians from authenticated;
grant update (name, country, role, years_qualified, species_focus, practice_type)
  on veterinarians to authenticated;
-- membership_status, stripe_customer_id, stripe_subscription_id remain
-- writable only by service_role (which bypasses RLS, not SQL-level
-- grants — see below).

-- service_role (trusted server-side code only — never exposed to a
-- browser client) needs its own explicit table-level grant now that
-- "Automatically expose new tables" is disabled: BYPASSRLS bypasses row
-- level security policies, not the underlying SQL GRANT system, so
-- service_role is just as unreachable as authenticated/anon without one.
-- Table-level (not column-scoped) is correct here — service_role is the
-- trusted role that provisions the profile row after Supabase Auth
-- signup and later applies Stripe webhook updates to membership_status/
-- stripe_customer_id/stripe_subscription_id; the column-scoping above
-- exists specifically to constrain the untrusted authenticated path, not
-- this one. No DELETE: no planned code path deletes a veterinarian row.
grant select, insert, update on veterinarians to service_role;

-- =============================================================================
-- ASK VAI — cases
-- =============================================================================
-- The case as the vet wrote/submitted it, plus their optional working theory
-- (Change 1/4, ChatGPT Differentiation Decision — approved 2026-08-24).
-- `outcome` is schema-only per Architecture Decision Part C.2 item 11: no UI,
-- no reminder, populated later if ever, protects the option at zero cost now.

create table ask_vai_cases (
  id uuid primary key default gen_random_uuid(),
  veterinarian_id uuid not null references veterinarians(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  narrative_text text not null,
  attachments jsonb not null default '[]'::jsonb,
  vet_working_theory text,
  extraction_summary jsonb,
  outcome text,
  status text not null default 'open'
    check (status in ('open', 'expert_requested', 'closed'))
);

alter table ask_vai_cases enable row level security;

create index ask_vai_cases_veterinarian_id_idx on ask_vai_cases(veterinarian_id);

create policy "ask_vai_cases read own" on ask_vai_cases
  for select using (auth.uid() = veterinarian_id);
create policy "ask_vai_cases insert own" on ask_vai_cases
  for insert with check (auth.uid() = veterinarian_id);
create policy "ask_vai_cases update own" on ask_vai_cases
  for update using (auth.uid() = veterinarian_id);

grant select, insert, update on ask_vai_cases to authenticated;

-- service_role needs the same three verbs for the same reasons as above:
-- server-side case creation/reads/status-and-summary updates. No DELETE:
-- no code path deletes a case.
grant select, insert, update on ask_vai_cases to service_role;

-- =============================================================================
-- ASK VAI — reasoning outputs
-- =============================================================================
-- A separate, typed table (not a jsonb blob on the case row, and not an
-- overwrite-in-place field) so that the single WSAVA-scoped follow-up turn is
-- a second LINKED record, never a destructive overwrite of the first — this
-- is the entirety of "reasoning transitions" required at WSAVA scale, per
-- Architecture Decision Part C.2 item 7. turn_number is 1 for the initial
-- reasoning, 2 for the one allowed follow-up.
--
-- confidence_level and uncertainty_flagged are stored as real structured
-- columns, not embedded only in rendered prose — the entire point of
-- Architecture Decision items 4 and 5.

create table ask_vai_reasoning_outputs (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references ask_vai_cases(id) on delete cascade,
  turn_number int not null default 1,
  understanding text not null,
  confidence_level text not null check (confidence_level in ('low', 'moderate', 'high')),
  uncertainty_flagged boolean not null default false,
  differentials jsonb not null default '[]'::jsonb,
  evidence jsonb not null default '[]'::jsonb,
  missing_info jsonb not null default '[]'::jsonb,
  next_considerations jsonb not null default '[]'::jsonb,
  citations jsonb not null default '[]'::jsonb,
  followup_message text,
  created_at timestamptz not null default now(),
  unique (case_id, turn_number)
);

alter table ask_vai_reasoning_outputs enable row level security;

create index ask_vai_reasoning_outputs_case_id_idx on ask_vai_reasoning_outputs(case_id);

create policy "ask_vai_reasoning_outputs read via case" on ask_vai_reasoning_outputs
  for select using (
    exists (
      select 1 from ask_vai_cases c
      where c.id = case_id and c.veterinarian_id = auth.uid()
    )
  );
create policy "ask_vai_reasoning_outputs insert via case" on ask_vai_reasoning_outputs
  for insert with check (
    exists (
      select 1 from ask_vai_cases c
      where c.id = case_id and c.veterinarian_id = auth.uid()
    )
  );

-- select + insert only, matching the two RLS policies above exactly — this
-- table has no UPDATE policy (turn 2 is a new linked row, never an
-- overwrite of turn 1, by explicit design) and must not get an UPDATE
-- grant it has no matching RLS policy for.
grant select, insert on ask_vai_reasoning_outputs to authenticated;

-- service_role: same select+insert only, same reason as the authenticated
-- grant above — turn 2 is a new linked row, never an UPDATE of turn 1.
grant select, insert on ask_vai_reasoning_outputs to service_role;

-- =============================================================================
-- EXPERT OPINION
-- =============================================================================
-- Deliberate, explicit request/response — NOT the old migration's automatic
-- specialist_responses-via-parent_entry_id pattern. That pattern violated the
-- frozen "private Entries != submitted cases" rule (every case_reflection got
-- an automatic linked response, no consent gate). This table requires an
-- explicit request row with consent captured before any specialist content
-- can exist against a case.
--
-- No `specialists` table: per the Blueprint, WSAVA does not build a
-- specialist marketplace. Specialist identity is inline text, populated
-- manually by a real person through a simple internal admin process (service
-- role), not a self-service specialist product. Easily normalized into a
-- real specialists table later if/when a real network exists — not built
-- ahead of that need.
--
-- Deliberately no UPDATE policy for authenticated users: once a vet submits
-- a request, they cannot edit specialist fields or the response — only the
-- service role (the internal admin process) can. This is enforced by the
-- absence of an update policy, not by application-layer discipline alone.

create table expert_opinion_requests (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references ask_vai_cases(id) on delete cascade,
  veterinarian_id uuid not null references veterinarians(id) on delete cascade,
  specialty text not null,
  question_text text not null,
  consent_given boolean not null default false,
  consent_given_at timestamptz,
  case_package jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'specialist_assigned', 'responded')),
  specialist_name text,
  specialist_credentials text,
  specialist_specialty text,
  response_text text,
  responded_at timestamptz,
  created_at timestamptz not null default now()
);

alter table expert_opinion_requests enable row level security;

create index expert_opinion_requests_case_id_idx on expert_opinion_requests(case_id);
create index expert_opinion_requests_veterinarian_id_idx on expert_opinion_requests(veterinarian_id);

create policy "expert_opinion_requests read own" on expert_opinion_requests
  for select using (auth.uid() = veterinarian_id);
create policy "expert_opinion_requests insert own" on expert_opinion_requests
  for insert with check (
    auth.uid() = veterinarian_id
    and exists (select 1 from ask_vai_cases c where c.id = case_id and c.veterinarian_id = auth.uid())
  );
-- No update policy for authenticated users — see note above.

-- No grant added: no UI or server action exercises this table yet
-- ("schema-only" per the Blueprint). Add the correct grant when Expert
-- Opinion is actually built, derived from that real code path — not now.

-- =============================================================================
-- PRACTICE — scenarios (global system content, not user-owned)
-- =============================================================================
-- IMPORTANT SECURITY DECISION, flagged for Andrei's review (not a silent
-- choice): this table holds the scenario's HIDDEN state (hidden_concern,
-- disclosure_rules, behavior_rules, never_reveal, feedback_reference_points)
-- alongside its public brief fields (patient, clinical_context,
-- stated_concern). If this table carried a client-readable SELECT policy,
-- any authenticated vet could query it directly via the Supabase client
-- library and read the owner's hidden concern before the session even
-- starts — breaking the entire simulation.
--
-- Resolution: NO select policy for authenticated users at all. This table is
-- readable only by the service role. All Practice reads — both the public
-- Brief (PRAC-02) and the full row the persona engine needs (PRAC-03) — must
-- go through a server-side API route, which decides what to expose. Postgres
-- RLS is row-level, not column-level; splitting "public" vs. "hidden"
-- columns via RLS alone isn't a clean option at this scale, so the API-route
-- boundary carries this responsibility instead. Flagged in the Andrei
-- package below as a real judgment call, not asserted as obviously correct.

create table practice_scenarios (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  patient jsonb not null,
  clinical_context jsonb not null,
  owner_profile jsonb not null,
  stated_concern text not null,
  hidden_concern text not null,
  disclosure_rules jsonb not null,
  behavior_rules jsonb not null,
  never_reveal jsonb not null default '[]'::jsonb,
  feedback_reference_points jsonb not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table practice_scenarios enable row level security;
-- No policies created. Service-role only, by omission, per the note above.

-- No grant added for `authenticated` or `anon`, on purpose. With
-- "Automatically expose new tables" disabled, this table has neither an
-- RLS policy NOR a SQL-level grant for either client-facing role — two
-- independent layers keeping hidden_concern/behavior_rules/never_reveal
-- unreachable by any client request, not just one.
--
-- service_role DOES need SELECT here — it is the only role that reads
-- this table at all, for both the public Brief (PRAC-02) and the full
-- persona-engine row (PRAC-03), from the server-side API route described
-- above. SELECT only: no service-role write path exists or is planned
-- this phase — scenario content is authored out-of-band, not through
-- the app itself.
grant select on practice_scenarios to service_role;

-- =============================================================================
-- PRACTICE — attempts
-- =============================================================================

create table practice_attempts (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references practice_scenarios(id),
  veterinarian_id uuid not null references veterinarians(id) on delete cascade,
  attempt_number int not null,
  transcript jsonb not null default '[]'::jsonb,
  final_trust_state jsonb,
  ending_type text check (ending_type in ('proceeds', 'declines', 'undecided', 'unaddressed_concern')),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  unique (scenario_id, veterinarian_id, attempt_number)
);

alter table practice_attempts enable row level security;

create index practice_attempts_veterinarian_id_idx on practice_attempts(veterinarian_id);

create policy "practice_attempts read own" on practice_attempts
  for select using (auth.uid() = veterinarian_id);
create policy "practice_attempts insert own" on practice_attempts
  for insert with check (auth.uid() = veterinarian_id);
create policy "practice_attempts update own" on practice_attempts
  for update using (auth.uid() = veterinarian_id);

grant select, insert, update on practice_attempts to authenticated;

-- service_role: same three verbs, same reasons — attempt creation and
-- in-progress updates (transcript/final_trust_state/ending_type/
-- ended_at) from server-side session logic. No DELETE: no code path
-- deletes an attempt.
grant select, insert, update on practice_attempts to service_role;

-- =============================================================================
-- PRACTICE — feedback
-- =============================================================================
-- quote_verification_status is the single most safety-critical field in this
-- entire schema — the deterministic, application-code record of whether each
-- quoted claim in the feedback text was actually found in the real
-- transcript. Never generated or verified by the LLM itself.

create table practice_feedback (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null unique references practice_attempts(id) on delete cascade,
  what_you_noticed text,
  moment_that_may_have_meant_more text,
  where_it_changed text,
  moment_worth_replaying text,
  curriculum_connection text,
  quote_verification_status jsonb not null default '[]'::jsonb,
  generated_at timestamptz not null default now()
);

alter table practice_feedback enable row level security;

create policy "practice_feedback read via attempt" on practice_feedback
  for select using (
    exists (
      select 1 from practice_attempts a
      where a.id = attempt_id and a.veterinarian_id = auth.uid()
    )
  );
create policy "practice_feedback insert via attempt" on practice_feedback
  for insert with check (
    exists (
      select 1 from practice_attempts a
      where a.id = attempt_id and a.veterinarian_id = auth.uid()
    )
  );

-- select + insert only — one feedback row per attempt (unique constraint
-- on attempt_id), never updated after generation; no UPDATE policy exists
-- for this table either.
grant select, insert on practice_feedback to authenticated;

-- service_role: same select+insert only — one feedback row generated per
-- attempt (unique constraint on attempt_id), never updated after
-- generation, for either role.
grant select, insert on practice_feedback to service_role;
