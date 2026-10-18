// Browser-safe: shared by the server's sync route and the web client. No node: imports.

function timeOf(record) {
  return Date.parse(record.updatedAt);
}

function newer(current, candidate) {
  if (!current) {
    return candidate;
  }
  const diff = timeOf(candidate) - timeOf(current);
  if (diff !== 0) {
    return diff > 0 ? candidate : current;
  }
  return candidate.deletedAt && !current.deletedAt ? candidate : current;
}

export function mergeNotes(...lists) {
  const byId = new Map();
  for (const record of lists.flat()) {
    const id = record.id.toLowerCase();
    byId.set(id, newer(byId.get(id), { ...record, id }));
  }
  return [...byId.values()].sort((a, b) => timeOf(b) - timeOf(a));
}

export function liveNotes(records) {
  return records.filter((record) => !record.deletedAt);
}

export function tombstone(record, at = new Date()) {
  const stamp = at.toISOString();
  return { ...record, text: '', updatedAt: stamp, deletedAt: stamp };
}
