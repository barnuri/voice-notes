import assert from 'node:assert/strict';
import { mkdtemp, writeFile } from 'node:fs/promises';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { appDataDir } from '../src/services/app-data-dir.js';
import { loadConfig } from '../src/services/config.js';

const TOKEN = 'a'.repeat(32);

test('defaults to no token on loopback', () => {
  const config = loadConfig({});
  assert.equal(config.host, '127.0.0.1');
  assert.equal(config.token, '');
});

test('reads token from env and applies defaults', () => {
  const config = loadConfig({ VOICENOTES_TOKEN: TOKEN, VOICENOTES_HUB_URL: 'http://hub:1/' });
  assert.equal(config.token, TOKEN);
  assert.equal(config.port, 5555);
  assert.equal(config.host, '127.0.0.1');
  assert.equal(config.hubUrl, 'http://hub:1');
  assert.equal(config.defaultModel, 'ivrit/ivrit-large-v3-turbo');
  assert.ok(config.models.length >= 2);
});

test('reads token from file', async () => {
  const file = join(await mkdtemp(join(tmpdir(), 'vn-cfg-')), 'token');
  await writeFile(file, `${TOKEN}\n`);
  assert.equal(loadConfig({ VOICENOTES_TOKEN_FILE: file }).token, TOKEN);
});

test('requires a strong token when configured or exposed beyond loopback', () => {
  assert.throws(() => loadConfig({ VOICENOTES_TOKEN: 'short' }), /at least 24 characters/);
  assert.throws(() => loadConfig({ VOICENOTES_HOST: '0.0.0.0' }), /required.*not a loopback/);
  assert.equal(loadConfig({ VOICENOTES_TOKEN_FILE: '/nonexistent' }).token, '');
});

test('rejects a bad port', () => {
  assert.throws(() => loadConfig({ VOICENOTES_TOKEN: TOKEN, VOICENOTES_PORT: 'abc' }), /not a valid port/);
});

test('VOICENOTES_MODELS replaces the built-in model list', () => {
  const config = loadConfig({ VOICENOTES_MODELS: ' openai/whisper-1 , groq/whisper-large-v3 ', VOICENOTES_MODEL: 'openai/whisper-1' });
  assert.deepEqual(config.models.map((model) => model.id), ['openai/whisper-1', 'groq/whisper-large-v3']);
  assert.equal(config.defaultModel, 'openai/whisper-1');
});

test('rejects an empty VOICENOTES_MODELS list', () => {
  assert.throws(() => loadConfig({ VOICENOTES_MODELS: ' , ' }), /at least one model id/);
});

test('stores data in the app data folder unless a file is set', () => {
  const dataDir = appDataDir(process.platform, {}, homedir());
  const defaults = loadConfig({});
  assert.equal(defaults.dataFile, join(dataDir, 'server-notes.json'));
  assert.equal(defaults.settingsFile, join(dataDir, 'server-settings.json'));
  const custom = loadConfig({ VOICENOTES_DATA_FILE: '/tmp/n.json', VOICENOTES_SETTINGS_FILE: '/tmp/s.json' });
  assert.equal(custom.dataFile, '/tmp/n.json');
  assert.equal(custom.settingsFile, '/tmp/s.json');
});
