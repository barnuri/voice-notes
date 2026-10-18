import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { MIME_TYPES } from '../consts/mime-types.js';
import { SECURITY_HEADERS } from '../consts/security-headers.js';
import { sendError } from '../services/send.js';

const INDEX_FILE = 'index.html';

export async function serveStatic(req, res, { config }) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    sendError(res, 405, 'method not allowed');
    return;
  }
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, 'http://local').pathname);
  } catch {
    sendError(res, 400, 'bad path');
    return;
  }
  const relative = pathname === '/' ? INDEX_FILE : pathname.slice(1);
  const resolved = normalize(join(config.publicDir, relative));
  if (!resolved.startsWith(config.publicDir)) {
    sendError(res, 404, 'not found');
    return;
  }
  const type = MIME_TYPES[extname(resolved)];
  if (!type) {
    sendError(res, 404, 'not found');
    return;
  }
  let content;
  try {
    content = await readFile(resolved);
  } catch {
    sendError(res, 404, 'not found');
    return;
  }
  res.writeHead(200, {
    ...SECURITY_HEADERS,
    'Content-Type': type,
    'Content-Length': content.length,
    'Cache-Control': 'no-cache',
  });
  res.end(req.method === 'HEAD' ? undefined : content);
}
