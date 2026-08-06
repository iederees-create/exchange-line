-- Exchange Line quote-to-install ecosystem.
-- Additive and safe before the new frontend/function is deployed.
-- IMPORTANT: this migration deliberately preserves the current anon leads INSERT policy.

create extension if not exists pgcrypto;

alter table public.leads add column if not exists assigned_to uuid;
alter table public.leads add column if not exists pipeline_stage text not null default 'new';
alter table public.leads add column if not exists priority text not null default 'normal';
alter table public.leads add column if not exists qualification_reason text;
alter table public.leads add column if not exists next_action text;
alter table public.leads add column if not exists follow_up_at timestamptz;
alter table public.leads add column if not exists first_response_at timestamptz;
alter table public.leads add column if not exists source_url text;
alter table public.leads add column if not exists utm_source text;
alter table public.leads add column if not exists utm_medium text;
alter table public.leads add column if not exists utm_campaign text;
alter table public.leads add column if not exists utm_content text;
alter table public.leads add column if not exists utm_term text;
alter table public.leads add column if not exists referral_code text;
alter table public.leads add column if not exists duplicate_of uuid references public.leads(id) on delete set null;
alter table public.leads add column if not exists privacy_notice_version text;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'customer' check (role in ('customer','sales','operations','admin')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.leads drop constraint if exists leads_assigned_to_fkey;
alter table public.leads add constraint leads_assigned_to_fkey foreign key (assigned_to) references public.profiles(id) on delete set null;

create table if not exists public.lead_requirements (
  id uuid primary key default gen_random_uuid(), lead_id uuid not null unique references public.leads(id) on delete cascade,
  staff_count int not null check (staff_count between 1 and 1000), location_count int not null check (location_count between 1 and 1000),
  current_setup text not null, business_status text not null, remote_required text not null, keep_number text not null,
  outcomes text[] not null default '{}', problem_description text not null, decision_timeline text not null,
  preferred_contact text not null, preferred_response_time text not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.lead_activities (
  id uuid primary key default gen_random_uuid(), lead_id uuid not null references public.leads(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null, activity_type text not null, summary text not null,
  customer_visible boolean not null default false, metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
create table if not exists public.sales_tasks (
  id uuid primary key default gen_random_uuid(), lead_id uuid references public.leads(id) on delete cascade,
  assigned_to uuid references public.profiles(id) on delete set null, title text not null, due_at timestamptz not null,
  status text not null default 'open' check (status in ('open','completed','cancelled')), priority text not null default 'normal',
  completed_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.quote_workflows (
  id uuid primary key default gen_random_uuid(), lead_id uuid not null unique references public.leads(id) on delete cascade,
  stage text not null default 'brief_ready' check (stage in ('brief_ready','submitted_to_premitel','formal_quote_ready','sent','accepted','declined','expired')),
  official_quote_reference text, official_quote_url text, next_step text, quote_ready_at timestamptz, sent_at timestamptz, accepted_at timestamptz,
  expires_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.customer_cases (
  id uuid primary key default gen_random_uuid(), lead_id uuid not null unique references public.leads(id) on delete cascade,
  customer_user_id uuid references auth.users(id) on delete set null, customer_email text not null, title text not null default 'Phone-system journey',
  stage text not null default 'formal_quote', next_step text, official_form_reference text, approved_secure_submission_url text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.onboarding_checklist_items (
  id uuid primary key default gen_random_uuid(), case_id uuid not null references public.customer_cases(id) on delete cascade,
  item_key text not null, label text not null, required_condition text, status text not null default 'required' check (status in ('required','received','under_review','accepted','not_required')),
  internal_note text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(case_id,item_key)
);
create table if not exists public.installations (
  id uuid primary key default gen_random_uuid(), case_id uuid not null unique references public.customer_cases(id) on delete cascade,
  stage text not null default 'not_started', scheduled_at timestamptz, completed_at timestamptz, porting_status text,
  high_level_summary text, internal_notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.support_requests (
  id uuid primary key default gen_random_uuid(), case_id uuid not null references public.customer_cases(id) on delete cascade,
  customer_user_id uuid not null references auth.users(id) on delete cascade, subject text not null, description text not null,
  status text not null default 'new' check (status in ('new','in_progress','waiting_customer','resolved','closed')),
  reference text, internal_notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.web_events (
  id bigint generated always as identity primary key, event_name text not null, source_path text,
  anonymous_session_hash text, lead_id uuid references public.leads(id) on delete set null, properties jsonb not null default '{}', created_at timestamptz not null default now()
);
create table if not exists public.submission_rate_limits (
  key_hash text primary key, window_started_at timestamptz not null, request_count int not null default 1, expires_at timestamptz not null
);

create index if not exists idx_leads_pipeline on public.leads(pipeline_stage,priority,follow_up_at);
create index if not exists idx_activities_lead on public.lead_activities(lead_id,created_at desc);
create index if not exists idx_tasks_due on public.sales_tasks(status,due_at);
create index if not exists idx_cases_user on public.customer_cases(customer_user_id);
create index if not exists idx_support_case on public.support_requests(case_id,created_at desc);

create or replace function public.handle_new_auth_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,display_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)),'customer') on conflict(id) do nothing; return new; end; $$;
drop trigger if exists on_auth_user_created_exchange_line on auth.users;
create trigger on_auth_user_created_exchange_line after insert on auth.users for each row execute function public.handle_new_auth_user();

create or replace function public.is_internal() returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role in('sales','operations','admin'));
$$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;

create or replace function public.submit_lead_transaction(p_payload jsonb, p_rate_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_lead public.leads; v_existing uuid; v_score int:=0; v_priority text:='normal'; v_reason text; v_due timestamptz; v_count int;
begin
  delete from public.submission_rate_limits where expires_at<now();
  insert into public.submission_rate_limits(key_hash,window_started_at,request_count,expires_at) values(p_rate_key,now(),1,now()+interval '1 hour')
  on conflict(key_hash) do update set request_count=public.submission_rate_limits.request_count+1 returning request_count into v_count;
  if coalesce(v_count,1)>8 then raise exception 'rate_limited' using errcode='P0001'; end if;
  select id into v_existing from public.leads where lower(email)=lower(p_payload->>'email') and lower(company_name)=lower(p_payload->>'company_name') and created_at>now()-interval '30 days' order by created_at desc limit 1;
  if (p_payload->>'staff_count')::int>=3 then v_score:=v_score+2; else v_reason:='1-2 users: manual low-fit review. '; end if;
  if p_payload->>'business_status'='trading' then v_score:=v_score+1; end if;
  if p_payload->>'decision_timeline' in('one_month','asap') then v_score:=v_score+1; end if;
  if jsonb_array_length(coalesce(p_payload->'outcomes','[]'))>=2 then v_score:=v_score+1; end if;
  v_score:=least(5,v_score); v_priority:=case when (p_payload->>'staff_count')::int<3 then 'low' when v_score>=4 then 'high' else 'normal' end;
  v_reason:=coalesce(v_reason,'')||'Score based on team size, trading status, timeline and number of stated outcomes.';
  v_due:=case when extract(isodow from now())=5 then date_trunc('day',now())+interval '3 days 10 hours' when extract(isodow from now())=6 then date_trunc('day',now())+interval '2 days 10 hours' when extract(isodow from now())=7 then date_trunc('day',now())+interval '1 day 10 hours' else now()+interval '1 day' end;
  insert into public.leads(company_name,contact_name,role_title,email,whatsapp,source,staff_count_est,current_provider,fit_reason,qualification_score,consent_basis,inbound_request_at,pipeline_stage,priority,qualification_reason,next_action,follow_up_at,source_url,utm_source,utm_medium,utm_campaign,utm_content,utm_term,referral_code,duplicate_of,notes)
  values(p_payload->>'company_name',p_payload->>'contact_name',p_payload->>'role',lower(p_payload->>'email'),nullif(p_payload->>'whatsapp',''),'landing_calculator',(p_payload->>'staff_count')::int,p_payload->>'current_setup',p_payload->>'problem_description',v_score,'inbound_request',now(),'new',v_priority,v_reason,'Respond through preferred contact method',v_due,p_payload->>'source_url',p_payload->>'utm_source',p_payload->>'utm_medium',p_payload->>'utm_campaign',p_payload->>'utm_content',p_payload->>'utm_term',p_payload->>'referral_code',v_existing,'Inbound request only; no marketing consent.') returning * into v_lead;
  update public.leads set privacy_notice_version=p_payload->>'privacy_version' where id=v_lead.id;
  insert into public.lead_requirements(lead_id,staff_count,location_count,current_setup,business_status,remote_required,keep_number,outcomes,problem_description,decision_timeline,preferred_contact,preferred_response_time)
  values(v_lead.id,(p_payload->>'staff_count')::int,(p_payload->>'location_count')::int,p_payload->>'current_setup',p_payload->>'business_status',p_payload->>'remote_required',p_payload->>'keep_number',array(select jsonb_array_elements_text(p_payload->'outcomes')),p_payload->>'problem_description',p_payload->>'decision_timeline',p_payload->>'preferred_contact',p_payload->>'preferred_response_time');
  insert into public.lead_activities(lead_id,activity_type,summary,metadata) values(v_lead.id,'inbound_request','Public phone-system health check submitted',jsonb_build_object('source_url',p_payload->>'source_url'));
  insert into public.sales_tasks(lead_id,title,due_at,priority) values(v_lead.id,'Respond to inbound phone-system enquiry',v_due,v_priority);
  return jsonb_build_object('submission_id',v_lead.id,'summary',jsonb_build_object('staff_count',p_payload->>'staff_count','location_count',p_payload->>'location_count','current_setup',p_payload->>'current_setup','outcomes',p_payload->'outcomes','problem_description',p_payload->>'problem_description'));
end; $$;
revoke all on function public.submit_lead_transaction(jsonb,text) from public,anon,authenticated;
grant execute on function public.submit_lead_transaction(jsonb,text) to service_role;

create or replace function public.create_customer_case_for_lead(p_lead_id uuid,p_customer_email text) returns uuid language plpgsql security definer set search_path=public as $$
declare v_case uuid; v_stage text;
begin if not public.is_internal() then raise exception 'forbidden'; end if; select stage into v_stage from public.quote_workflows where lead_id=p_lead_id; if v_stage not in('formal_quote_ready','sent','accepted') then raise exception 'formal_quote_required'; end if; insert into public.customer_cases(lead_id,customer_email,stage,next_step) values(p_lead_id,lower(p_customer_email),'formal_quote','Review the official formal quote') on conflict(lead_id) do update set customer_email=excluded.customer_email returning id into v_case; return v_case; end; $$;

create or replace function public.link_customer_case_user(p_case_id uuid,p_customer_user_id uuid) returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_internal() then raise exception 'forbidden'; end if;
  if not exists(select 1 from public.profiles where id=p_customer_user_id and role='customer') then raise exception 'customer_user_required'; end if;
  update public.customer_cases set customer_user_id=p_customer_user_id,updated_at=now() where id=p_case_id;
  if not found then raise exception 'case_not_found'; end if;
end; $$;

create or replace function public.record_lead_activity(p_lead_id uuid,p_activity_type text,p_summary text,p_customer_visible boolean default false) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if not public.is_internal() then raise exception 'forbidden'; end if;
  if p_activity_type not in ('note','email','whatsapp','conversation','status_change') or char_length(trim(p_summary)) not between 1 and 2000 then raise exception 'invalid_activity'; end if;
  insert into public.lead_activities(lead_id,actor_user_id,activity_type,summary,customer_visible) values(p_lead_id,auth.uid(),p_activity_type,trim(p_summary),p_customer_visible) returning id into v_id;
  update public.leads set first_response_at=coalesce(first_response_at,case when p_activity_type in('email','whatsapp','conversation') then now() else first_response_at end) where id=p_lead_id;
  return v_id;
end; $$;

create or replace function public.set_quote_workflow(p_lead_id uuid,p_stage text,p_reference text default null,p_url text default null,p_next_step text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if not public.is_internal() then raise exception 'forbidden'; end if;
  if p_stage not in ('brief_ready','submitted_to_premitel','formal_quote_ready','sent','accepted','declined','expired') then raise exception 'invalid_stage'; end if;
  if p_url is not null and p_url !~ '^https://' then raise exception 'https_required'; end if;
  insert into public.quote_workflows(lead_id,stage,official_quote_reference,official_quote_url,next_step,quote_ready_at,sent_at,accepted_at)
  values(p_lead_id,p_stage,nullif(trim(p_reference),''),nullif(trim(p_url),''),nullif(trim(p_next_step),''),case when p_stage='formal_quote_ready' then now() end,case when p_stage='sent' then now() end,case when p_stage='accepted' then now() end)
  on conflict(lead_id) do update set stage=excluded.stage,official_quote_reference=coalesce(excluded.official_quote_reference,public.quote_workflows.official_quote_reference),official_quote_url=coalesce(excluded.official_quote_url,public.quote_workflows.official_quote_url),next_step=coalesce(excluded.next_step,public.quote_workflows.next_step),quote_ready_at=coalesce(public.quote_workflows.quote_ready_at,excluded.quote_ready_at),sent_at=coalesce(public.quote_workflows.sent_at,excluded.sent_at),accepted_at=coalesce(public.quote_workflows.accepted_at,excluded.accepted_at),updated_at=now() returning id into v_id;
  update public.leads set pipeline_stage=case when p_stage='sent' then 'quote_sent' else p_stage end,updated_at=now() where id=p_lead_id;
  insert into public.lead_activities(lead_id,actor_user_id,activity_type,summary) values(p_lead_id,auth.uid(),'status_change','Quote workflow moved to '||replace(p_stage,'_',' '));
  return v_id;
end; $$;

alter table public.profiles enable row level security; alter table public.lead_requirements enable row level security; alter table public.lead_activities enable row level security; alter table public.sales_tasks enable row level security; alter table public.quote_workflows enable row level security; alter table public.customer_cases enable row level security; alter table public.onboarding_checklist_items enable row level security; alter table public.installations enable row level security; alter table public.support_requests enable row level security; alter table public.web_events enable row level security; alter table public.submission_rate_limits enable row level security;

create policy profiles_self_read on public.profiles for select to authenticated using(id=auth.uid() or public.is_internal());
create policy profiles_admin_manage on public.profiles for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy leads_internal_all on public.leads for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy requirements_internal_all on public.lead_requirements for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy requirements_customer_read on public.lead_requirements for select to authenticated using(exists(select 1 from public.customer_cases c where c.lead_id=lead_id and c.customer_user_id=auth.uid()));
create policy activities_internal_all on public.lead_activities for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy tasks_internal_all on public.sales_tasks for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy workflows_internal_all on public.quote_workflows for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy workflows_customer_read on public.quote_workflows for select to authenticated using(exists(select 1 from public.customer_cases c where c.lead_id=lead_id and c.customer_user_id=auth.uid()));
create policy cases_internal_all on public.customer_cases for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy cases_customer_read on public.customer_cases for select to authenticated using(customer_user_id=auth.uid());
create policy checklist_internal_all on public.onboarding_checklist_items for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy checklist_customer_read on public.onboarding_checklist_items for select to authenticated using(exists(select 1 from public.customer_cases c where c.id=case_id and c.customer_user_id=auth.uid()));
create policy installations_internal_all on public.installations for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy installations_customer_read on public.installations for select to authenticated using(exists(select 1 from public.customer_cases c where c.id=case_id and c.customer_user_id=auth.uid()));
create policy support_internal_all on public.support_requests for all to authenticated using(public.is_internal()) with check(public.is_internal());
create policy support_customer_read on public.support_requests for select to authenticated using(customer_user_id=auth.uid() and exists(select 1 from public.customer_cases c where c.id=case_id and c.customer_user_id=auth.uid()));
create policy support_customer_insert on public.support_requests for insert to authenticated with check(customer_user_id=auth.uid() and exists(select 1 from public.customer_cases c where c.id=case_id and c.customer_user_id=auth.uid()));
create policy web_events_internal_read on public.web_events for select to authenticated using(public.is_internal());

create or replace view public.admin_lead_overview with(security_invoker=true) as select id,created_at,company_name,contact_name,email,staff_count_est,pipeline_stage,priority,next_action,follow_up_at,qualification_score,qualification_reason,lost_reason from public.leads;
grant select on public.admin_lead_overview to authenticated;

comment on column public.onboarding_checklist_items.internal_note is 'Internal only. Record Premitel document-template observations here; never expose through customer queries.';
comment on table public.submission_rate_limits is 'Short-lived keyed rate limits. Store only an HMAC hash, never a raw IP address.';
