# Exchange Line

A conversion-focused landing page for Iederees Francis's Premitel freelance
sales work. The public journey identifies business phone problems, gathers
requirements and sends inbound enquiries to Supabase or a review-before-send
WhatsApp funnel.

## What's here

- `index.html` - GitHub Pages landing page and 60-second phone check.
- `db/` - Supabase/Postgres schema, RLS and consent migrations.
- `email/` - problem-led outreach sequence and operating rules.
- `docs/` - internal lead-sourcing and POPIA notes.

## Public quote policy

The public site deliberately does not expose Premitel rates, bundle codes,
bundle prices, technical add-on prices or calculated estimates. Prospects are
not expected to configure PBX terminology themselves. They describe their team,
locations, current setup and desired outcomes; Iederees confirms the
requirements and Louise at Premitel prepares the formal quote privately.

Internal database quote fields remain available for authorised operational use.
They are not populated with a browser-generated public estimate.

## Stack and deployment

Dependency-free HTML/CSS/JavaScript, Supabase (Postgres plus RLS), and GitHub
Pages. The live homepage is served from `main` at:

https://iederees-create.github.io/exchange-line/

## Database

Apply `db/schema.sql`, then the numbered migrations in order. The RLS and
consent migrations are required before public traffic: anonymous visitors may
submit an inbound request, but may not read lead PII or convert that request
into marketing consent.
