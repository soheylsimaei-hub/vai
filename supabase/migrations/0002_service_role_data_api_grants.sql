-- Additive fix for the already-applied `vai-production` database.
--
-- 0001 was written and run before we verified that `service_role`'s
-- BYPASSRLS attribute bypasses RLS policies only, not SQL-level GRANTs.
-- With "Automatically expose new tables" disabled on this project, that
-- meant `service_role` had zero privileges on every table in the schema —
-- confirmed live against `vai-production` (every probed table returned
-- Postgres error 42501 "permission denied", not 42P01 "relation does not
-- exist", i.e. the schema itself was intact, only privileges were
-- missing). 0001 itself has been corrected in place for any future fresh
-- database; this migration brings the existing, already-migrated
-- production database to that same corrected state without rerunning 0001.
--
-- Scope is intentionally identical to 0001's corrected service_role
-- grants, no more:
--   - No grant to `anon` — none was needed before, none is added now.
--   - No change to any existing `authenticated` grant, table- or
--     column-scoped.
--   - No grant on `expert_opinion_requests` — no UI or server action
--     exercises that table yet (verified against vai-app/src: only two
--     non-code references exist, a doc comment and UI copy, neither a
--     server code path), so per the "derive from the real code path, not
--     guessed" rule it gets nothing here either.
--   - No DELETE anywhere — no code path deletes a row from any table in
--     this schema.
--   - No sequence privileges — every primary key uses
--     `uuid default gen_random_uuid()`; the schema's two plain `int`
--     columns (`turn_number`, `attempt_number`) are ordinary
--     application-supplied values, not `serial`/`identity` columns, so no
--     sequence object exists to grant on.

grant select, insert, update on veterinarians to service_role;
grant select, insert, update on ask_vai_cases to service_role;
grant select, insert on ask_vai_reasoning_outputs to service_role;
grant select on practice_scenarios to service_role;
grant select, insert, update on practice_attempts to service_role;
grant select, insert on practice_feedback to service_role;
