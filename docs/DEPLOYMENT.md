# Deployment

## Public site

GitHub Pages serves `main` from the repository root at <https://iederees-create.github.io/exchange-line/>. Static assets contain only the Supabase URL, anon key, Edge Function URL, public Turnstile site key when enabled, and WhatsApp routing number. Never add server secrets.

## Migration order

Back up the Supabase database before any migration and verify the target project ref.

1. Existing `db/schema.sql`, `db/002_rls_policies.sql`, and `db/003_consent_tracking.sql` must already be applied.
2. Apply `db/004_ecosystem.sql`. It is additive and deliberately leaves the current anonymous lead insert available.
3. Deploy and configure `submit-lead`.
4. Live-test the function and confirm one request creates a lead, requirement, activity and follow-up task.
5. Change `submissionMode` in `assets/js/config.js` from `legacy-direct` to `edge-function`, deploy GitHub Pages, and repeat the test.
6. Only then apply `db/005_disable_direct_anon_lead_insert.sql` and confirm direct anonymous inserts fail.

Migration 005 must not be run early: GitHub Pages has no server runtime and would otherwise lose enquiries.

## Edge Function environment variables

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (Edge Function only)
- `ALLOWED_ORIGINS=https://iederees-create.github.io`
- `ADMIN_NOTIFICATION_EMAIL=iedereesfrancis@gmail.com`
- `RESEND_API_KEY` (optional)
- `RESEND_FROM_EMAIL` (optional)
- `TURNSTILE_SECRET_KEY` (optional)
- `RATE_LIMIT_SECRET` (recommended independent HMAC secret)

Set `TURNSTILE_SITE_KEY` only as the public value in frontend configuration when Turnstile is enabled. Never expose the Turnstile secret.

## Supabase commands

```sh
supabase login
supabase link --project-ref sijvvbozaufzpjirijhb
supabase db push --include-all
supabase secrets set ALLOWED_ORIGINS=https://iederees-create.github.io ADMIN_NOTIFICATION_EMAIL=iedereesfrancis@gmail.com
supabase secrets set RESEND_API_KEY=... RESEND_FROM_EMAIL=... TURNSTILE_SECRET_KEY=... RATE_LIMIT_SECRET=...
supabase functions deploy submit-lead --no-verify-jwt
```

The public function uses strict origin validation, server validation and rate limiting; `--no-verify-jwt` permits anonymous enquiries and does not expose the service role.

## Auth settings

In Supabase Auth set:

- Site URL: `https://iederees-create.github.io/exchange-line/`
- Redirect allow-list:
  - `https://iederees-create.github.io/exchange-line/admin/`
  - `https://iederees-create.github.io/exchange-line/portal/`

Passwordless delivery must be tested with real internal and invited customer addresses before it is described as operational. New users default to `customer`; assign internal roles manually using trusted SQL/admin tooling.

```sql
update public.profiles set role='admin' where id=(select id from auth.users where email='authorised-admin@example.com');
```

## SQL verification

```sql
-- Every new application table has RLS enabled.
select relname, relrowsecurity from pg_class where relname in
('profiles','lead_requirements','lead_activities','sales_tasks','customer_cases','quote_workflows','onboarding_checklist_items','installations','support_requests','web_events','submission_rate_limits');

-- A transaction created all operational records.
select l.id, r.id requirement_id, a.id activity_id, t.id task_id
from leads l left join lead_requirements r on r.lead_id=l.id
left join lead_activities a on a.lead_id=l.id and a.activity_type='inbound_request'
left join sales_tasks t on t.lead_id=l.id and t.status='open'
where l.id='<safe test submission id>';

-- No inbound request became marketing consent.
select id, consent_basis from leads where source='landing_calculator' and consent_basis<>'inbound_request';

-- After 005, verify no anon INSERT policy exists.
select policyname,cmd,roles from pg_policies where schemaname='public' and tablename='leads';
```

Use an anon-key REST request after 005 and expect permission denied. Use the Edge Function and expect HTTP 201 plus only `submission_id` and `summary`.

## Rollback

For a frontend regression, revert the Git commit and push `main`. Before migration 005, the legacy form remains available. After migration 005, do not re-enable direct inserts casually; roll the frontend back to the last working Edge Function version. Database rollback should be restoration from the pre-migration backup or a reviewed forward migration—never destructive ad-hoc SQL.
