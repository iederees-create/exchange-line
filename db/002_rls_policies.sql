-- =====================================================================
-- Exchange Line — Row Level Security policies
-- Run this in the Supabase SQL editor AFTER schema.sql, before any real
-- traffic touches the landing page. schema.sql defines the tables but
-- never enables RLS, which means (as deployed) the public anon key can
-- currently SELECT every row in every table below — including lead PII
-- (name, email, phone) once real leads start coming in.
-- =====================================================================

alter table leads enable row level security;
alter table quotes enable row level security;
alter table campaigns enable row level security;
alter table campaign_leads enable row level security;
alter table email_events enable row level security;

-- ---------------------------------------------------------------------
-- leads: the public landing page may INSERT a new lead. Nothing else.
-- No anon SELECT/UPDATE/DELETE — reading or editing leads is a
-- service-role (backend/dashboard) operation only.
-- ---------------------------------------------------------------------
create policy "anon can submit a lead"
  on leads for insert
  to anon
  with check (
    source = 'landing_calculator'
    and do_not_contact = false
  );

-- ---------------------------------------------------------------------
-- quotes, campaigns, campaign_leads, email_events: internal pipeline
-- tables. No anon policies at all — RLS with zero policies means
-- default-deny for anon, so these become service-role-only by omission.
-- ---------------------------------------------------------------------
