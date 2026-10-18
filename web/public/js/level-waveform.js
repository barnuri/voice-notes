export class LevelWaveform {
  static #SAMPLE_MS = 70;
  static #BAR_WIDTH = 3;
  static #BAR_GAP = 2;
  static #MIN_BAR_HEIGHT = 3;
  static #LEVEL_CURVE = 0.6;

  #canvas;
  #context;
  #samples = [];
  #lastSampleAt = 0;

  constructor(canvas) {
    this.#canvas = canvas;
    this.#context = canvas.getContext('2d');
  }

  reset() {
    this.#samples = [];
    this.#lastSampleAt = 0;
    this.#draw();
  }

  push(level, now = performance.now()) {
    if (now - this.#lastSampleAt < LevelWaveform.#SAMPLE_MS) {
      return;
    }
    this.#lastSampleAt = now;
    this.#samples.push(level);
    const capacity = this.#capacity();
    if (this.#samples.length > capacity) {
      this.#samples.splice(0, this.#samples.length - capacity);
    }
    this.#draw();
  }

  #capacity() {
    const width = this.#canvas.clientWidth || this.#canvas.width;
    return Math.max(1, Math.floor(width / (LevelWaveform.#BAR_WIDTH + LevelWaveform.#BAR_GAP)));
  }

  #draw() {
    const ratio = globalThis.devicePixelRatio || 1;
    const width = this.#canvas.clientWidth;
    const height = this.#canvas.clientHeight;
    if (this.#canvas.width !== width * ratio || this.#canvas.height !== height * ratio) {
      this.#canvas.width = width * ratio;
      this.#canvas.height = height * ratio;
    }
    const context = this.#context;
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);
    context.fillStyle = getComputedStyle(this.#canvas).color;
    const step = LevelWaveform.#BAR_WIDTH + LevelWaveform.#BAR_GAP;
    const capacity = this.#capacity();
    const offset = capacity - this.#samples.length;
    this.#samples.forEach((level, index) => {
      const shaped = Math.pow(Math.min(1, Math.max(0, level)), LevelWaveform.#LEVEL_CURVE);
      const barHeight = Math.max(LevelWaveform.#MIN_BAR_HEIGHT, shaped * height);
      const x = (offset + index) * step;
      const y = (height - barHeight) / 2;
      context.beginPath();
      context.roundRect(x, y, LevelWaveform.#BAR_WIDTH, barHeight, LevelWaveform.#BAR_WIDTH / 2);
      context.fill();
    });
  }
}
