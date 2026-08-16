-- =====================================================================
-- Exchange Line — Leads Auto-Link Trigger
-- Automatically creates a customer case and links it to an existing 
-- auth account if the user creates their portal account BEFORE 
-- submitting a quote request.
-- =====================================================================

create or replace function public.handle_new_lead_auto_link()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid;
begin
  -- Check if an auth user already exists for this lead's email
  select id into v_user_id from auth.users where lower(email) = lower(new.email) limit 1;

  -- If an account exists, instantly create their customer case so they see it in the portal
  if v_user_id is not null then
    insert into public.customer_cases(lead_id, status, public_next_step, customer_user_id, customer_message)
    values(
      new.id, 
      'formal_quote', 
      'We are preparing your official quote based on your requirements.', 
      v_user_id,
      'Phone-system journey'
    )
    on conflict (lead_id) do update set customer_user_id = excluded.customer_user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists on_new_lead_auto_link on public.leads;
create trigger on_new_lead_auto_link
  after insert on public.leads
  for each row execute function public.handle_new_lead_auto_link();

-- Run a one-time sweep just in case there are leads sitting there that belong to existing accounts!
do $$
declare
  l record;
  v_user_id uuid;
begin
  for l in select id, email from public.leads loop
    -- Find if there is an auth user for this lead
    select id into v_user_id from auth.users where lower(email) = lower(l.email) limit 1;
    
    if v_user_id is not null then
      -- Link it up if no case exists yet
      if not exists (select 1 from public.customer_cases where customer_user_id = v_user_id or lead_id = l.id) then
        insert into public.customer_cases(lead_id, status, public_next_step, customer_user_id, customer_message)
        values(
          l.id, 
          'formal_quote', 
          'We are preparing your official quote based on your requirements.', 
          v_user_id,
          'Phone-system journey'
        )
        on conflict (lead_id) do update set customer_user_id = excluded.customer_user_id;
      end if;
    end if;
  end loop;
end;
$$;
