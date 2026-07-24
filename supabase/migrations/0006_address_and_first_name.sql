-- LeadFlow AI · Structured address + first_name
--
-- Two additions:
--   1. contacts.first_name  — Zoho and most CRMs want "First Name" as its
--                             own field (not a substring of full_name).
--                             App UI still shows full_name; this column
--                             is populated automatically on save.
--   2. companies.state + companies.postal_code — so a business-card address
--                             ("901, The Summit Business Bay, Off Andheri-
--                              Kurla Road, Andheri East, Mumbai - 400093,
--                              Maharashtra, India") lands as usable rows
--                             instead of one blob that's invisible in the app.
-- Safe to re-run.

alter table public.contacts
  add column if not exists first_name text;

alter table public.companies
  add column if not exists state text,
  add column if not exists postal_code text;

-- Backfill first_name from existing full_name so old leads survive the
-- schema change with a sensible default. Users can still edit later.
update public.contacts
set first_name = trim(split_part(full_name, ' ', 1))
where first_name is null
  and full_name is not null
  and trim(full_name) <> '';
