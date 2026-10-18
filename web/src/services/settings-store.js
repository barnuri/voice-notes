import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

export class SettingsStore {
  #file;
  #models;
  #model;

  constructor(file, models, defaultModel) {
    this.#file = file;
    this.#models = models;
    this.#model = this.#isKnown(defaultModel) ? defaultModel : models[0].id;
  }

  async load() {
    try {
      const saved = JSON.parse(await readFile(this.#file, 'utf8'));
      if (this.#isKnown(saved.model)) {
        this.#model = saved.model;
      }
    } catch (error) {
      if (error.code !== 'ENOENT') {
        throw new Error(`cannot read ${this.#file}: ${error.message}`);
      }
    }
    return this;
  }

  get model() {
    return this.#model;
  }

  get models() {
    return this.#models;
  }

  async selectModel(id) {
    if (!this.#isKnown(id)) {
      return false;
    }
    this.#model = id;
    await mkdir(dirname(this.#file), { recursive: true });
    const temp = `${this.#file}.tmp`;
    await writeFile(temp, JSON.stringify({ model: id }, null, 2), { mode: 0o600 });
    await rename(temp, this.#file);
    return true;
  }

  #isKnown(id) {
    return this.#models.some((model) => model.id === id);
  }
}
