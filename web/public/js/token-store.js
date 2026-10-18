const TOKEN_KEY = 'voicenotes.token';
const HASH_PREFIX = '#token=';

export function readToken(storage) {
  try {
    return storage.getItem(TOKEN_KEY) || '';
  } catch {
    return '';
  }
}

export function saveToken(storage, token) {
  try {
    storage.setItem(TOKEN_KEY, token.trim());
  } catch {
    // Private mode can refuse storage; the token then lasts for this page only.
  }
}

export function clearToken(storage) {
  try {
    storage.removeItem(TOKEN_KEY);
  } catch {
    // Nothing stored to clear.
  }
}

export function takeTokenFromHash(location) {
  if (!location.hash.startsWith(HASH_PREFIX)) {
    return '';
  }
  try {
    return decodeURIComponent(location.hash.slice(HASH_PREFIX.length)).trim();
  } catch {
    return '';
  }
}
