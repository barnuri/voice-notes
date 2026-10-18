import { BodyTooLargeError } from './body-too-large-error.js';

export async function readBody(req, limit) {
  const declared = Number(req.headers['content-length']);
  if (Number.isFinite(declared) && declared > limit) {
    throw new BodyTooLargeError(limit);
  }
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limit) {
      throw new BodyTooLargeError(limit);
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}
