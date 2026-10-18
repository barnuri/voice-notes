// Browser-safe: shared by the server's sync route and the web client. No node: imports.

export const MAX_NOTES = 5000;
export const MAX_TEXT_LENGTH = 200_000;
export const MAX_RECORDED_SECONDS = 1_000_000;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isDate(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value));
}

function noteIssue(note, index) {
  const prefix = `notes.${index}`;
  if (!note || typeof note !== 'object' || Array.isArray(note)) {
    return `${prefix} must be an object`;
  }
  if (typeof note.id !== 'string' || !UUID_PATTERN.test(note.id)) {
    return `${prefix}.id must be a UUID`;
  }
  if (typeof note.text !== 'string' || note.text.length > MAX_TEXT_LENGTH) {
    return `${prefix}.text must be a string of at most ${MAX_TEXT_LENGTH} characters`;
  }
  if (!isDate(note.createdAt) || !isDate(note.updatedAt)) {
    return `${prefix}.createdAt and updatedAt must be ISO-8601 dates`;
  }
  if (note.deletedAt != null && !isDate(note.deletedAt)) {
    return `${prefix}.deletedAt must be an ISO-8601 date`;
  }
  const seconds = note.recordedSeconds;
  if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0 || seconds > MAX_RECORDED_SECONDS) {
    return `${prefix}.recordedSeconds must be a number from 0 to ${MAX_RECORDED_SECONDS}`;
  }
  return null;
}

function cleanNote(note) {
  const cleaned = {
    id: note.id.toLowerCase(),
    text: note.text,
    createdAt: new Date(note.createdAt).toISOString(),
    updatedAt: new Date(note.updatedAt).toISOString(),
    recordedSeconds: note.recordedSeconds,
  };
  if (note.deletedAt != null) {
    cleaned.deletedAt = new Date(note.deletedAt).toISOString();
  }
  return cleaned;
}

export function validateSyncBody(body) {
  if (!body || typeof body !== 'object' || !Array.isArray(body.notes)) {
    return { error: 'body must be an object with a "notes" array' };
  }
  if (body.notes.length > MAX_NOTES) {
    return { error: `at most ${MAX_NOTES} notes per sync` };
  }
  for (const [index, note] of body.notes.entries()) {
    const issue = noteIssue(note, index);
    if (issue) {
      return { error: issue };
    }
  }
  return { notes: body.notes.map(cleanNote) };
}
