export class BodyTooLargeError extends Error {
  constructor(limit) {
    super(`request body exceeds ${limit} bytes`);
    this.limit = limit;
  }
}
