import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NotesModel } from '../public/js/notes-model.js';
import { FakeStorage } from './fake-storage.js';

function fakeApi(serverRecords = []) {
  const calls = [];
  return {
    calls,
    async sync(records) {
      calls.push(records);
      return [...serverRecords, ...records];
    },
  };
}

let tick = 0;
const clock = () => new Date(Date.UTC(2026, 9, 6, 12, 0, tick++));

test('create, edit and append update the note and the cache', () => {
  const storage = new FakeStorage();
  const model = new NotesModel({ api: fakeApi(), storage, now: clock });
  const note = model.create();
  model.edit(note.id, 'Typed');
  model.appendTranscript(note.id, 'spoken words.');
  model.stop();

  assert.equal(model.get(note.id).text, 'Typed spoken words.');
  const cached = new NotesModel({ api: fakeApi(), storage, now: clock });
  assert.equal(cached.get(note.id).text, 'Typed spoken words.');
});

test('remove hides the note but keeps a tombstone to sync', async () => {
  const api = fakeApi();
  const model = new NotesModel({ api, storage: new FakeStorage(), now: clock });
  const note = model.create();
  model.remove(note.id);
  await model.syncNow();
  model.stop();

  assert.equal(model.get(note.id), null);
  assert.equal(model.list().length, 0);
  assert.ok(api.calls.at(-1).find((record) => record.id === note.id).deletedAt);
});

test('sync brings in server notes and records the time', async () => {
  const remote = {
    id: '6b1f2c1e-0000-4000-8000-000000000009', text: 'from the mac',
    createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-01T00:00:00.000Z', recordedSeconds: 0,
  };
  const model = new NotesModel({ api: fakeApi([remote]), storage: new FakeStorage(), now: clock });
  await model.syncNow();
  model.stop();

  assert.equal(model.get(remote.id).text, 'from the mac');
  assert.ok(model.lastSyncedAt);
  assert.equal(model.syncError, null);
});

test('a failed sync keeps local notes and exposes the error', async () => {
  const api = { async sync() { throw new Error('offline'); } };
  const model = new NotesModel({ api, storage: new FakeStorage(), now: clock });
  const note = model.create();
  await model.syncNow();
  model.stop();

  assert.equal(model.syncError.message, 'offline');
  assert.ok(model.get(note.id));
});

test('search filters live notes', () => {
  const model = new NotesModel({ api: fakeApi(), storage: new FakeStorage(), now: clock });
  model.edit(model.create().id, 'Project kickoff');
  model.edit(model.create().id, 'Groceries');
  model.stop();
  assert.deepEqual(model.list('kick').map((n) => n.text), ['Project kickoff']);
});
