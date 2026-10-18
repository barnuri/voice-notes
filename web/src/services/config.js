import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { DEFAULT_MODEL_ID, MODELS } from '../consts/models.js';
import {
  DEFAULT_DATA_FILE,
  DEFAULT_HOST,
  DEFAULT_HUB_URL,
  DEFAULT_SETTINGS_FILE,
  DEFAULT_PORT,
} from '../consts/server.js';

const MIN_TOKEN_LENGTH = 24;
const LOOPBACK_HOSTS = new Set(['127.0.0.1', '::1', '[::1]', 'localhost']);

function readToken(env) {
  if (env.VOICENOTES_TOKEN) {
    return env.VOICENOTES_TOKEN.trim();
  }
  if (!env.VOICENOTES_TOKEN_FILE) {
    return '';
  }
  try {
    return readFileSync(env.VOICENOTES_TOKEN_FILE, 'utf8').trim();
  } catch {
    return '';
  }
}

function parseModels(raw) {
  if (!raw) {
    return MODELS;
  }
  const ids = raw.split(',').map((id) => id.trim()).filter(Boolean);
  if (ids.length === 0) {
    throw new Error('VOICENOTES_MODELS must list at least one model id');
  }
  return ids.map((id) => ({ id, title: id, description: '' }));
}

function parsePort(raw) {
  if (raw == null || raw === '') {
    return DEFAULT_PORT;
  }
  const port = Number(raw);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error(`VOICENOTES_PORT is not a valid port: ${raw}`);
  }
  return port;
}

export function loadConfig(env = process.env) {
  const host = env.VOICENOTES_HOST || DEFAULT_HOST;
  const token = readToken(env);
  if (token && token.length < MIN_TOKEN_LENGTH) {
    throw new Error(`VOICENOTES_TOKEN must contain at least ${MIN_TOKEN_LENGTH} characters`);
  }
  if (!LOOPBACK_HOSTS.has(host) && !token) {
    throw new Error('VOICENOTES_TOKEN is required when VOICENOTES_HOST is not a loopback address');
  }
  return {
    port: parsePort(env.VOICENOTES_PORT),
    host,
    hubUrl: (env.VOICENOTES_HUB_URL || DEFAULT_HUB_URL).replace(/\/+$/, ''),
    defaultModel: env.VOICENOTES_MODEL || DEFAULT_MODEL_ID,
    models: parseModels(env.VOICENOTES_MODELS),
    settingsFile: env.VOICENOTES_SETTINGS_FILE || DEFAULT_SETTINGS_FILE,
    publicUrl: env.VOICENOTES_PUBLIC_URL || '',
    dataFile: env.VOICENOTES_DATA_FILE || DEFAULT_DATA_FILE,
    publicDir: fileURLToPath(new URL('../../public/', import.meta.url)),
    token,
  };
}
