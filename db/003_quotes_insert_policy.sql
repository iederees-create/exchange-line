-- =====================================================================
-- Exchange Line — allow anon INSERT on quotes
-- Run in the Supabase SQL editor after 002_rls_policies.sql.
--
-- 002 enabled RLS on quotes but defined no policies for it, so as
-- deployed, quotes is currently insert-locked even for the landing
-- page's own lead form. This adds an INSERT-only policy, same pattern
-- as leads: no anon SELECT/UPDATE/DELETE, so a quote can be logged but
-- never read back or altered by the public key.
-- =====================================================================

create policy "anon can log a quote for a lead"
  on quotes for insert
  to anon
  with check (
    lead_id is not null
    and staff_count > 0
    and total_estimate >= 0
  );
