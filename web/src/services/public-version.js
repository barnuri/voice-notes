import { readdir, stat } from 'node:fs/promises';
import { join } from 'node:path';

export async function publicVersion(directory) {
  const entries = await readdir(directory, { recursive: true, withFileTypes: true });
  const times = await Promise.all(
    entries.filter((entry) => entry.isFile()).map(async (entry) => (await stat(join(entry.parentPath, entry.name))).mtimeMs),
  );
  return String(Math.max(0, ...times.map(Math.floor)));
}
