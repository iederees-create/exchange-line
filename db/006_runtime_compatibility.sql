-- Runtime compatibility for the ecosystem handoff schema already deployed.
-- Safe after 004. Does not remove the temporary anonymous lead INSERT policy.

create extension if not exists pgcrypto;

alter table public.leads add column if not exists referral_code text;
alter table public.leads add column if not exists duplicate_of uuid references public.leads(id) on delete set null;
alter table public.leads add column if not exists privacy_notice_version text;

create table if not exists public.submission_rate_limits (
  key_hash text primary key,
  window_started_at timestamptz not null,
  request_count integer not null default 1,
  expires_at timestamptz not null
);
alter table public.submission_rate_limits enable row level security;
revoke all on public.submission_rate_limits from anon, authenticated;

create or replace function public.submit_lead_transaction(p_payload jsonb, p_rate_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lead_id uuid;
  v_existing uuid;
  v_score integer := 0;
  v_priority text := 'normal';
  v_reason text := '';
  v_due timestamptz;
  v_count integer;
  v_staff integer := (p_payload->>'staff_count')::integer;
  v_locations integer := (p_payload->>'location_count')::integer;
  v_outcomes text[] := array(select jsonb_array_elements_text(coalesce(p_payload->'outcomes','[]'::jsonb)));
begin
  delete from public.submission_rate_limits where expires_at < now();
  insert into public.submission_rate_limits(key_hash,window_started_at,request_count,expires_at)
  values(p_rate_key,now(),1,now()+interval '1 hour')
  on conflict(key_hash) do update set request_count=public.submission_rate_limits.request_count+1
  returning request_count into v_count;
  if coalesce(v_count,1) > 8 then raise exception 'rate_limited' using errcode='P0001'; end if;

  select id into v_existing from public.leads
  where lower(email)=lower(p_payload->>'email')
    and lower(company_name)=lower(p_payload->>'company_name')
    and created_at > now()-interval '30 days'
  order by created_at desc limit 1;

  if v_staff >= 3 then v_score := v_score+2; else v_reason := '1-2 users: manual low-fit review. '; end if;
  if p_payload->>'business_status'='trading' then v_score := v_score+1; end if;
  if p_payload->>'decision_timeline' in ('one_month','asap') then v_score := v_score+1; end if;
  if cardinality(v_outcomes) >= 2 then v_score := v_score+1; end if;
  v_score := least(5,v_score);
  v_priority := case when v_staff < 3 then 'low' when v_score >= 4 then 'high' else 'normal' end;
  v_reason := v_reason || 'Score based on team size, trading status, timeline and stated outcomes.';
  v_due := case extract(isodow from now())
    when 5 then date_trunc('day',now())+interval '3 days 10 hours'
    when 6 then date_trunc('day',now())+interval '2 days 10 hours'
    when 7 then date_trunc('day',now())+interval '1 day 10 hours'
    else now()+interval '1 day' end;

  insert into public.leads(
    company_name,contact_name,role_title,email,whatsapp,source,staff_count_est,current_provider,
    fit_reason,qualification_score,consent_basis,consent_status,do_not_contact,status,priority,
    preferred_contact_method,preferred_contact_time,next_follow_up_at,source_url,
    utm_source,utm_medium,utm_campaign,utm_content,utm_term,referral_code,duplicate_of,
    privacy_notice_version,notes
  ) values (
    p_payload->>'company_name',p_payload->>'contact_name',p_payload->>'role',lower(p_payload->>'email'),
    nullif(p_payload->>'whatsapp',''),'landing_calculator',v_staff,p_payload->>'current_setup',
    p_payload->>'problem_description',v_score,'inbound_request','not_requested',false,'sourced',v_priority,
    p_payload->>'preferred_contact',p_payload->>'preferred_response_time',v_due,p_payload->>'source_url',
    p_payload->>'utm_source',p_payload->>'utm_medium',p_payload->>'utm_campaign',p_payload->>'utm_content',
    p_payload->>'utm_term',p_payload->>'referral_code',v_existing,p_payload->>'privacy_version',
    'Inbound request only; no marketing consent.'
  ) returning id into v_lead_id;

  insert into public.lead_requirements(
    lead_id,sites_count,business_status,current_setup,remote_staff_required,keep_existing_number,
    recording_required,decision_timeline,pain_points,problem_description,customer_summary,qualification_reason
  ) values (
    v_lead_id,v_locations,p_payload->>'business_status',p_payload->>'current_setup',
    case p_payload->>'remote_required' when 'yes' then true when 'no' then false else null end,
    case p_payload->>'keep_number' when 'yes' then true when 'no' then false else null end,
    'call_recording'=any(v_outcomes),p_payload->>'decision_timeline',v_outcomes,
    p_payload->>'problem_description',
    format('%s users across %s location(s); outcomes: %s',v_staff,v_locations,array_to_string(v_outcomes,', ')),
    v_reason
  );
  insert into public.lead_activities(lead_id,activity_type,summary,metadata)
  values(v_lead_id,'enquiry_received','Public phone-system health check submitted',jsonb_build_object('source_url',p_payload->>'source_url'));
  insert into public.sales_tasks(lead_id,title,due_at,status,notes)
  values(v_lead_id,'Respond to inbound phone-system enquiry',v_due,'open','Use the prospect preferred contact method. No marketing enrolment.');

  return jsonb_build_object(
    'submission_id',v_lead_id,
    'summary',jsonb_build_object(
      'staff_count',v_staff,'location_count',v_locations,'current_setup',p_payload->>'current_setup',
      'outcomes',p_payload->'outcomes','problem_description',p_payload->>'problem_description'
    )
  );
end;
$$;

revoke all on function public.submit_lead_transaction(jsonb,text) from public,anon,authenticated;
grant execute on function public.submit_lead_transaction(jsonb,text) to service_role;

create or replace view public.admin_lead_overview with (security_invoker=true) as
select id,created_at,company_name,contact_name,email,staff_count_est,
  status as pipeline_stage,priority,null::text as next_action,next_follow_up_at as follow_up_at,
  qualification_score,fit_reason as qualification_reason,lost_reason
from public.leads;
grant select on public.admin_lead_overview to authenticated;

comment on table public.submission_rate_limits is 'Short-lived HMAC-keyed rate limits. No raw IP address is stored.';
