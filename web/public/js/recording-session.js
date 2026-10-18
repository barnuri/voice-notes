import { SpeechChunker } from '../shared/speech-chunker.js';

export class RecordingSession extends EventTarget {
  static #MIC_DENIED_MESSAGE = 'VoiceNotes can’t use the microphone. Allow it for this site in your browser settings.';
  static #MIC_UNAVAILABLE_MESSAGE = 'The microphone needs a secure (https) connection.';
  static #TICK_MS = 100;
  static #EMPTY_RESULT_MESSAGE = 'Whisper heard speech but returned no text. Try again, or check the language picker.';

  phase = 'idle';
  noteId = null;
  pending = 0;
  failed = [];
  error = null;
  #elapsedBefore = 0;
  #segmentStartedAt = null;
  #chunker = new SpeechChunker();
  #ticker = null;
  #rotating = false;
  #mic;
  #notes;
  #api;
  #model;
  #language;
  #queue = Promise.resolve();
  #now;

  constructor({ mic, notes, api, model, language, now = () => performance.now() }) {
    super();
    this.#mic = mic;
    this.#notes = notes;
    this.#api = api;
    this.#model = model;
    this.#language = language;
    this.#now = now;
  }

  get elapsedSeconds() {
    const running = this.#segmentStartedAt === null ? 0 : (this.#now() - this.#segmentStartedAt) / 1000;
    return this.#elapsedBefore + running;
  }

  isRecordingInto(id) {
    return this.phase !== 'idle' && this.noteId === id;
  }

  async toggle(selectedId) {
    if (this.phase === 'idle') {
      await this.record(selectedId);
    } else if (this.phase === 'recording') {
      await this.pause();
    } else {
      this.resume();
    }
  }

  async record(selectedId) {
    if (this.phase !== 'idle') {
      return;
    }
    try {
      await this.#mic.open();
    } catch (error) {
      const denied = error?.name === 'NotAllowedError';
      this.#fail(denied ? RecordingSession.#MIC_DENIED_MESSAGE : RecordingSession.#MIC_UNAVAILABLE_MESSAGE);
      return;
    }
    this.noteId = (selectedId && this.#notes.get(selectedId)?.id) || this.#notes.create().id;
    this.#elapsedBefore = 0;
    this.#startSegment();
  }

  async pause() {
    if (this.phase !== 'recording') {
      return;
    }
    this.phase = 'paused';
    await this.#closeSegment();
  }

  resume() {
    if (this.phase === 'paused') {
      this.#startSegment();
    }
  }

  async finish() {
    const wasRecording = this.phase === 'recording';
    this.phase = 'idle';
    if (wasRecording) {
      await this.#closeSegment();
    }
    this.#mic.close();
    this.#elapsedBefore = 0;
    this.#emit();
  }

  retry() {
    const retries = this.failed;
    this.failed = [];
    this.error = null;
    retries.forEach((segment) => this.#enqueue(segment));
    this.#emit();
  }

  dismissError() {
    this.error = null;
    this.#emit();
  }

  async tick() {
    if (this.phase !== 'recording' || this.#rotating) {
      return;
    }
    if (!this.#chunker.observe(this.#mic.level(), this.#now())) {
      return;
    }
    this.#rotating = true;
    const hadSpeech = this.#chunker.hasSpeech;
    this.#chunker.reset(this.#now());
    try {
      this.#keep(await this.#mic.rotate(), hadSpeech);
    } finally {
      this.#rotating = false;
    }
  }

  #startSegment() {
    this.#mic.startSegment();
    this.#segmentStartedAt = this.#now();
    this.#chunker.reset(this.#segmentStartedAt);
    this.phase = 'recording';
    this.error = null;
    clearInterval(this.#ticker);
    this.#ticker = setInterval(() => this.tick(), RecordingSession.#TICK_MS);
    this.#emit();
  }

  async #closeSegment() {
    clearInterval(this.#ticker);
    this.#ticker = null;
    this.#elapsedBefore = this.elapsedSeconds;
    this.#segmentStartedAt = null;
    const hadSpeech = this.#chunker.hasSpeech;
    this.#emit();
    this.#keep(await this.#mic.stopSegment(), hadSpeech);
  }

  #keep(segment, hadSpeech) {
    if (!segment || !this.noteId) {
      return;
    }
    this.#notes.addRecordedSeconds(this.noteId, segment.seconds);
    this.#enqueue({ ...segment, noteId: this.noteId, hadSpeech });
  }

  #enqueue(segment) {
    this.pending += 1;
    this.#emit();
    this.#queue = this.#queue.then(() => this.#transcribe(segment));
    return this.#queue;
  }

  async #transcribe(segment) {
    try {
      const text = await this.#api.transcribe(segment.blob, this.#model(), segment.filename, this.#language());
      if (!text && segment.hadSpeech) {
        throw new Error(RecordingSession.#EMPTY_RESULT_MESSAGE);
      }
      this.#notes.appendTranscript(segment.noteId, text);
    } catch (error) {
      this.failed.push(segment);
      this.error = error.message;
    } finally {
      this.pending -= 1;
      this.#emit();
    }
  }

  #fail(message) {
    this.error = message;
    this.#emit();
  }

  #emit() {
    this.dispatchEvent(new Event('change'));
  }
}
