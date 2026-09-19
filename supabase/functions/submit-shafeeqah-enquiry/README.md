# submit-shafeeqah-enquiry

Public Shafeeqah Francis portfolio enquiry endpoint. It validates an allow-listed payload, rejects the website honeypot, HMAC-hashes a short-lived rate-limit key (`sf-enquiry:` prefix, stored in `sf_submission_rate_limits`), and calls `submit_sf_enquiry_transaction` with the service role.

There is no Resend/notify step. Saving the enquiry is the source of truth.

Origin is required. Allowed origins are `https://shafeeqahfrancis-gif.github.io` and `https://iederees-create.github.io`. CORS headers are not used as the only gate.

Deploy only after `db/009_shafeeqah_portfolio.sql`. Do not confuse 009 with `db/005_disable_direct_anon_lead_insert.sql`.

```sh
supabase functions deploy submit-shafeeqah-enquiry --no-verify-jwt
```

`--no-verify-jwt` permits anonymous enquiries. It does not expose the service role. The function still requires a matching Origin header.
