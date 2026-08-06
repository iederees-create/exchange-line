# Security and privacy

## Boundaries

The public site collects only business contact details and pre-conversation requirements. It does not collect bank account numbers, IDs, bank statements, proof of bank account, proof of address, debit-order details or document contents.

Inbound requests use `consent_basis = inbound_request`. They are not marketing consent and must never be enrolled automatically. A future marketing opt-in must be separate, optional, unticked by default, and record exact wording, timestamp and evidence.

## Authentication and roles

Supabase passwordless email authenticates internal and customer users. The auth-user trigger creates the harmless `customer` role. Internal roles are manually assigned. The `/admin/` client checks the role, but database RLS—not the UI—enforces access.

Customer policies require `customer_cases.customer_user_id = auth.uid()`. Customer-readable tables exclude internal lead notes; checklist and installation internal notes must never be selected by customer-facing code.

## Public submission

The Edge Function accepts only documented fields, validates sizes and enums, verifies an optional Turnstile token, HMAC-hashes the transient rate-limit key, and calls a service-only transaction RPC. Raw IP addresses and detailed fingerprints are not retained. The API returns only a safe ID and customer summary.

Internal notification is transactional, never marketing, and happens after the database transaction. Notification failure must not lose the lead.

## URL handling

The portal renders formal-quote URLs only when they use HTTPS and match the configured Premitel/Xero host allow-list. `javascript:` and arbitrary hosts are never linked.

## Secrets

The Supabase anon key is public by design and is protected by RLS. Service-role, Resend, Turnstile and HMAC secrets belong only in Supabase Edge Function secrets. Scan every release for secret-like strings and inspect Git history before publishing.

## Remaining approvals

- Premitel approval of public/outreach wording and the formal quote handoff.
- Current approved porting-letter template.
- Confirmation of the WEBCALL bank abbreviation.
- Approved instructions and secure destination for sensitive onboarding documents.
- Approved support/service wording and any official URL hostnames beyond the initial allow-list.
