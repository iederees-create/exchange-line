# Exchange Line — Cold Outreach Sequence

Three emails, spaced ~4 business days apart. Each one is short enough to
read on a phone. Merge fields come straight from the `leads` table.

**Merge fields used:** `{{contact_name}}`, `{{company_name}}`,
`{{fit_reason}}`, `{{current_provider}}`, `{{quote_link}}`,
`{{unsubscribe_link}}`

Send via Resend. Every email carries a visible unsubscribe link and an
honest sender identity — non-negotiable for POPIA compliance, not optional.

---

## Email 1 — The observation (Day 0)

**Subject:** quick one about {{company_name}}'s phone line

Hi {{contact_name}},

Came across {{company_name}} while looking at businesses in your area —
{{fit_reason}}.

Most teams your size are still paying landline rates for something a
cloud exchange handles for less, with zero hardware and unlimited
extensions if you ever grow the team.

Worth 90 seconds to see what it'd cost you specifically? No call needed —
just numbers: {{quote_link}}

Iederees Francis
Exchange Line — authorised Premitel reseller

*Don't want emails like this? {{unsubscribe_link}}*

---

## Email 2 — The specific case (Day 4)

**Subject:** re: {{company_name}}'s phone line

Hi {{contact_name}},

Following up briefly — didn't want this to just sit unread.

The short version of what changes if {{company_name}} moves off
{{current_provider}}:

- Every staff member gets their own extension, set up same-day, no
  technician visit
- Calls that used to just ring out get caught by an auto-attendant
  instead of a missed opportunity
- Call rates run roughly 20% below the industry average

Here's your number again, no form re-entry needed: {{quote_link}}

If it's genuinely not relevant right now, just reply "not now" and I'll
leave it there.

Iederees

*Don't want emails like this? {{unsubscribe_link}}*

---

## Email 3 — The close (Day 8)

**Subject:** last one from me, {{contact_name}}

Hi {{contact_name}},

Last note on this — I don't want to clutter your inbox.

If a lower phone bill and less admin around your call handling is
useful to {{company_name}} at some point this year, the estimate's
still sitting here: {{quote_link}}

If not, no worries at all, and I won't follow up again.

All the best,
Iederees Francis
Exchange Line

*Don't want emails like this? {{unsubscribe_link}}*

---

## Sequencing rules (for the automation)

1. Only enter a lead into the sequence once `status = 'enriched'` and
   `do_not_contact = false`.
2. Stop the sequence immediately on any `replied`, `unsubscribed`, or
   `bounced` event — check `leads.status` before each send.
3. Space sends by real business days, not calendar days (skip weekends).
4. Cap sends per domain per day to avoid tripping spam filters — start
   conservative (30–50/day) and scale once domain reputation is proven.
5. Warm up the sending domain for 1–2 weeks with low volume before the
   first real campaign — this matters more than sequence copy for
   inbox placement.
