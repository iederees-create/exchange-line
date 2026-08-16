-- =====================================================================
-- Exchange Line — Portal Auto-Link Update (Fixed)
-- Automatically links newly signed-up auth users to their existing quotes 
-- by joining the leads table (does not rely on customer_email column).
-- =====================================================================

-- 1. Update the authentication trigger for future sign-ups
create or replace function public.handle_new_auth_user() 
returns trigger 
language plpgsql 
security definer 
set search_path=public 
as $$
declare
  v_lead_id uuid;
begin 
  -- Default behavior: Create profile
  insert into public.profiles(id,display_name,role) 
  values(new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)), 'customer') 
  on conflict(id) do nothing; 

  -- Auto-link to an existing customer case if an admin already created one
  update public.customer_cases c
  set customer_user_id = new.id, updated_at = now()
  from public.leads l
  where c.lead_id = l.id and lower(l.email) = lower(new.email) and c.customer_user_id is null;

  -- If no customer case exists, but they previously submitted a quote request (lead),
  -- create a customer case automatically so they can see their portal!
  if not exists (select 1 from public.customer_cases where customer_user_id = new.id) then
    select id into v_lead_id from public.leads 
    where lower(email) = lower(new.email) 
    order by created_at desc limit 1;

    if v_lead_id is not null then
      insert into public.customer_cases(lead_id, stage, next_step, customer_user_id, title)
      values(
        v_lead_id, 
        'formal_quote', 
        'We are preparing your official quote based on your requirements.', 
        new.id,
        'Phone-system journey'
      )
      on conflict (lead_id) do update set customer_user_id = excluded.customer_user_id;
    end if;
  end if;

  return new; 
end; 
$$;

-- 2. Run a one-time backfill to fix all existing accounts that are stuck on "No linked case"
do $$
declare 
  r record;
  v_lead_id uuid;
begin
  for r in select id, email from auth.users loop
    -- Link existing cases
    update public.customer_cases c
    set customer_user_id = r.id, updated_at = now()
    from public.leads l
    where c.lead_id = l.id and lower(l.email) = lower(r.email) and c.customer_user_id is null;

    -- Create case if a lead exists but no case exists
    if not exists (select 1 from public.customer_cases where customer_user_id = r.id) then
      select id into v_lead_id from public.leads 
      where lower(email) = lower(r.email) 
      order by created_at desc limit 1;

      if v_lead_id is not null then
        insert into public.customer_cases(lead_id, stage, next_step, customer_user_id, title)
        values(
          v_lead_id, 
          'formal_quote', 
          'We are preparing your official quote based on your requirements.', 
          r.id,
          'Phone-system journey'
        )
        on conflict (lead_id) do update set customer_user_id = excluded.customer_user_id;
      end if;
    end if;
  end loop;
end;
$$;
