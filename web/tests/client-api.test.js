import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ApiClient } from '../public/js/api-client.js';
import { takeTokenFromHash, readToken, saveToken, clearToken } from '../public/js/token-store.js';
import { FakeStorage } from './fake-storage.js';

function respond(status, body) {
  return async (path, init) => {
    respond.last = { path, init };
    return new Response(JSON.stringify(body), { status });
  };
}

test('sends the bearer token and returns synced notes', async () => {
  const client = new ApiClient('tok', respond(200, { notes: [{ id: 'a' }] }));
  assert.deepEqual(await client.sync([]), [{ id: 'a' }]);
  assert.equal(respond.last.path, '/api/sync');
  assert.equal(respond.last.init.headers.authorization, 'Bearer tok');
});

test('omits authorization when no token is configured', async () => {
  const client = new ApiClient('', respond(200, { model: 'ivrit/a' }));
  assert.deepEqual(await client.config(), { model: 'ivrit/a' });
  assert.equal(respond.last.init.headers.authorization, undefined);
});

test('maps hub and server error shapes and 401', async () => {
  const hub = new ApiClient('t', respond(502, { error: { message: 'all attempts failed' } }));
  await assert.rejects(hub.config(), { message: 'all attempts failed', status: 502 });
  const denied = new ApiClient('t', respond(401, { error: 'missing or wrong access token' }));
  await assert.rejects(denied.config(), (error) => error.isUnauthorized);
});

test('a network failure becomes a readable error', async () => {
  const client = new ApiClient('t', async () => { throw new TypeError('fetch failed'); });
  await assert.rejects(client.config(), { status: 0, message: /Can't reach/ });
});

test('transcribe posts model then file and trims the text', async () => {
  const client = new ApiClient('t', respond(200, { text: ' hi \n' }));
  assert.equal(await client.transcribe(new Blob(['A']), 'whisper/x', 'segment.webm', { code: 'he', prompt: 'p' }), 'hi');
  assert.deepEqual([...respond.last.init.body.keys()], ['model', 'response_format', 'language', 'prompt', 'file']);
  await client.transcribe(new Blob(['A']), 'whisper/x', 'segment.webm', { code: null, prompt: null });
  assert.deepEqual([...respond.last.init.body.keys()], ['model', 'response_format', 'file']);
});

test('token store reads links and survives storage errors', () => {
  assert.equal(takeTokenFromHash({ hash: '#token=abc%20' }), 'abc');
  assert.equal(takeTokenFromHash({ hash: '#other' }), '');
  assert.equal(takeTokenFromHash({ hash: '#token=%E0%A4%A' }), '');
  const storage = new FakeStorage();
  saveToken(storage, ' t1 ');
  assert.equal(readToken(storage), 't1');
  clearToken(storage);
  assert.equal(readToken(storage), '');
  const broken = { getItem() { throw new Error('blocked'); } };
  assert.equal(readToken(broken), '');
});

test('selectModel puts the id and returns the saved model', async () => {
  const client = new ApiClient('t', respond(200, { model: 'ivrit/a' }));
  assert.equal(await client.selectModel('ivrit/a'), 'ivrit/a');
  assert.equal(respond.last.path, '/api/settings');
  assert.equal(respond.last.init.method, 'PUT');
  assert.equal(respond.last.init.body, '{"model":"ivrit/a"}');
});
