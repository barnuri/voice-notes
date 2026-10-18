import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, readFile, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, before, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { startServer } from '../src/server.js';

const TOKEN = 'test-token-0123456789abcdef0123';
const NOTE = {
  id: '6b1f2c1e-0000-4000-8000-000000000001',
  text: 'from the mac',
  createdAt: '2026-10-01T00:00:00.000Z',
  updatedAt: '2026-10-01T00:00:00.000Z',
  recordedSeconds: 2,
};
let server;
let hub;
let base;
let dataFile;
let hubRequests = [];

function api(path, init = {}) {
  return fetch(`${base}${path}`, {
    ...init,
    headers: { authorization: `Bearer ${TOKEN}`, ...init.headers },
  });
}

before(async () => {
  hub = createServer(async (req, res) => {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    hubRequests.push({ url: req.url, type: req.headers['content-type'], body: Buffer.concat(chunks).toString() });
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ text: ' hello there\n' }));
  });
  await new Promise((resolve) => hub.listen(0, '127.0.0.1', resolve));
  dataFile = join(await mkdtemp(join(tmpdir(), 'vn-web-')), 'notes.json');
  server = await startServer({
    port: 0,
    host: '127.0.0.1',
    hubUrl: `http://127.0.0.1:${hub.address().port}`,
    defaultModel: 'ivrit/a',
    models: [{ id: 'ivrit/a', title: 'A', description: '' }, { id: 'whisper/b', title: 'B', description: '' }],
    publicUrl: 'https://box.example.ts.net:5555',
    dataFile,
    settingsFile: join(dirname(dataFile), 'settings.json'),
    publicDir: fileURLToPath(new URL('../public/', import.meta.url)),
    token: TOKEN,
  });
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server.close();
  hub.close();
});

test('api rejects a missing or wrong token', async () => {
  assert.equal((await fetch(`${base}/api/config`)).status, 401);
  const wrong = await fetch(`${base}/api/config`, { headers: { authorization: 'Bearer nope' } });
  assert.equal(wrong.status, 401);
});

test('api accepts requests without a token when authentication is disabled', async () => {
  const openDataFile = join(await mkdtemp(join(tmpdir(), 'vn-web-open-')), 'notes.json');
  const openServer = await startServer({
    port: 0,
    host: '127.0.0.1',
    hubUrl: `http://127.0.0.1:${hub.address().port}`,
    defaultModel: 'ivrit/a',
    models: [{ id: 'ivrit/a', title: 'A', description: '' }],
    publicUrl: '',
    dataFile: openDataFile,
    settingsFile: join(dirname(openDataFile), 'settings.json'),
    publicDir: fileURLToPath(new URL('../public/', import.meta.url)),
    token: '',
  });
  try {
    const response = await fetch(`http://127.0.0.1:${openServer.address().port}/api/config`);
    assert.equal(response.status, 200);
  } finally {
    await new Promise((resolve) => openServer.close(resolve));
  }
});

test('config returns the model', async () => {
  const config = await (await api('/api/config')).json();
  assert.equal(config.model, 'ivrit/a');
  assert.deepEqual(config.models.map((m) => m.id), ['ivrit/a', 'whisper/b']);
  assert.equal(config.publicUrl, 'https://box.example.ts.net:5555');
  assert.match(config.version, /^\d+$/);
});

test('sync merges, persists with private permissions, and returns everything', async () => {
  const first = await api('/api/sync', { method: 'POST', body: JSON.stringify({ notes: [NOTE] }) });
  assert.equal(first.status, 200);
  const edit = { ...NOTE, text: 'edited on the phone', updatedAt: '2026-10-02T00:00:00.000Z' };
  const second = await (await api('/api/sync', { method: 'POST', body: JSON.stringify({ notes: [edit, NOTE] }) })).json();
  assert.equal(second.notes.length, 1);
  assert.equal(second.notes[0].text, 'edited on the phone');

  const saved = JSON.parse(await readFile(dataFile, 'utf8'));
  assert.equal(saved.notes[0].text, 'edited on the phone');
  assert.equal((await stat(dataFile)).mode & 0o777, 0o600);
});

test('model selection is validated, saved and shared', async () => {
  const put = (body) => api('/api/settings', { method: 'PUT', headers: { 'content-type': 'application/json' }, body });
  assert.equal((await put('{"model":"nope"}')).status, 400);
  assert.equal((await put('{')).status, 400);
  assert.deepEqual(await (await put('{"model":"whisper/b"}')).json(), { model: 'whisper/b' });
  assert.equal((await (await api('/api/config')).json()).model, 'whisper/b');
  const saved = JSON.parse(await readFile(join(dirname(dataFile), 'settings.json'), 'utf8'));
  assert.equal(saved.model, 'whisper/b');
  assert.equal((await fetch(`${base}/api/settings`, { method: 'PUT', body: '{"model":"ivrit/a"}' })).status, 401);
});

test('sync rejects invalid bodies', async () => {
  const notJson = await api('/api/sync', { method: 'POST', body: '{' });
  assert.equal(notJson.status, 400);
  const badNote = await api('/api/sync', { method: 'POST', body: JSON.stringify({ notes: [{ id: 'x' }] }) });
  assert.equal(badNote.status, 400);
});

test('transcribe forwards the multipart body to llm-hub', async () => {
  const form = new FormData();
  form.append('model', 'whisper/b');
  form.append('file', new Blob(['AUDIO'], { type: 'audio/webm' }), 'a.webm');
  const response = await api('/api/transcribe', { method: 'POST', body: form });

  assert.equal(response.status, 200);
  assert.equal((await response.json()).text, ' hello there\n');
  const forwarded = hubRequests.at(-1);
  assert.equal(forwarded.url, '/v1/audio/transcriptions');
  assert.match(forwarded.type, /^multipart\/form-data; boundary=/);
  assert.match(forwarded.body, /whisper\/b/);
  assert.match(forwarded.body, /AUDIO/);
});

test('transcribe requires multipart', async () => {
  const response = await api('/api/transcribe', { method: 'POST', body: 'raw' });
  assert.equal(response.status, 400);
});

test('static files are served with security headers and traversal is blocked', async () => {
  const index = await fetch(`${base}/`);
  assert.equal(index.status, 200);
  assert.match(index.headers.get('content-security-policy'), /frame-ancestors/);
  assert.equal((await fetch(`${base}/shared/merge-notes.js`)).status, 200);
  assert.equal((await fetch(`${base}/%2e%2e/package.json`)).status, 404);
  assert.equal((await fetch(`${base}/missing.js`)).status, 404);
  assert.equal((await fetch(`${base}/%E0%A4%A`)).status, 400);
});

test('unknown api route is 404 after auth', async () => {
  assert.equal((await api('/api/nope')).status, 404);
});
