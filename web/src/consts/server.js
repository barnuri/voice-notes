import { homedir } from 'node:os';
import { join } from 'node:path';

export const DEFAULT_PORT = 5555;
export const DEFAULT_HOST = '127.0.0.1';
export const DEFAULT_HUB_URL = 'http://127.0.0.1:8888';
export const DEFAULT_DATA_FILE = join(homedir(), 'Library', 'Application Support', 'VoiceNotes', 'server-notes.json');
export const DEFAULT_SETTINGS_FILE = join(homedir(), 'Library', 'Application Support', 'VoiceNotes', 'server-settings.json');
export const MAX_SETTINGS_BODY_BYTES = 4096;
export const MAX_SYNC_BODY_BYTES = 50 * 1024 * 1024;
export const MAX_AUDIO_BODY_BYTES = 25 * 1024 * 1024;
export const HUB_TRANSCRIPTION_PATH = '/v1/audio/transcriptions';
export const HUB_TIMEOUT_MS = 120_000;
export const UPSTREAM_ERROR_PREVIEW_CHARS = 300;
