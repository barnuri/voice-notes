// Browser-safe: decides when a live recording chunk is ready to transcribe. No node: imports.

export class SpeechChunker {
  static VOICE_LEVEL = 0.03;
  static MIN_CHUNK_MS = 5000;
  static SILENCE_GAP_MS = 700;
  static LONG_CHUNK_MS = 12_000;
  static WORD_GAP_MS = 250;
  static MAX_CHUNK_MS = 20_000;

  #startedAt = 0;
  #lastSpeechAt = 0;
  hasSpeech = false;

  reset(now) {
    this.#startedAt = now;
    this.#lastSpeechAt = now;
    this.hasSpeech = false;
  }

  observe(level, now) {
    if (level >= SpeechChunker.VOICE_LEVEL) {
      this.hasSpeech = true;
      this.#lastSpeechAt = now;
    }
    const age = now - this.#startedAt;
    if (age >= SpeechChunker.MAX_CHUNK_MS) {
      return true;
    }
    const quietFor = now - this.#lastSpeechAt;
    if (!this.hasSpeech || age < SpeechChunker.MIN_CHUNK_MS) {
      return false;
    }
    const sentenceEnded = quietFor >= SpeechChunker.SILENCE_GAP_MS;
    const longEnoughForWordGap = age >= SpeechChunker.LONG_CHUNK_MS && quietFor >= SpeechChunker.WORD_GAP_MS;
    return sentenceEnded || longEnoughForWordGap;
  }
}
