# Exchange Line

A conversion-focused landing page with a live quote calculator, a
Supabase-backed lead pipeline, and a compliant cold outreach sequence —
built for a South African Cloud PBX (Premitel CBX) reseller business.

## What's here

```
index.html   Landing page with the live quote calculator — served
              directly as the GitHub Pages homepage from repo root
db/          Supabase/Postgres schema + RLS policies
email/       3-touch cold outreach sequence + sequencing rules
docs/        Lead sourcing methodology and POPIA compliance notes
             (internal — not part of the public site)
```

## Stack

Dependency-free HTML/CSS/JS · Supabase (Postgres + RLS) · hosted on
GitHub Pages, live at https://iederees-create.github.io/exchange-line/

`index.html` lives at repo root because that's what GitHub Pages'
default build serves — there is exactly one copy of the landing page,
so there's no risk of it drifting from a second copy elsewhere.

## Pricing model

The quote calculator's tiers and rates are pulled directly from
Premitel's published CBX bundle rate sheet — not estimated. See the
comments in `index.html`'s pricing script for the source figures.

## Database

Run `db/schema.sql` first, then `db/002_rls_policies.sql`. The second
file is not optional — without it, the public anon key can read every
lead's contact details.

## Status

Live on GitHub Pages at https://iederees-create.github.io/exchange-line/
(served from `main`, root). This is an active reseller lead-gen build —
see the project owner's private notes for current agreement/compliance
status before pointing outreach traffic at this site.
