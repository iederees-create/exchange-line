-- Run ONLY after submit-lead is deployed and a live service-role transaction test passes.
begin;
drop policy if exists "anon can submit a lead" on public.leads;
drop policy if exists "anon can submit an inbound request" on public.leads;
revoke insert on table public.leads from anon;
revoke insert on table public.quotes from anon;
drop policy if exists "anon can log a quote for a lead" on public.quotes;
commit;

-- Verification should return false/permission denied for anon direct inserts while
-- the submit-lead Edge Function continues to create lead + requirements + activity + task.
