const TITLE_LENGTH = 60;
const MINUTE = 60;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

export function noteTitle(note) {
  const firstLine = (note.text.split(/\r?\n/).find((line) => line.trim()) || '').trim();
  if (!firstLine) {
    return 'New note';
  }
  return firstLine.length > TITLE_LENGTH ? `${firstLine.slice(0, TITLE_LENGTH)}…` : firstLine;
}

export function formatDuration(totalSeconds) {
  const seconds = Math.max(0, Math.floor(totalSeconds));
  const minutes = Math.floor(seconds / MINUTE);
  return `${minutes}:${String(seconds % MINUTE).padStart(2, '0')}`;
}

export function relativeTime(iso, now = new Date()) {
  const seconds = Math.round((now - new Date(iso)) / 1000);
  if (seconds < MINUTE) {
    return 'just now';
  }
  if (seconds < HOUR) {
    return `${Math.floor(seconds / MINUTE)} min ago`;
  }
  if (seconds < DAY) {
    return `${Math.floor(seconds / HOUR)} h ago`;
  }
  return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

export function appendTranscript(text, transcript) {
  const addition = transcript.replace(/-\s*\n\s*/g, '-').replace(/\s+/g, ' ').trim();
  if (!addition) {
    return text;
  }
  const needsSpace = text.length > 0 && !/\s$/.test(text);
  return `${text}${needsSpace ? ' ' : ''}${addition}`;
}

export function matchesQuery(note, query) {
  const needle = query.trim().toLocaleLowerCase();
  return !needle || note.text.toLocaleLowerCase().includes(needle);
}
