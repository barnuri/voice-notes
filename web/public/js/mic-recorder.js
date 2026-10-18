export class MicRecorder {
  static #PREFERRED_TYPES = ['audio/webm;codecs=opus', 'audio/mp4', 'audio/webm', 'audio/ogg;codecs=opus'];
  static #SILENCE_FLOOR = 0.02;
  static #LEVEL_GAIN = 4;
  static #ANALYSER_FFT_SIZE = 1024;
  #stream = null;
  #context = null;
  #analyser = null;
  #samples = null;
  #segment = null;

  static isAvailable() {
    return Boolean(globalThis.isSecureContext && navigator.mediaDevices?.getUserMedia && globalThis.MediaRecorder);
  }

  #deviceId = '';

  get isOpen() {
    return this.#stream !== null;
  }

  get deviceId() {
    return this.#deviceId;
  }

  set deviceId(id) {
    this.#deviceId = id || '';
  }

  get activeDeviceId() {
    return this.#stream?.getAudioTracks()[0]?.getSettings().deviceId ?? '';
  }

  static async listInputs() {
    if (!navigator.mediaDevices?.enumerateDevices) {
      return [];
    }
    const devices = await navigator.mediaDevices.enumerateDevices();
    return devices
      .filter((device) => device.kind === 'audioinput' && device.deviceId)
      .map((device, index) => ({ id: device.deviceId, label: device.label || `Microphone ${index + 1}` }));
  }

  async open() {
    if (this.#stream) {
      return;
    }
    const audio = { echoCancellation: true, noiseSuppression: true };
    if (this.#deviceId) {
      audio.deviceId = { ideal: this.#deviceId };
    }
    this.#stream = await navigator.mediaDevices.getUserMedia({ audio });
    this.#context = new AudioContext();
    this.#analyser = this.#context.createAnalyser();
    this.#analyser.fftSize = MicRecorder.#ANALYSER_FFT_SIZE;
    this.#samples = new Float32Array(this.#analyser.fftSize);
    this.#context.createMediaStreamSource(this.#stream).connect(this.#analyser);
  }

  startSegment() {
    const mimeType = MicRecorder.#PREFERRED_TYPES.find((type) => MediaRecorder.isTypeSupported(type)) || '';
    const recorder = new MediaRecorder(this.#stream, mimeType ? { mimeType } : undefined);
    const chunks = [];
    recorder.addEventListener('dataavailable', (event) => {
      if (event.data.size > 0) {
        chunks.push(event.data);
      }
    });
    recorder.start();
    this.#segment = { recorder, chunks, startedAt: performance.now() };
  }

  stopSegment() {
    const segment = this.#segment;
    this.#segment = null;
    return MicRecorder.#finish(segment);
  }

  rotate() {
    const finished = this.#segment;
    this.startSegment();
    return MicRecorder.#finish(finished);
  }

  static #finish(segment) {
    if (!segment) {
      return Promise.resolve(null);
    }
    const { recorder, chunks, startedAt } = segment;
    const seconds = (performance.now() - startedAt) / 1000;
    return new Promise((resolve) => {
      recorder.addEventListener('stop', () => {
        const type = recorder.mimeType || 'audio/webm';
        resolve({ blob: new Blob(chunks, { type }), seconds, filename: `segment.${MicRecorder.#extensionFor(type)}` });
      }, { once: true });
      recorder.stop();
    });
  }

  level() {
    if (!this.#analyser || !this.#segment) {
      return 0;
    }
    this.#analyser.getFloatTimeDomainData(this.#samples);
    let sum = 0;
    for (const sample of this.#samples) {
      sum += sample * sample;
    }
    const rms = Math.sqrt(sum / this.#samples.length);
    return Math.min(1, Math.max(0, (rms - MicRecorder.#SILENCE_FLOOR) * MicRecorder.#LEVEL_GAIN));
  }

  close() {
    this.#stream?.getTracks().forEach((track) => track.stop());
    this.#context?.close();
    this.#stream = null;
    this.#context = null;
    this.#analyser = null;
  }

  static #extensionFor(type) {
    if (type.includes('mp4')) {
      return 'm4a';
    }
    return type.includes('ogg') ? 'ogg' : 'webm';
  }
}
