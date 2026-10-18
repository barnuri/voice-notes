import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ApiError } from '../public/js/api-error.js';
import { NotesModel } from '../public/js/notes-model.js';
import { RecordingSession } from '../public/js/recording-session.js';
import { SpeechChunker } from '../public/shared/speech-chunker.js';
import { FakeStorage } from './fake-storage.js';

class FakeMic {
  levelValue = 0.5;
  rotations = 0;
  opened = 0;
  closed = 0;
  segments = 0;
  denied = false;

  async open() {
    if (this.denied) {
      const error = new Error('denied');
      error.name = 'NotAllowedError';
      throw error;
    }
    this.opened += 1;
  }

  startSegment() {
    this.segments += 1;
  }

  async stopSegment() {
    return { blob: new Blob(['A']), seconds: 2, filename: 'segment.webm' };
  }

  async rotate() {
    this.rotations += 1;
    this.segments += 1;
    return this.stopSegment();
  }

  level() {
    return this.levelValue;
  }

  close() {
    this.closed += 1;
  }
}

function setup(replies) {
  const clock = { now: 0 };
  const mic = new FakeMic();
  const notes = new NotesModel({ api: { sync: async (r) => r }, storage: new FakeStorage() });
  const api = {
    models: [],
    languages: [],
    async transcribe(blob, model, filename, language) {
      this.models.push(model);
      this.languages.push(language.code);
      const reply = replies.shift();
      if (reply instanceof Error) {
        throw reply;
      }
      return reply;
    },
  };
  const session = new RecordingSession({
    mic, notes, api, model: () => 'whisper/x', language: () => ({ code: 'he', prompt: 'p' }), now: () => clock.now,
  });
  return { clock, mic, notes, api, session };
}

async function speak(session, mic, clock, ms = 300) {
  mic.levelValue = 0.5;
  for (let t = 0; t < ms; t += 100) {
    clock.now += 100;
    await session.tick();
  }
}

async function settle(session) {
  for (let i = 0; i < 50 && session.pending > 0; i += 1) {
    await new Promise((resolve) => setTimeout(resolve, 1));
  }
}

test('pause and resume append each segment in order', async () => {
  const { clock, mic, notes, api, session } = setup(['first part.', 'second part.']);
  await session.toggle(null);
  assert.equal(session.phase, 'recording');
  await speak(session, mic, clock);
  await session.toggle(null);
  assert.equal(session.phase, 'paused');
  await session.toggle(null);
  await speak(session, mic, clock);
  await session.finish();
  await settle(session);
  notes.stop();

  assert.equal(notes.get(session.noteId).text, 'first part. second part.');
  assert.equal(notes.get(session.noteId).recordedSeconds, 4);
  assert.equal(mic.segments, 2);
  assert.equal(mic.closed, 1);
  assert.deepEqual(api.models, ['whisper/x', 'whisper/x']);
});

test('records into the selected note', async () => {
  const { clock, mic, notes, session } = setup(['later.']);
  const existing = notes.create();
  notes.edit(existing.id, 'Earlier.');
  await session.record(existing.id);
  await speak(session, mic, clock);
  await session.finish();
  await settle(session);
  notes.stop();
  assert.equal(notes.get(existing.id).text, 'Earlier. later.');
});

test('a failed segment is kept and retried into its own note', async () => {
  const { clock, mic, notes, session } = setup([new ApiError(502, "can't reach llm-hub"), 'recovered']);
  await session.record(null);
  await speak(session, mic, clock);
  await session.pause();
  await settle(session);
  assert.equal(session.failed.length, 1);
  assert.equal(session.error, "can't reach llm-hub");

  session.retry();
  await settle(session);
  notes.stop();
  assert.equal(session.failed.length, 0);
  assert.equal(notes.get(session.noteId).text, 'recovered');
});

test('denied microphone shows guidance and stays idle', async () => {
  const { mic, notes, session } = setup([]);
  mic.denied = true;
  await session.record(null);
  notes.stop();
  assert.equal(session.phase, 'idle');
  assert.equal(session.noteId, null);
  assert.match(session.error, /microphone/);
});

test('live: speech then silence transcribes while still recording', async () => {
  const { clock, mic, notes, api, session } = setup(['live words.', 'tail.']);
  await session.record(null);
  await speak(session, mic, clock, SpeechChunker.MIN_CHUNK_MS + 500);
  mic.levelValue = 0;
  for (let i = 0; i < 10; i += 1) {
    clock.now += 100;
    await session.tick();
  }
  await settle(session);
  assert.equal(mic.rotations, 1);
  assert.equal(session.phase, 'recording');
  assert.equal(notes.get(session.noteId).text, 'live words.');

  await speak(session, mic, clock);
  await session.finish();
  await settle(session);
  notes.stop();
  assert.equal(notes.get(session.noteId).text, 'live words. tail.');
  assert.deepEqual(api.languages, ['he', 'he']);
});

test('a quiet chunk is still transcribed so no speech is ever lost', async () => {
  const { clock, mic, notes, api, session } = setup(['quiet words.']);
  await session.record(null);
  mic.levelValue = 0;
  clock.now += 1000;
  await session.tick();
  await session.pause();
  await settle(session);
  await session.finish();
  notes.stop();
  assert.equal(api.models.length, 1);
  assert.equal(notes.get(session.noteId).text, 'quiet words.');
});

test('an empty transcript for speech is reported and kept for retry', async () => {
  const { clock, mic, notes, session } = setup(['', 'second try.']);
  await session.record(null);
  await speak(session, mic, clock);
  await session.pause();
  await settle(session);
  assert.match(session.error, /no text/);
  assert.equal(session.failed.length, 1);
  session.retry();
  await settle(session);
  await session.finish();
  notes.stop();
  assert.equal(notes.get(session.noteId).text, 'second try.');
});

test('an empty result for a quiet chunk is not an error', async () => {
  const { clock, mic, notes, session } = setup(['']);
  await session.record(null);
  mic.levelValue = 0;
  clock.now += 500;
  await session.tick();
  await session.pause();
  await settle(session);
  await session.finish();
  notes.stop();
  assert.equal(session.error, null);
  assert.equal(session.failed.length, 0);
});
