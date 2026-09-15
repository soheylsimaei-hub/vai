-- Additive migration: extended professional-profile fields for the
-- Account page ("Account Profile Completion" pass). Does not alter
-- 0001-0005 in any way.
--
-- city/address/postal_code/organization_name are new, nullable text
-- columns — no NOT NULL, no backfill, no check constraints (free text,
-- consistent with the existing unconstrained free-text columns from 0001
-- such as `country`/`years_qualified`/`species_focus`). Every existing
-- row (including the real production veterinarian account) gets NULL for
-- all four on this ALTER; nothing here writes to any existing row.
--
-- `country` and `role` already exist (0001) and are deliberately not
-- re-declared here.

alter table veterinarians
  add column city text,
  add column address text,
  add column postal_code text,
  add column organization_name text;

-- Column-level UPDATE grant for exactly the four NEW columns above.
-- title/first_name/last_name (0005) and country/role (0001) are already
-- authenticated-updatable via those migrations' own grants — Postgres
-- GRANTs accumulate, so re-granting them here would be redundant, not
-- protective, and would obscure which migration actually changed what.
-- Together with those two existing grants, `authenticated` ends up with
-- UPDATE on exactly the nine professional-profile columns the Account
-- page edits: title, first_name, last_name, role, country, city, address,
-- postal_code, organization_name — nothing else. membership_status,
-- stripe_customer_id, stripe_subscription_id, id, email, and created_at
-- remain untouched by any authenticated-role grant, exactly as in 0001 —
-- this migration does not widen that boundary in any way.
grant update (city, address, postal_code, organization_name) on veterinarians to authenticated;
