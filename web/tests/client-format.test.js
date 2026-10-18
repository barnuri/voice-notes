import assert from 'node:assert/strict';
import { test } from 'node:test';
import { appendTranscript, formatDuration, matchesQuery, noteTitle, relativeTime } from '../public/js/format.js';

test('appendTranscript spaces segments and keeps user line breaks', () => {
  assert.equal(appendTranscript('Hello', '  world. \n'), 'Hello world.');
  assert.equal(appendTranscript('Line one\n', 'two'), 'Line one\ntwo');
  assert.equal(appendTranscript('', 'first'), 'first');
  assert.equal(appendTranscript('keep', '   '), 'keep');
  assert.equal(appendTranscript('A', ' the lake.\n Remember  this.'), 'A the lake. Remember this.');
  assert.equal(appendTranscript('', 'על ה-\nmeeting של מחר.'), 'על ה-meeting של מחר.');
});

test('noteTitle uses the first non-empty line and truncates', () => {
  assert.equal(noteTitle({ text: '' }), 'New note');
  assert.equal(noteTitle({ text: '\n  Groceries \nmilk' }), 'Groceries');
  assert.equal(noteTitle({ text: 'a'.repeat(70) }), `${'a'.repeat(60)}…`);
});

test('formatDuration and relativeTime', () => {
  assert.equal(formatDuration(94.7), '1:34');
  assert.equal(formatDuration(-3), '0:00');
  const now = new Date('2026-10-06T12:00:00Z');
  assert.equal(relativeTime('2026-10-06T11:59:30Z', now), 'just now');
  assert.equal(relativeTime('2026-10-06T11:55:00Z', now), '5 min ago');
  assert.equal(relativeTime('2026-10-06T09:00:00Z', now), '3 h ago');
});

test('matchesQuery is case-insensitive and handles Hebrew', () => {
  assert.ok(matchesQuery({ text: 'שלום Meeting' }, 'meeting'));
  assert.ok(matchesQuery({ text: 'שלום Meeting' }, 'שלום'));
  assert.ok(matchesQuery({ text: 'x' }, '  '));
  assert.ok(!matchesQuery({ text: 'x' }, 'budget'));
});
