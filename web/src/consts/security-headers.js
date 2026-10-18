export const SECURITY_HEADERS = {
  'Content-Security-Policy': [
    "default-src 'self'",
    "media-src 'self' blob:",
    "img-src 'self' data:",
    "frame-ancestors 'self' http://*:1111 https://*:1111",
  ].join('; '),
  'Permissions-Policy': 'microphone=(self)',
  'Referrer-Policy': 'no-referrer',
  'X-Content-Type-Options': 'nosniff',
};
