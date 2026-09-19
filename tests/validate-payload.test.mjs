import test from 'node:test';
import assert from 'node:assert/strict';
import { allowedOutcomes, validatePayload } from '../supabase/functions/submit-lead/validate-payload.js';

const valid = {
  contact_name: 'Alex Tester',
  company_name: 'Example Co',
  role: 'Operations',
  email: 'alex.tester@example.com',
  staff_count: 4,
  location_count: 1,
  current_setup: 'not_sure',
  business_status: 'trading',
  remote_required: 'not_sure',
  keep_number: 'yes',
  outcomes: ['fewer_missed_calls'],
  problem_description: 'Calls ring unanswered when reception is busy.',
  decision_timeline: 'researching',
  preferred_contact: 'email',
  preferred_response_time: 'weekday afternoons',
  privacy_version: '2026-09-19',
  website: '',
};

test('allows a complete payload with at least one outcome', () => {
  const result = validatePayload(valid);
  assert.equal(result.email, 'alex.tester@example.com');
  assert.deepEqual(result.outcomes, ['fewer_missed_calls']);
});

test('rejects empty outcomes', () => {
  assert.throws(() => validatePayload({ ...valid, outcomes: [] }), /invalid_field/);
});

test('accepts the explicit not_sure outcome', () => {
  const result = validatePayload({ ...valid, outcomes: ['not_sure'] });
  assert.deepEqual(result.outcomes, ['not_sure']);
  assert.ok(allowedOutcomes.includes('not_sure'));
});

test('rejects an unknown outcome', () => {
  assert.throws(() => validatePayload({ ...valid, outcomes: ['cheaper_price'] }), /invalid_field/);
});
