# submit-lead

Server-side public enquiry endpoint. It validates an allow-listed payload, checks the honeypot and optional Turnstile token, hashes the short-lived rate-limit key, and calls `submit_lead_transaction` using the service role. Notification failure is logged after the transaction and never rolls back a saved enquiry.

Deploy only after `db/004_ecosystem.sql` succeeds. Then live-test before switching `submissionMode` in `assets/js/config.js` and before applying migration 005.
