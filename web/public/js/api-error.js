export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }

  get isUnauthorized() {
    return this.status === 401;
  }
}
