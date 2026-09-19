import test from 'node:test';
import assert from 'node:assert/strict';
import { validatePayload } from '../supabase/functions/submit-shafeeqah-enquiry/validate-payload.js';
import { validatePayload as validateEvent, ALLOWED_EVENTS } from '../supabase/functions/record-shafeeqah-event/validate-payload.js';

const valid = {
  path: 'project',
  service: 'qa-workflow',
  description: 'Need a release-readiness review of a demo workflow.',
  timing: 'exploring',
  contact_name: 'Alex Tester',
  email: 'alex.tester@example.com',
  preferred_contact: 'email',
  privacy_version: '2026-09-19',
  website: '',
  project_url: '',
};

test('accepts a complete project enquiry', () => {
  const result = validatePayload(valid);
  assert.equal(result.email, 'alex.tester@example.com');
  assert.equal(result.path, 'project');
  assert.equal(result.is_synthetic, false);
});

test('rejects honeypot submissions', () => {
  assert.throws(() => validatePayload({ ...valid, website: 'https://spam.example' }), /invalid_request/);
});

test('employment path requires a role instead of a service', () => {
  const result = validatePayload({
    ...valid,
    path: 'employment',
    service: '',
    role: 'Quality Assurance Analyst',
  });
  assert.equal(result.role, 'Quality Assurance Analyst');
  assert.equal(result.service, null);
});

test('event allowlist matches the documented names', () => {
  assert.deepEqual(ALLOWED_EVENTS, [
    'page_view',
    'case_study_view',
    'case_study_download',
    'linkedin_click',
    'whatsapp_click',
    'enquiry_start',
    'enquiry_saved',
    'affiliate_outbound',
  ]);
});

test('events reject PII property keys and unknown event names', () => {
  assert.throws(() => validateEvent({ event_name: 'page_view', properties: { email: 'a@b.c' } }), /invalid_field/);
  assert.throws(() => validateEvent({ event_name: 'purchase' }), /invalid_field/);
  const ok = validateEvent({ event_name: 'case_study_view', source_path: '/case-studies/member-upload/', properties: { case_id: 'MU' } });
  assert.equal(ok.event_name, 'case_study_view');
  assert.equal(ok.properties.case_id, 'MU');
});
