import {
  HUB_TIMEOUT_MS,
  HUB_TRANSCRIPTION_PATH,
  MAX_AUDIO_BODY_BYTES,
  MAX_SETTINGS_BODY_BYTES,
  MAX_SYNC_BODY_BYTES,
  UPSTREAM_ERROR_PREVIEW_CHARS,
} from '../consts/server.js';
import { validateSyncBody } from '../../public/shared/note-validation.js';
import { isAuthorized } from '../services/auth.js';
import { BodyTooLargeError } from '../services/body-too-large-error.js';
import { readBody } from '../services/read-body.js';
import { publicVersion } from '../services/public-version.js';
import { sendError, sendJson } from '../services/send.js';

async function handleSync(req, res, { store }) {
  let body;
  try {
    body = JSON.parse((await readBody(req, MAX_SYNC_BODY_BYTES)).toString('utf8'));
  } catch (error) {
    if (error instanceof BodyTooLargeError) {
      throw error;
    }
    sendError(res, 400, 'body must be JSON');
    return;
  }
  const { notes, error } = validateSyncBody(body);
  if (error) {
    sendError(res, 400, error);
    return;
  }
  sendJson(res, 200, { notes: await store.sync(notes) });
}

async function handleSettings(req, res, { settings }) {
  let body;
  try {
    body = JSON.parse((await readBody(req, MAX_SETTINGS_BODY_BYTES)).toString('utf8'));
  } catch (error) {
    if (error instanceof BodyTooLargeError) {
      throw error;
    }
    sendError(res, 400, 'body must be JSON');
    return;
  }
  if (typeof body?.model !== 'string' || !(await settings.selectModel(body.model))) {
    sendError(res, 400, `model must be one of: ${settings.models.map((model) => model.id).join(', ')}`);
    return;
  }
  sendJson(res, 200, { model: settings.model });
}

async function handleTranscribe(req, res, { config }) {
  const contentType = req.headers['content-type'] || '';
  if (!contentType.toLowerCase().startsWith('multipart/form-data')) {
    sendError(res, 400, 'send the audio as multipart/form-data');
    return;
  }
  const audio = await readBody(req, MAX_AUDIO_BODY_BYTES);
  let upstream;
  try {
    upstream = await fetch(`${config.hubUrl}${HUB_TRANSCRIPTION_PATH}`, {
      method: 'POST',
      headers: { 'content-type': contentType },
      body: audio,
      signal: AbortSignal.timeout(HUB_TIMEOUT_MS),
    });
  } catch {
    sendError(res, 502, `can't reach llm-hub at ${config.hubUrl}`);
    return;
  }
  const text = await upstream.text();
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    payload = { error: text.slice(0, UPSTREAM_ERROR_PREVIEW_CHARS) };
  }
  sendJson(res, upstream.status, payload);
}

const ROUTES = {
  'GET /api/config': async (req, res, { config, settings }) => sendJson(res, 200, {
    model: settings.model,
    models: settings.models,
    publicUrl: config.publicUrl,
    version: await publicVersion(config.publicDir),
  }),
  'POST /api/sync': handleSync,
  'PUT /api/settings': handleSettings,
  'POST /api/transcribe': handleTranscribe,
};

export async function handleApi(req, res, deps) {
  if (deps.config.token && !isAuthorized(req.headers.authorization, deps.config.token)) {
    sendError(res, 401, 'missing or wrong access token');
    return;
  }
  const path = new URL(req.url, 'http://local').pathname;
  const route = ROUTES[`${req.method} ${path}`];
  if (!route) {
    sendError(res, 404, 'not found');
    return;
  }
  try {
    await route(req, res, deps);
  } catch (error) {
    if (error instanceof BodyTooLargeError) {
      sendError(res, 413, error.message);
      return;
    }
    sendError(res, 500, 'internal error');
  }
}
