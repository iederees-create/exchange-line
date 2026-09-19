export const allowedOutcomes = [
  'fewer_missed_calls',
  'easier_routing',
  'remote_staff',
  'usage_visibility',
  'call_recording',
  'keep_number',
  'not_sure',
];

const allowed = {
  current_setup: ['not_sure', 'telkom_landline', 'on_premise_pbx', 'cloud_voip', 'mobile_only', 'other'],
  business_status: ['trading', 'new_business'],
  remote_required: ['not_sure', 'yes', 'no'],
  keep_number: ['not_sure', 'yes', 'no'],
  decision_timeline: ['researching', 'three_months', 'one_month', 'asap'],
  preferred_contact: ['email', 'whatsapp', 'conversation'],
};

const text = (value, max, required = true) => {
  if (typeof value !== 'string') {
    if (!required && (value === null || value === undefined)) return null;
    throw new Error('invalid_field');
  }
  const clean = value.trim().replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '');
  if ((required && !clean) || clean.length > max) throw new Error('invalid_field');
  return clean || null;
};

const enumValue = (payload, key) => {
  const value = text(payload[key], 50);
  if (!allowed[key].includes(value)) throw new Error('invalid_field');
  return value;
};

export function validatePayload(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('invalid_request');
  const p = input;
  if (p.website) throw new Error('invalid_request');
  const staff = Number(p.staff_count), locations = Number(p.location_count);
  if (!Number.isInteger(staff) || staff < 1 || staff > 1000 || !Number.isInteger(locations) || locations < 1 || locations > 1000) {
    throw new Error('invalid_field');
  }
  if (
    !Array.isArray(p.outcomes) ||
    p.outcomes.length < 1 ||
    p.outcomes.length > allowedOutcomes.length ||
    p.outcomes.some((v) => typeof v !== 'string' || !allowedOutcomes.includes(v))
  ) {
    throw new Error('invalid_field');
  }
  const email = text(p.email, 254);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('invalid_field');
  return {
    contact_name: text(p.contact_name, 120),
    company_name: text(p.company_name, 160),
    role: text(p.role, 100),
    email: email.toLowerCase(),
    whatsapp: text(p.whatsapp, 40, false),
    staff_count: staff,
    location_count: locations,
    current_setup: enumValue(p, 'current_setup'),
    business_status: enumValue(p, 'business_status'),
    remote_required: enumValue(p, 'remote_required'),
    keep_number: enumValue(p, 'keep_number'),
    outcomes: [...new Set(p.outcomes)],
    problem_description: text(p.problem_description, 1500),
    decision_timeline: enumValue(p, 'decision_timeline'),
    preferred_contact: enumValue(p, 'preferred_contact'),
    preferred_response_time: text(p.preferred_response_time, 100),
    source_url: text(p.source_url, 1000, false),
    utm_source: text(p.utm_source, 150, false),
    utm_medium: text(p.utm_medium, 150, false),
    utm_campaign: text(p.utm_campaign, 150, false),
    utm_content: text(p.utm_content, 150, false),
    utm_term: text(p.utm_term, 150, false),
    referral_code: text(p.referral_code, 100, false),
    privacy_version: text(p.privacy_version, 50),
    turnstile_token: text(p.turnstile_token, 2048, false),
  };
}
