import { liveNotes, mergeNotes, tombstone } from '../shared/merge-notes.js';
import { appendTranscript, matchesQuery } from './format.js';

export class NotesModel extends EventTarget {
  static #CACHE_KEY = 'voicenotes.records';
  static #EDIT_SYNC_DELAY_MS = 800;
  static #SYNC_INTERVAL_MS = 20_000;
  #records;
  #api;
  #storage;
  #now;
  #editTimer = null;
  #interval = null;
  #syncing = null;
  #resyncRequested = false;
  lastSyncedAt = null;
  syncError = null;

  constructor({ api, storage, now = () => new Date() }) {
    super();
    this.#api = api;
    this.#storage = storage;
    this.#now = now;
    this.#records = NotesModel.#readCache(storage);
  }

  get records() {
    return this.#records;
  }

  list(query = '') {
    return liveNotes(this.#records).filter((note) => matchesQuery(note, query));
  }

  get(id) {
    return liveNotes(this.#records).find((note) => note.id === id) || null;
  }

  create() {
    const stamp = this.#now().toISOString();
    const note = { id: crypto.randomUUID(), text: '', createdAt: stamp, updatedAt: stamp, recordedSeconds: 0 };
    this.#commit([note]);
    return note;
  }

  edit(id, text) {
    this.#change(id, (note) => ({ ...note, text }), NotesModel.#EDIT_SYNC_DELAY_MS);
  }

  appendTranscript(id, transcript) {
    this.#change(id, (note) => ({ ...note, text: appendTranscript(note.text, transcript) }), 0);
  }

  addRecordedSeconds(id, seconds) {
    this.#change(id, (note) => ({ ...note, recordedSeconds: note.recordedSeconds + seconds }), NotesModel.#EDIT_SYNC_DELAY_MS);
  }

  remove(id) {
    const note = this.get(id);
    if (note) {
      this.#commit([tombstone(note, new Date(this.#stampAfter(note)))]);
      this.#scheduleSync(0);
    }
  }

  start() {
    this.syncNow();
    this.#interval = setInterval(() => this.syncNow(), NotesModel.#SYNC_INTERVAL_MS);
  }

  stop() {
    clearInterval(this.#interval);
    clearTimeout(this.#editTimer);
  }

  async syncNow() {
    if (this.#syncing) {
      this.#resyncRequested = true;
      return this.#syncing;
    }
    this.#syncing = this.#runSync();
    try {
      await this.#syncing;
    } finally {
      this.#syncing = null;
    }
    if (this.#resyncRequested) {
      this.#resyncRequested = false;
      await this.syncNow();
    }
  }

  async #runSync() {
    this.#emit('syncstart');
    try {
      const merged = await this.#api.sync(this.#records);
      this.#records = mergeNotes(this.#records, merged);
      NotesModel.#writeCache(this.#storage, this.#records);
      this.lastSyncedAt = this.#now();
      this.syncError = null;
      this.#emit('change');
    } catch (error) {
      this.syncError = error;
    }
    this.#emit('sync');
  }

  #change(id, update, syncDelay) {
    const note = this.get(id);
    if (!note) {
      return;
    }
    this.#commit([{ ...update(note), updatedAt: this.#stampAfter(note) }]);
    this.#scheduleSync(syncDelay);
  }

  #stampAfter(note) {
    return new Date(Math.max(this.#now().getTime(), Date.parse(note.updatedAt) + 1)).toISOString();
  }

  #commit(changed) {
    this.#records = mergeNotes(this.#records, changed);
    NotesModel.#writeCache(this.#storage, this.#records);
    this.#emit('change');
  }

  #scheduleSync(delay) {
    clearTimeout(this.#editTimer);
    this.#editTimer = setTimeout(() => this.syncNow(), delay);
  }

  #emit(type) {
    this.dispatchEvent(new Event(type));
  }

  static #readCache(storage) {
    try {
      const parsed = JSON.parse(storage.getItem(NotesModel.#CACHE_KEY) || '[]');
      return Array.isArray(parsed) ? mergeNotes(parsed) : [];
    } catch {
      return [];
    }
  }

  static #writeCache(storage, records) {
    try {
      storage.setItem(NotesModel.#CACHE_KEY, JSON.stringify(records));
    } catch {
      // Storage full or blocked: the server copy is still the source of truth.
    }
  }
}
