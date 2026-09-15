-- Additive schema + privilege correction for the already-applied
-- `vai-production` database (0001/0002 are historical — this migration
-- never touches them).
--
-- SCHEMA: ask_vai_reasoning_outputs was written against the reasoning-output
-- shape as of 0001. `priority`/`escalation` were added to that shape
-- afterward (DEC-012) but the table was never updated to match. Verified
-- empty (0 rows) in vai-production on 2026-09-09 before writing this
-- migration, so both columns are added as `jsonb not null` with NO
-- default — a future insert that omits either field fails loudly (a NOT
-- NULL violation) instead of silently persisting an incomplete record.
-- `{}` was deliberately rejected: it is not a valid ClinicalPriority or
-- Escalation (both have required sub-fields, src/lib/ask-vai/types.ts), so
-- a default that "succeeds" would conceal exactly the application defect
-- this constraint exists to catch.
--
-- PRIVILEGE: reasoning-output content is entirely produced by trusted
-- server code (the Anthropic tool-call result), never user-supplied at
-- insert time. The existing `authenticated` INSERT grant let any holder of
-- a valid session token write arbitrary content into this table via a
-- direct Data API call — RLS's case-ownership join verifies WHICH rows are
-- reachable, never WHETHER the content is genuinely AI-generated. INSERT
-- moves to service_role exclusively; authenticated keeps SELECT.
-- service_role already holds INSERT here (0002) — only the revoke is new.

alter table ask_vai_reasoning_outputs
  add column priority jsonb not null,
  add column escalation jsonb not null;

revoke insert on ask_vai_reasoning_outputs from authenticated;
