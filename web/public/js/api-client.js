import { ApiError } from './api-error.js';

export class ApiClient {
  static #UNREACHABLE_MESSAGE = "Can't reach the VoiceNotes server. Check that your Mac is awake and online.";
  #token;
  #fetch;

  constructor(token, fetchImpl = globalThis.fetch.bind(globalThis)) {
    this.#token = token;
    this.#fetch = fetchImpl;
  }

  config() {
    return this.#request('/api/config');
  }

  async selectModel(id) {
    const body = await this.#request('/api/settings', {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ model: id }),
    });
    return body.model;
  }

  async sync(records) {
    const body = await this.#request('/api/sync', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ notes: records }),
    });
    return body.notes;
  }

  async transcribe(blob, model, filename, language) {
    const form = new FormData();
    form.append('model', model);
    form.append('response_format', 'json');
    if (language?.code) {
      form.append('language', language.code);
    }
    if (language?.prompt) {
      form.append('prompt', language.prompt);
    }
    form.append('file', blob, filename);
    const body = await this.#request('/api/transcribe', { method: 'POST', body: form });
    return (body.text || '').trim();
  }

  async #request(path, init = {}) {
    let response;
    try {
      const headers = { ...init.headers };
      if (this.#token) {
        headers.authorization = `Bearer ${this.#token}`;
      }
      response = await this.#fetch(path, {
        ...init,
        headers,
      });
    } catch {
      throw new ApiError(0, ApiClient.#UNREACHABLE_MESSAGE);
    }
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new ApiError(response.status, ApiClient.#errorText(body, response.status));
    }
    return body;
  }

  static #errorText(body, status) {
    if (typeof body.error === 'string') {
      return body.error;
    }
    if (body.error && typeof body.error.message === 'string') {
      return body.error.message;
    }
    return `The server answered ${status}.`;
  }
}
