-- Additive migration: structured personal-name fields for the veterinarian
-- profile-completion / onboarding step ("VAI Profile Onboarding + Personal
-- Greeting"). Does not alter 0001-0004 in any way.
--
-- `name` (0001) was never a real display name — ensureVeterinarianProfile
-- (vai-app/src/server/veterinarian-provisioning.ts) sets it to the user's
-- own email at signup, and no UI has ever let a vet edit it since. It is
-- therefore left completely untouched here (per explicit instruction: do
-- not fabricate a first/last-name split from an ambiguous existing string
-- — for every current row that string is literally an email address, so
-- any split would just be nonsense). `title`/`first_name`/`last_name` are
-- new, dedicated columns instead — the only architecturally honest way to
-- support "Welcome back, {title} {first_name}" without conflating a
-- freeform legacy label with structured identity, and without a NOT NULL
-- backfill that would have to guess at real names.
--
-- All three are nullable. Every existing row (including the real
-- production veterinarian account already in this table) gets NULL for
-- all three on this ALTER — the application layer treats a NULL/empty
-- first_name as "profile incomplete" and routes that vet through the new
-- onboarding step on their next sign-in. Nothing here writes to any
-- existing row.

alter table veterinarians
  add column title text check (title in ('Dr', 'Prof', 'Mr', 'Ms', 'Mrs') or title is null),
  add column first_name text,
  add column last_name text;

-- Column-level UPDATE grant, additive to the one already granted in 0001
-- (name, country, role, years_qualified, species_focus, practice_type) —
-- Postgres GRANTs accumulate; this does not replace, widen, or otherwise
-- touch that earlier grant statement. Deliberately UPDATE only, never
-- INSERT: the onboarding step always writes to a profile row that
-- ensureVeterinarianProfile already created during sign-in provisioning
-- (that INSERT still only ever supplies id/email/name, unchanged by this
-- migration), so the authenticated role never needs to INSERT these
-- columns — only UPDATE its own already-existing row. Same "derive the
-- grant from the actual code path, not guessed" discipline as 0001.
--
-- membership_status/stripe_customer_id/stripe_subscription_id are not
-- part of this grant and were never touched by it — a vet updating their
-- own title/first_name/last_name still cannot reach those columns in the
-- same statement, exactly as with every other profile field.
grant update (title, first_name, last_name) on veterinarians to authenticated;
