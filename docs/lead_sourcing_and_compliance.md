# Lead Sourcing Methodology & Compliance Notes

## Who we're looking for (ICP)

- SA-registered SME, roughly 5–100 staff
- In the confirmed Territory (Annexure A — get this filled in before any
  outreach batch, since it defines where you're contractually allowed to sell)
- Public signal of legacy telephony: site still lists a Telkom landline
  number, no mention of VoIP/cloud PBX, job ads for "receptionist" or
  "call centre agent" (signals a manual switchboard), multi-branch retail
  or professional services (law firms, clinics, estate agents — high
  call volume, low current automation)

## Sourcing channels (public information only)

1. **CIPC company registry** — confirms the business is real, registered,
   and gives a registered address for territory matching.
2. **Google Maps / Google Business Profile** — phone number format often
   reveals landline vs mobile-first setups; review mentions of "couldn't
   get through" or "no one answered" are gold for `fit_reason`.
3. **Company websites** — contact pages showing landline numbers,
   "Careers" pages advertising receptionist/call-centre roles.
4. **LinkedIn company pages** — headcount estimate, decision-maker
   identification (office manager, operations director — rarely the
   named "IT" contact for an 11–100 person business).

**Excluded, same as the Skool list:** ZoomInfo, RocketReach, ContactOut,
or any data-broker platform. Only information the business or the
individual has made public themselves.

## Verification checklist per lead (before it enters `status = 'enriched'`)

- [ ] Company is real and currently trading (CIPC + live website)
- [ ] Staff count estimate has a source (LinkedIn, About page, or
      Google review volume as a proxy)
- [ ] Decision-maker name and role are publicly confirmed, not guessed
- [ ] `fit_reason` is a specific, true, one-line observation — not a
      generic template line
- [ ] Contact email is either publicly listed or a standard
      role-based address (info@, admin@) — no guessed/permutated
      addresses

## POPIA — what actually applies here

South Africa's Protection of Personal Information Act governs this, not
the more familiar CAN-SPAM/GDPR frameworks (though the practical rules
end up similar):

- **B2B outreach to a business address for a business purpose** (e.g.
  `info@company.co.za`, or a named person in their professional
  capacity) generally sits on firmer ground under "legitimate interest"
  than direct marketing to a personal/individual capacity.
- **Every email must carry**: an honest sender identity, a real reason
  the person is being contacted, and a working unsubscribe/opt-out —
  all three are already built into the sequence templates.
- **Immediate suppression on request** — if someone replies "unsubscribe"
  or "remove me," that lead's `do_not_contact` flag goes to `true`
  immediately and stays true. The schema's trigger handles this
  automatically off email events, but any manual replies need the same
  treatment logged by hand.
- **Don't scrape or buy consumer/individual contact lists** — this
  entire pipeline is built on public business information, not
  purchased or scraped personal data sets.

## Agent Agreement — Clause 4.1.2 (marketing approval)

The signed agreement requires all advertising and public communication
material relating to the Services to go to Mobifin/Premitel for written
approval before use, with up to 30 days for them to respond. That
covers:

- The landing page (copy + design)
- The 3-email outreach sequence
- Any social posts, ads, or other public-facing material referencing
  Premitel, CBX, or the Premitel brand

**Practical sequencing:** submit the landing page and email sequence for
approval now, in parallel with building the scraper/enrichment tooling
underneath it — that way the 30-day clock isn't sitting idle while
everything else is ready to go live the moment approval lands.

Also worth confirming directly with Quintes: exact wording Premitel is
comfortable with around pricing estimates (the calculator is explicitly
labelled "estimate only," but getting sign-off on that framing avoids
any issue under Clause 4.1.10, which holds the Agent liable for any
promise made outside the official Data Pack).
