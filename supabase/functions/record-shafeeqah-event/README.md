# record-shafeeqah-event

Public Shafeeqah Francis portfolio analytics endpoint. It allow-lists event names, strips unknown properties, rejects PII keys, HMAC-hashes a short-lived rate-limit key (`sf-event:` prefix, stored in `sf_submission_rate_limits`), and calls `record_sf_event_transaction` with the service role.

Raw IP addresses and user-agent strings are not stored. The HMAC input is discarded after hashing.

Allowed events: `page_view`, `case_study_view`, `case_study_download`, `linkedin_click`, `whatsapp_click`, `enquiry_start`, `enquiry_saved`, `affiliate_outbound`.

Origin is required. Allowed origins are `https://shafeeqahfrancis-gif.github.io` and `https://iederees-create.github.io`.

```sh
supabase functions deploy record-shafeeqah-event --no-verify-jwt
```

`--no-verify-jwt` permits anonymous events. It does not expose the service role.
