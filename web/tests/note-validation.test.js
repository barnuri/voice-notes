import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MAX_NOTES, MAX_TEXT_LENGTH, validateSyncBody } from '../public/shared/note-validation.js';

const valid = {
  id: '6B1F2C1E-0000-4000-8000-000000000001',
  text: 'hello',
  createdAt: '2026-10-01T00:00:00Z',
  updatedAt: '2026-10-01T00:00:01.250Z',
  recordedSeconds: 3.5,
};

test('valid notes are normalized', () => {
  const { notes, error } = validateSyncBody({ notes: [valid] });
  assert.equal(error, undefined);
  assert.equal(notes[0].id, valid.id.toLowerCase());
  assert.equal(notes[0].createdAt, '2026-10-01T00:00:00.000Z');
  assert.equal('deletedAt' in notes[0], false);
});

test('unknown fields are dropped', () => {
  const { notes } = validateSyncBody({ notes: [{ ...valid, extra: '<script>' }] });
  assert.equal('extra' in notes[0], false);
});

for (const [label, body] of [
  ['missing array', {}],
  ['bad id', { notes: [{ ...valid, id: '../etc' }] }],
  ['text too long', { notes: [{ ...valid, text: 'a'.repeat(MAX_TEXT_LENGTH + 1) }] }],
  ['bad date', { notes: [{ ...valid, updatedAt: 'yesterday' }] }],
  ['bad deletedAt', { notes: [{ ...valid, deletedAt: 'soon' }] }],
  ['negative seconds', { notes: [{ ...valid, recordedSeconds: -1 }] }],
  ['too many notes', { notes: Array.from({ length: MAX_NOTES + 1 }, () => valid) }],
]) {
  test(`rejects ${label}`, () => {
    assert.ok(validateSyncBody(body).error);
  });
}
