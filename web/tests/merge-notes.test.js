import assert from 'node:assert/strict';
import { test } from 'node:test';
import { liveNotes, mergeNotes, tombstone } from '../public/shared/merge-notes.js';

const ID = '6b1f2c1e-0000-4000-8000-000000000001';

function note(text, updatedAt, extra = {}) {
  return { id: ID, text, createdAt: '2026-10-01T00:00:00.000Z', updatedAt, recordedSeconds: 0, ...extra };
}

test('later updatedAt wins regardless of argument order', () => {
  const older = note('old', '2026-10-01T10:00:00.000Z');
  const newer = note('new', '2026-10-01T10:00:00.500Z');
  assert.equal(mergeNotes([older], [newer])[0].text, 'new');
  assert.equal(mergeNotes([newer], [older])[0].text, 'new');
});

test('ids match case-insensitively and come back lowercase', () => {
  const upper = note('upper', '2026-10-02T00:00:00Z', { id: ID.toUpperCase() });
  const merged = mergeNotes([note('lower', '2026-10-01T00:00:00Z')], [upper]);
  assert.equal(merged.length, 1);
  assert.equal(merged[0].id, ID);
  assert.equal(merged[0].text, 'upper');
});

test('a delete on a tie wins and liveNotes hides it', () => {
  const kept = note('text', '2026-10-01T10:00:00.000Z');
  const deleted = note('', '2026-10-01T10:00:00.000Z', { deletedAt: '2026-10-01T10:00:00.000Z' });
  const merged = mergeNotes([kept], [deleted]);
  assert.ok(merged[0].deletedAt);
  assert.deepEqual(liveNotes(merged), []);
});

test('an edit after a delete brings the note back', () => {
  const deleted = note('', '2026-10-01T10:00:00Z', { deletedAt: '2026-10-01T10:00:00Z' });
  const edited = note('revived', '2026-10-01T11:00:00Z');
  assert.equal(liveNotes(mergeNotes([deleted], [edited]))[0].text, 'revived');
});

test('tombstone clears text and stamps both dates', () => {
  const at = new Date('2026-10-03T00:00:00.000Z');
  const record = tombstone(note('secret', '2026-10-01T00:00:00Z'), at);
  assert.equal(record.text, '');
  assert.equal(record.updatedAt, at.toISOString());
  assert.equal(record.deletedAt, at.toISOString());
});

test('result is sorted newest first', () => {
  const a = { ...note('a', '2026-10-01T00:00:00Z'), id: '00000000-0000-4000-8000-00000000000a' };
  const b = { ...note('b', '2026-10-05T00:00:00Z'), id: '00000000-0000-4000-8000-00000000000b' };
  assert.deepEqual(mergeNotes([a, b]).map((n) => n.text), ['b', 'a']);
});
