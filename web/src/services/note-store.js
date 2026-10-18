import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { mergeNotes } from '../../public/shared/merge-notes.js';

export class NoteStore {
  #file;
  #records = [];
  #queue = Promise.resolve();

  constructor(file) {
    this.#file = file;
  }

  async load() {
    try {
      const parsed = JSON.parse(await readFile(this.#file, 'utf8'));
      this.#records = Array.isArray(parsed.notes) ? mergeNotes(parsed.notes) : [];
    } catch (error) {
      if (error.code !== 'ENOENT') {
        throw new Error(`cannot read ${this.#file}: ${error.message}`);
      }
    }
    return this;
  }

  get records() {
    return this.#records;
  }

  sync(incoming) {
    const run = this.#queue.then(async () => {
      this.#records = mergeNotes(this.#records, incoming);
      await this.#save();
      return this.#records;
    });
    this.#queue = run.catch(() => {});
    return run;
  }

  async #save() {
    await mkdir(dirname(this.#file), { recursive: true });
    const temp = `${this.#file}.tmp`;
    await writeFile(temp, JSON.stringify({ notes: this.#records }, null, 2), { mode: 0o600 });
    await rename(temp, this.#file);
  }
}
