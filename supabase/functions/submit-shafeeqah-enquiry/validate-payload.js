export const SITE_ID = 'shafeeqah-portfolio';
export const PATHS = ['project', 'employment'];
export const SERVICES = ['qa-workflow', 'sop-docs', 'data-quality', 'reporting', 'release-readiness', 'define-project'];
export const TIMING = ['exploring', 'one-month', 'this-month', 'flexible'];
export const CONTACT_METHODS = ['email', 'whatsapp', 'either'];

const text = (value, max, required = true) => {
  if (typeof value !== 'string') {
    if (!required && (value === null || value === undefined)) return null;
    throw new Error('invalid_field');
  }
  const clean = value.trim().replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '');
  if ((required && !clean) || clean.length > max) throw new Error('invalid_field');
  return clean || null;
};

const urlOk = (value) => {
  if (!value) return true;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
};

export function validatePayload(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('invalid_request');
  const p = input;
  if (p.website) throw new Error('invalid_request');
  const path = text(p.path, 40);
  if (!PATHS.includes(path)) throw new Error('invalid_field');
  const service = path === 'project' ? text(p.service, 80) : text(p.service, 80, false);
  const role = path === 'employment' ? text(p.role, 120) : text(p.role, 120, false);
  if (path === 'project' && !SERVICES.includes(service)) throw new Error('invalid_field');
  if (path === 'employment' && (!role || role.length < 2)) throw new Error('invalid_field');
  const description = text(p.description, 1500);
  if (description.length < 12) throw new Error('invalid_field');
  const timing = text(p.timing, 40);
  if (!TIMING.includes(timing)) throw new Error('invalid_field');
  const projectUrl = text(p.project_url, 500, false);
  if (!urlOk(projectUrl)) throw new Error('invalid_field');
  const email = text(p.email, 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('invalid_field');
  const phone = text(p.phone, 40, false);
  if (phone && phone.length < 8) throw new Error('invalid_field');
  const preferred = text(p.preferred_contact, 20);
  if (!CONTACT_METHODS.includes(preferred)) throw new Error('invalid_field');
  const contactName = text(p.contact_name, 120);
  if (contactName.length < 2) throw new Error('invalid_field');
  return {
    site_id: SITE_ID,
    path,
    service: path === 'project' ? service : null,
    role: path === 'employment' ? role : null,
    description,
    timing,
    budget: text(p.budget, 80, false),
    project_url: projectUrl,
    contact_name: contactName,
    email,
    phone,
    preferred_contact: preferred,
    source_path: text(p.source_path, 300, false),
    utm_source: text(p.utm_source, 150, false),
    utm_medium: text(p.utm_medium, 150, false),
    utm_campaign: text(p.utm_campaign, 150, false),
    utm_content: text(p.utm_content, 150, false),
    utm_term: text(p.utm_term, 150, false),
    privacy_version: text(p.privacy_version, 50),
    idempotency_key: text(p.idempotency_key, 80, false) || crypto.randomUUID(),
    is_synthetic: Boolean(p.is_synthetic),
  };
}
