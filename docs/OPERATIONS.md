# Operations and continuity

## Daily workflow

1. Review new and overdue enquiries in `/admin/`.
2. Respond through the prospect's preferred email or WhatsApp method. There is no cold-calling workflow.
3. Confirm requirements and record the interaction and next action.
4. Print the Louise Quote Brief only from confirmed information. Never guess a price or product configuration.
5. Move the workflow through brief ready, submitted to Premitel, formal quote ready, sent, accepted, declined or expired.
6. Create a customer case only after a real formal quote exists.
7. Invite the customer using Supabase passwordless email and link their `auth.uid()` to the case through authorised tooling.
8. Track onboarding metadata and status only; do not upload sensitive documents to this application.
9. After installation, track high-level milestones and customer support requests without unapproved service promises.

## Pipeline measures

The weekly report focuses on qualified conversations, quote briefs, formal quotes, acceptances, installations, response time and lost reasons. Raw lead count is context, not the main success measure.

One- and two-user enquiries receive a low priority and manual fit review; they are not rejected. Normal commercial fit begins at three users.

## Onboarding checklist

Track status only for these official documents; never reproduce or alter legal wording:

- accepted/signed official quote;
- customer application form;
- Cloud PBX terms and conditions;
- debit-order mandate;
- copies of directors' IDs;
- proof of bank account;
- proof of business/address;
- company resolution or authority to sign;
- porting letter of authority and current telephone bill when applicable;
- three months of bank statements and CIPC/company documents when credit is requested.

Premitel confirms the final list and provides secure submission instructions.

## Mandatory internal observations

- The supplied porting-letter template is old and says it authorises Sessions. Do not use it until Louise/Premitel provides or approves a current corrected template.
- The supplied debit-order form uses the bank abbreviation WEBCALL. Louise/Premitel must confirm it remains correct.
- The legal terms are four pages and contain initial fields. Do not alter wording or decide signing requirements without Premitel.

These belong in internal setup notes only, never customer-visible generated copy.

## Support

Record the issue, safe response, reference and status. Do not promise response times, service levels or technical capabilities without approved Premitel wording.

## Continuity if the original developer is unavailable

- GitHub repository `iederees-create/exchange-line` is the source of truth for static code and migrations.
- Supabase owns authentication, database, RLS and Edge Functions.
- Keep at least two authorised administrators with hardware-protected GitHub and Supabase accounts.
- Maintain encrypted records of who can access GitHub, Supabase, the transactional email provider and DNS; never store secrets in Git.
- Schedule Supabase backups and periodically verify a restore procedure.
- Export lead and pipeline data only through an authorised, restricted admin process; store exports encrypted and delete working copies when no longer needed.
- Record each deployment commit, applied migration, Edge Function version and Premitel approval in an operational change log.
- A replacement operator can follow `DEPLOYMENT.md`, verify RLS, inspect the dashboard, export the current pipeline, and continue the quote-to-install process without access to the original developer's machine.
