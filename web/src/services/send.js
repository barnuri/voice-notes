import { SECURITY_HEADERS } from '../consts/security-headers.js';

export function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    ...SECURITY_HEADERS,
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

export function sendError(res, status, message) {
  sendJson(res, status, { error: message });
}
