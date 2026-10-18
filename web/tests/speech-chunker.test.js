import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SpeechChunker } from '../public/shared/speech-chunker.js';

const SPEECH = 0.5;
const SILENCE = 0;

function feed(chunker, level, from, to, step = 100) {
  let closedAt = null;
  for (let now = from; now <= to && closedAt === null; now += step) {
    if (chunker.observe(level, now)) {
      closedAt = now;
    }
  }
  return closedAt;
}

test('does not close before the minimum chunk length', () => {
  const chunker = new SpeechChunker();
  chunker.reset(0);
  assert.equal(feed(chunker, SPEECH, 0, 1000), null);
  assert.equal(feed(chunker, SILENCE, 1100, SpeechChunker.MIN_CHUNK_MS - 100), null);
});

test('closes after speech followed by a short silence', () => {
  const chunker = new SpeechChunker();
  chunker.reset(0);
  const spokeUntil = SpeechChunker.MIN_CHUNK_MS + 500;
  assert.equal(feed(chunker, SPEECH, 0, spokeUntil), null);
  const closedAt = feed(chunker, SILENCE, spokeUntil + 100, spokeUntil + 2000);
  assert.ok(closedAt >= spokeUntil + SpeechChunker.SILENCE_GAP_MS && closedAt < spokeUntil + 1000, `closed at ${closedAt}`);
  assert.equal(chunker.hasSpeech, true);
});

test('pure silence never closes before the maximum and has no speech', () => {
  const chunker = new SpeechChunker();
  chunker.reset(0);
  assert.equal(feed(chunker, SILENCE, 0, SpeechChunker.MAX_CHUNK_MS - 100), null);
  assert.equal(chunker.hasSpeech, false);
});

test('continuous speech is cut at the maximum length', () => {
  const chunker = new SpeechChunker();
  chunker.reset(0);
  assert.equal(feed(chunker, SPEECH, 0, SpeechChunker.MAX_CHUNK_MS * 2), SpeechChunker.MAX_CHUNK_MS);
});

test('long continuous speech is cut at a brief word gap after the long-chunk length', () => {
  const chunker = new SpeechChunker();
  chunker.reset(0);
  const long = SpeechChunker.LONG_CHUNK_MS;
  assert.equal(feed(chunker, SPEECH, 0, long), null);
  const closedAt = feed(chunker, SILENCE, long + 100, long + 1000);
  assert.ok(closedAt >= long + SpeechChunker.WORD_GAP_MS && closedAt < long + SpeechChunker.SILENCE_GAP_MS, `closed at ${closedAt}`);
});

test('a brief word gap early in the chunk does not cut it', () => {
  const chunker = new SpeechChunker();
  chunker.reset(0);
  const spokeUntil = SpeechChunker.MIN_CHUNK_MS + 500;
  assert.equal(feed(chunker, SPEECH, 0, spokeUntil), null);
  assert.equal(feed(chunker, SILENCE, spokeUntil + 100, spokeUntil + 500), null);
});
