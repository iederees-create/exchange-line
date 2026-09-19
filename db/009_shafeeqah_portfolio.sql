-- Shafeeqah Francis portfolio enquiry/event tables.
-- Additive and namespaced. This is NOT a replacement for
-- db/005_disable_direct_anon_lead_insert.sql and must not be confused with it.
-- No FKs to leads/quotes. No automated email or WhatsApp. No destructive changes.

begin;

create table if not exists public.sf_site_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  site_id text not null default 'shafeeqah-portfolio' check (site_id = 'shafeeqah-portfolio'),
  created_at timestamptz not null default now()
);

create table if not exists public.sf_enquiries (
  id uuid primary key default gen_random_uuid(),
  site_id text not null default 'shafeeqah-portfolio' check (site_id = 'shafeeqah-portfolio'),
  path text not null check (path in ('project','employment')),
  service text,
  role text,
  description text not null,
  timing text not null,
  budget text,
  project_url text,
  contact_name text not null,
  email text not null,
  phone text,
  preferred_contact text not null,
  source_path text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term text,
  privacy_version text,
  idempotency_key text not null,
  duplicate_of uuid,
  is_synthetic boolean not null default false,
  created_at timestamptz not null default now(),
  unique (site_id, idempotency_key)
);

alter table public.sf_enquiries
  drop constraint if exists sf_enquiries_duplicate_of_fkey;
alter table public.sf_enquiries
  add constraint sf_enquiries_duplicate_of_fkey
  foreign key (duplicate_of) references public.sf_enquiries(id) on delete set null;

create table if not exists public.sf_enquiry_activities (
  id uuid primary key default gen_random_uuid(),
  enquiry_id uuid not null references public.sf_enquiries(id) on delete cascade,
  activity_type text not null,
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.sf_events (
  id bigint generated always as identity primary key,
  site_id text not null default 'shafeeqah-portfolio' check (site_id = 'shafeeqah-portfolio'),
  event_name text not null check (event_name in (
    'page_view','case_study_view','case_study_download','linkedin_click',
    'whatsapp_click','enquiry_start','enquiry_saved','affiliate_outbound'
  )),
  source_path text,
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Isolated from public.submission_rate_limits used by Exchange Line.
create table if not exists public.sf_submission_rate_limits (
  key_hash text primary key,
  window_started_at timestamptz not null,
  request_count int not null default 1,
  expires_at timestamptz not null
);

create index if not exists idx_sf_enquiries_email_created on public.sf_enquiries (lower(email), created_at desc);
create index if not exists idx_sf_enquiry_activities_enquiry on public.sf_enquiry_activities (enquiry_id, created_at desc);
create index if not exists idx_sf_events_name_created on public.sf_events (event_name, created_at desc);

create or replace function public.is_sf_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.sf_site_admins
    where user_id = auth.uid() and site_id = 'shafeeqah-portfolio'
  );
$$;

create or replace function public.submit_sf_enquiry_transaction(p_payload jsonb, p_rate_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enquiry public.sf_enquiries;
  v_existing uuid;
  v_count int;
  v_key text;
begin
  if coalesce(p_payload->>'site_id','shafeeqah-portfolio') <> 'shafeeqah-portfolio' then
    raise exception 'invalid_site' using errcode = 'P0001';
  end if;
  delete from public.sf_submission_rate_limits where expires_at < now();
  insert into public.sf_submission_rate_limits(key_hash, window_started_at, request_count, expires_at)
  values(p_rate_key, now(), 1, now() + interval '1 hour')
  on conflict(key_hash) do update
    set request_count = public.sf_submission_rate_limits.request_count + 1
  returning request_count into v_count;
  if coalesce(v_count, 1) > 8 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;

  v_key := nullif(trim(coalesce(p_payload->>'idempotency_key','')), '');
  if v_key is null then
    v_key := gen_random_uuid()::text;
  end if;

  select * into v_enquiry
  from public.sf_enquiries
  where site_id = 'shafeeqah-portfolio' and idempotency_key = v_key;
  if found then
    return jsonb_build_object(
      'submission_id', v_enquiry.id,
      'replay', true,
      'summary', jsonb_build_object('path', v_enquiry.path, 'timing', v_enquiry.timing)
    );
  end if;

  select id into v_existing
  from public.sf_enquiries
  where site_id = 'shafeeqah-portfolio'
    and lower(email) = lower(p_payload->>'email')
    and created_at > now() - interval '30 days'
  order by created_at desc
  limit 1;

  insert into public.sf_enquiries(
    site_id, path, service, role, description, timing, budget, project_url,
    contact_name, email, phone, preferred_contact, source_path,
    utm_source, utm_medium, utm_campaign, utm_content, utm_term,
    privacy_version, idempotency_key, duplicate_of, is_synthetic
  ) values (
    'shafeeqah-portfolio',
    p_payload->>'path',
    nullif(p_payload->>'service',''),
    nullif(p_payload->>'role',''),
    p_payload->>'description',
    p_payload->>'timing',
    nullif(p_payload->>'budget',''),
    nullif(p_payload->>'project_url',''),
    p_payload->>'contact_name',
    lower(p_payload->>'email'),
    nullif(p_payload->>'phone',''),
    p_payload->>'preferred_contact',
    nullif(p_payload->>'source_path',''),
    nullif(p_payload->>'utm_source',''),
    nullif(p_payload->>'utm_medium',''),
    nullif(p_payload->>'utm_campaign',''),
    nullif(p_payload->>'utm_content',''),
    nullif(p_payload->>'utm_term',''),
    p_payload->>'privacy_version',
    v_key,
    v_existing,
    coalesce((p_payload->>'is_synthetic')::boolean, false)
  ) returning * into v_enquiry;

  insert into public.sf_enquiry_activities(enquiry_id, activity_type, summary, metadata)
  values (
    v_enquiry.id,
    'inbound_request',
    'Public Shafeeqah portfolio enquiry submitted',
    jsonb_build_object('source_path', p_payload->>'source_path', 'path', p_payload->>'path')
  );

  return jsonb_build_object(
    'submission_id', v_enquiry.id,
    'replay', false,
    'summary', jsonb_build_object('path', v_enquiry.path, 'timing', v_enquiry.timing)
  );
end;
$$;

create or replace function public.record_sf_event_transaction(p_payload jsonb, p_rate_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
  v_count int;
  v_name text;
begin
  if coalesce(p_payload->>'site_id','shafeeqah-portfolio') <> 'shafeeqah-portfolio' then
    raise exception 'invalid_site' using errcode = 'P0001';
  end if;
  v_name := p_payload->>'event_name';
  if v_name not in (
    'page_view','case_study_view','case_study_download','linkedin_click',
    'whatsapp_click','enquiry_start','enquiry_saved','affiliate_outbound'
  ) then
    raise exception 'invalid_field' using errcode = 'P0001';
  end if;

  delete from public.sf_submission_rate_limits where expires_at < now();
  insert into public.sf_submission_rate_limits(key_hash, window_started_at, request_count, expires_at)
  values(p_rate_key, now(), 1, now() + interval '1 hour')
  on conflict(key_hash) do update
    set request_count = public.sf_submission_rate_limits.request_count + 1
  returning request_count into v_count;
  if coalesce(v_count, 1) > 60 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;

  insert into public.sf_events(site_id, event_name, source_path, properties)
  values (
    'shafeeqah-portfolio',
    v_name,
    nullif(p_payload->>'source_path',''),
    coalesce(p_payload->'properties', '{}'::jsonb)
  ) returning id into v_id;

  return jsonb_build_object('event_id', v_id);
end;
$$;

revoke all on function public.submit_sf_enquiry_transaction(jsonb, text) from public, anon, authenticated;
grant execute on function public.submit_sf_enquiry_transaction(jsonb, text) to service_role;
revoke all on function public.record_sf_event_transaction(jsonb, text) from public, anon, authenticated;
grant execute on function public.record_sf_event_transaction(jsonb, text) to service_role;
revoke all on function public.is_sf_site_admin() from public, anon;
grant execute on function public.is_sf_site_admin() to authenticated, service_role;

alter table public.sf_site_admins enable row level security;
alter table public.sf_enquiries enable row level security;
alter table public.sf_enquiry_activities enable row level security;
alter table public.sf_events enable row level security;
alter table public.sf_submission_rate_limits enable row level security;

drop policy if exists sf_site_admins_self_read on public.sf_site_admins;
create policy sf_site_admins_self_read on public.sf_site_admins
  for select to authenticated
  using (user_id = auth.uid() or public.is_sf_site_admin());

drop policy if exists sf_enquiries_admin_select on public.sf_enquiries;
create policy sf_enquiries_admin_select on public.sf_enquiries
  for select to authenticated
  using (public.is_sf_site_admin());

drop policy if exists sf_enquiry_activities_admin_select on public.sf_enquiry_activities;
create policy sf_enquiry_activities_admin_select on public.sf_enquiry_activities
  for select to authenticated
  using (public.is_sf_site_admin());

drop policy if exists sf_events_admin_select on public.sf_events;
create policy sf_events_admin_select on public.sf_events
  for select to authenticated
  using (public.is_sf_site_admin());

comment on table public.sf_enquiries is 'Shafeeqah portfolio enquiries. No anon SELECT. No FKs to Exchange Line leads/quotes.';
comment on table public.sf_events is 'Shafeeqah portfolio analytics events. No PII, UA, or raw IP.';
comment on table public.sf_submission_rate_limits is 'HMAC rate-limit keys for Shafeeqah functions only. Isolated from Exchange Line submission_rate_limits.';
comment on column public.sf_enquiries.duplicate_of is 'Prior enquiry with the same email within 30 days, if any.';

commit;
