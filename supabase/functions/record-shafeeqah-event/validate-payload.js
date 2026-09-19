export const SITE_ID = 'shafeeqah-portfolio';
export const ALLOWED_EVENTS = [
  'page_view',
  'case_study_view',
  'case_study_download',
  'linkedin_click',
  'whatsapp_click',
  'enquiry_start',
  'enquiry_saved',
  'affiliate_outbound',
];

const BLOCKED_PROPERTY_KEYS = /^(email|phone|name|contact_name|user_agent|ua|ip|ip_address|address)$/i;
const ALLOWED_PROPERTY_KEYS = ['case_id', 'affiliate', 'path', 'title', 'source'];

const text = (value, max, required = true) => {
  if (typeof value !== 'string') {
    if (!required && (value === null || value === undefined)) return null;
    throw new Error('invalid_field');
  }
  const clean = value.trim().replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '');
  if ((required && !clean) || clean.length > max) throw new Error('invalid_field');
  return clean || null;
};

export function validatePayload(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('invalid_request');
  const p = input;
  if (p.website) throw new Error('invalid_request');
  const eventName = text(p.event_name, 80);
  if (!ALLOWED_EVENTS.includes(eventName)) throw new Error('invalid_field');
  const properties = p.properties && typeof p.properties === 'object' && !Array.isArray(p.properties) ? p.properties : {};
  const cleanProps = {};
  for (const [key, value] of Object.entries(properties)) {
    if (BLOCKED_PROPERTY_KEYS.test(key)) throw new Error('invalid_field');
    if (!ALLOWED_PROPERTY_KEYS.includes(key)) continue;
    if (typeof value !== 'string') throw new Error('invalid_field');
    const clean = text(value, 200, false);
    if (clean) cleanProps[key] = clean;
  }
  return {
    site_id: SITE_ID,
    event_name: eventName,
    source_path: text(p.source_path, 300, false),
    properties: cleanProps,
  };
}
