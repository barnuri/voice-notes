import { createHash, timingSafeEqual } from 'node:crypto';

const BEARER_PREFIX = 'Bearer ';

function digest(value) {
  return createHash('sha256').update(value).digest();
}

export function isAuthorized(authorizationHeader, token) {
  if (typeof authorizationHeader !== 'string' || !authorizationHeader.startsWith(BEARER_PREFIX)) {
    return false;
  }
  const presented = authorizationHeader.slice(BEARER_PREFIX.length).trim();
  return timingSafeEqual(digest(presented), digest(token));
}
