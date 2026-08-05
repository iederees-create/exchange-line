-- Exchange Line - inbound consent tracking hardening
-- Safe, idempotent migration. No destructive table operations.

alter table public.leads add column if not exists consent_basis text;
alter table public.leads add column if not exists consent_recorded_at timestamptz;
alter table public.leads add column if not exists inbound_request_at timestamptz;
alter table public.leads add column if not exists privacy_notice_version text;
alter table public.leads alter column consent_basis set default 'legitimate_interest_b2b';

create or replace function public.mark_inbound_request()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.source = 'landing_calculator' and new.consent_basis = 'inbound_request' then
    new.inbound_request_at := coalesce(new.inbound_request_at, now());
  end if;
  return new;
end;
$$;

drop trigger if exists trg_mark_inbound_request on public.leads;
create trigger trg_mark_inbound_request
before insert on public.leads
for each row execute function public.mark_inbound_request();

drop policy if exists "anon can submit a lead" on public.leads;
drop policy if exists "anon can submit an inbound request" on public.leads;

create policy "anon can submit an inbound request"
  on public.leads for insert to anon
  with check (
    source = 'landing_calculator'
    and consent_basis = 'inbound_request'
    and do_not_contact = false
    and company_name is not null
    and char_length(trim(company_name)) > 0
    and email is not null
    and char_length(trim(email)) > 3
  );

comment on column public.leads.consent_basis is
  'Interaction basis. inbound_request allows a reply to this enquiry only; it is not marketing opt-in.';
comment on column public.leads.inbound_request_at is
  'When the visitor made the inbound request, if recorded by a trusted backend.';
comment on column public.leads.privacy_notice_version is
  'Version of the privacy wording shown when the request was submitted.';

-- Restrict browser inserts to the fields used by the inbound form. Pipeline,
-- suppression and marketing fields remain service-role-only.
revoke insert on table public.leads from anon;
grant insert (company_name, contact_name, email, whatsapp, staff_count_est,
  current_provider, source, consent_basis, fit_reason, notes)
on table public.leads to anon;
