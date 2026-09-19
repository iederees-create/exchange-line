# Deployment

## Public site

GitHub Pages serves `main` from the repository root at <https://iederees-create.github.io/exchange-line/>. Static assets contain only the Supabase URL, anon key, Edge Function URL, public Turnstile site key when enabled, and WhatsApp routing number. Never add server secrets.

## Migration order

Back up the Supabase database before any migration and verify the target project ref.

1. Existing `db/schema.sql`, `db/002_rls_policies.sql`, and `db/003_consent_tracking.sql` must already be applied.
2. Apply `db/004_ecosystem.sql`. It is additive and deliberately leaves the current anonymous lead insert available.
3. If the live project uses the earlier handoff column names (`profiles.user_id`, `onboarding_items`), apply `db/006_runtime_compatibility.sql`. This creates the service-only transaction RPC without removing the temporary anon policy.
4. Deploy and configure `submit-lead`.
5. Live-test the function and confirm one request creates a lead, requirement, activity and follow-up task.
6. Change `submissionMode` in `assets/js/config.js` from `legacy-direct` to `edge-function`, deploy GitHub Pages, and repeat the test.
7. Only then apply `db/005_disable_direct_anon_lead_insert.sql` and confirm direct anonymous inserts fail.

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

## Migration 009 — Shafeeqah portfolio (additive, separate from 005)

`db/009_shafeeqah_portfolio.sql` adds namespaced tables (`sf_site_admins`, `sf_enquiries`, `sf_enquiry_activities`, `sf_events`, `sf_submission_rate_limits`) and service-role RPCs for the Shafeeqah Francis portfolio. It does **not** change Exchange Line `leads` / `quotes`, does not replace migration 005, and must not be applied as if it were 005.

- Apply 009 only after a database backup. It is additive.
- Do not grant anon SELECT on `sf_enquiries` or other PII tables.
- Rate-limit keys live in `sf_submission_rate_limits`, not Exchange Line `submission_rate_limits`.
- Deploy `submit-shafeeqah-enquiry` and `record-shafeeqah-event` with `--no-verify-jwt` after 009. Origin is still required.
- These functions do not send email or WhatsApp.
- Do not deploy from this branch until Shafeeqah has signed off the code change. The Supabase CLI is not assumed to be logged in.

```sh
supabase functions deploy submit-shafeeqah-enquiry --no-verify-jwt
supabase functions deploy record-shafeeqah-event --no-verify-jwt
```

```sql
select relname, relrowsecurity from pg_class where relname in
('sf_site_admins','sf_enquiries','sf_enquiry_activities','sf_events','sf_submission_rate_limits');
```

## Rollback

For a frontend regression, revert the Git commit and push `main`. Before migration 005, the legacy form remains available. After migration 005, do not re-enable direct inserts casually; roll the frontend back to the last working Edge Function version. Database rollback should be restoration from the pre-migration backup or a reviewed forward migration—never destructive ad-hoc SQL.
