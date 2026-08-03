-- =====================================================================
-- Exchange Line — Lead & Outreach Schema
-- Target: Supabase (Postgres)
-- Covers: inbound leads (landing page calculator) + outbound leads
--         (scraped/sourced) + email sequence tracking + quotes
-- =====================================================================

create extension if not exists "uuid-ossp";

-- ---------------------------------------------------------------------
-- LEADS
-- One row per business/prospect, regardless of how they entered the
-- pipeline (inbound form vs sourced/scraped).
-- ---------------------------------------------------------------------
create table if not exists leads (
  id                uuid primary key default uuid_generate_v4(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  -- identity
  company_name      text not null,
  contact_name      text,
  role_title        text,               -- e.g. "Office Manager", "Ops Director"
  email             text,
  phone             text,
  whatsapp          text,

  -- sourcing
  source            text not null check (source in (
                       'landing_calculator', 'scraped_directory', 'scraped_maps',
                       'referral', 'linkedin', 'manual', 'other'
                     )),
  source_detail     text,               -- e.g. "CIPC registry batch 2026-08", specific search query
  territory         text,               -- must match Annexure A once defined

  -- qualification
  staff_count_est   int,
  current_provider  text,               -- e.g. "Telkom landline", "unknown", "Vox"
  fit_reason        text,               -- one-line "why this lead fits" note
  qualification_score int check (qualification_score between 0 and 5),

  -- pipeline status
  status            text not null default 'sourced' check (status in (
                       'sourced', 'enriched', 'emailed', 'opened', 'clicked',
                       'replied', 'quoted', 'contract_sent', 'signed',
                       'installed', 'lost', 'unsubscribed', 'bounced'
                     )),
  lost_reason       text,

  -- consent / compliance (POPIA)
  consent_basis     text default 'legitimate_interest_b2b', -- or 'opt_in'
  do_not_contact    boolean not null default false,

  notes             text
);

create index if not exists idx_leads_status on leads(status);
create index if not exists idx_leads_source on leads(source);
create index if not exists idx_leads_email on leads(email);

-- ---------------------------------------------------------------------
-- QUOTES
-- Every estimate generated (from the landing page calculator or manually)
-- ---------------------------------------------------------------------
create table if not exists quotes (
  id              uuid primary key default uuid_generate_v4(),
  created_at      timestamptz not null default now(),
  lead_id         uuid references leads(id) on delete cascade,

  staff_count     int not null,
  tier_code       text not null,          -- e.g. 'CBX-21'
  base_price      numeric(10,2) not null,
  addons          jsonb not null default '[]', -- ["avr","did","hgr"]
  addon_cost      numeric(10,2) not null default 0,
  total_estimate  numeric(10,2) not null,

  confirmed       boolean not null default false, -- true once Premitel/agent confirms real price
  confirmed_price numeric(10,2),
  confirmed_at    timestamptz
);

create index if not exists idx_quotes_lead on quotes(lead_id);

-- ---------------------------------------------------------------------
-- CAMPAIGNS
-- A named outreach batch, e.g. "Roodepoort SME sweep — Aug 2026"
-- ---------------------------------------------------------------------
create table if not exists campaigns (
  id              uuid primary key default uuid_generate_v4(),
  created_at      timestamptz not null default now(),
  name            text not null,
  territory       text,
  target_criteria text,          -- free text description of ICP used for sourcing
  status          text not null default 'draft' check (status in (
                     'draft', 'active', 'paused', 'complete'
                   ))
);

-- ---------------------------------------------------------------------
-- CAMPAIGN_LEADS
-- Many-to-many: a lead can be part of more than one campaign over time
-- ---------------------------------------------------------------------
create table if not exists campaign_leads (
  campaign_id     uuid references campaigns(id) on delete cascade,
  lead_id         uuid references leads(id) on delete cascade,
  added_at        timestamptz not null default now(),
  sequence_step   int not null default 0,   -- which touch of the 3-email sequence they're on
  primary key (campaign_id, lead_id)
);

-- ---------------------------------------------------------------------
-- EMAIL_EVENTS
-- Every send/open/click/reply/bounce/unsubscribe, keyed to Resend webhooks
-- ---------------------------------------------------------------------
create table if not exists email_events (
  id              uuid primary key default uuid_generate_v4(),
  created_at      timestamptz not null default now(),
  lead_id         uuid references leads(id) on delete cascade,
  campaign_id     uuid references campaigns(id) on delete set null,

  event_type      text not null check (event_type in (
                     'sent', 'delivered', 'opened', 'clicked',
                     'replied', 'bounced', 'complained', 'unsubscribed'
                   )),
  sequence_step   int,               -- 1, 2, or 3
  resend_message_id text,
  meta            jsonb default '{}'
);

create index if not exists idx_email_events_lead on email_events(lead_id);
create index if not exists idx_email_events_type on email_events(event_type);

-- ---------------------------------------------------------------------
-- Trigger: keep leads.updated_at current
-- ---------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_leads_updated_at on leads;
create trigger trg_leads_updated_at
before update on leads
for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- Trigger: auto-advance lead status on email events
-- (only moves status forward, never backward, except unsubscribe/bounce)
-- ---------------------------------------------------------------------
create or replace function advance_lead_status()
returns trigger as $$
declare
  rank_current int;
  rank_new int;
  status_ranks jsonb := '{
    "sourced":0,"enriched":1,"emailed":2,"opened":3,"clicked":4,
    "replied":5,"quoted":6,"contract_sent":7,"signed":8,"installed":9,
    "lost":-1,"unsubscribed":-1,"bounced":-1
  }';
  new_status text;
begin
  new_status := case new.event_type
    when 'sent' then 'emailed'
    when 'opened' then 'opened'
    when 'clicked' then 'clicked'
    when 'replied' then 'replied'
    when 'unsubscribed' then 'unsubscribed'
    when 'bounced' then 'bounced'
    else null
  end;

  if new_status is null then
    return new;
  end if;

  select (status_ranks->> (select status from leads where id = new.lead_id))::int into rank_current;
  select (status_ranks-> new_status)::int into rank_new;

  if new_status in ('unsubscribed','bounced') then
    update leads set status = new_status, do_not_contact = true where id = new.lead_id;
  elsif rank_new > coalesce(rank_current, -99) then
    update leads set status = new_status where id = new.lead_id;
  end if;

  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_advance_lead_status on email_events;
create trigger trg_advance_lead_status
after insert on email_events
for each row execute function advance_lead_status();

-- ---------------------------------------------------------------------
-- Simple pipeline view for a dashboard
-- ---------------------------------------------------------------------
create or replace view pipeline_summary as
select
  status,
  count(*) as lead_count,
  count(*) filter (where source = 'landing_calculator') as from_inbound,
  count(*) filter (where source != 'landing_calculator') as from_outreach
from leads
group by status
order by
  case status
    when 'sourced' then 0 when 'enriched' then 1 when 'emailed' then 2
    when 'opened' then 3 when 'clicked' then 4 when 'replied' then 5
    when 'quoted' then 6 when 'contract_sent' then 7 when 'signed' then 8
    when 'installed' then 9 else 10
  end;
