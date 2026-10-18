import { createServer } from 'node:http';
import { handleApi } from './routes/api.js';
import { serveStatic } from './routes/static-files.js';
import { NoteStore } from './services/note-store.js';
import { SettingsStore } from './services/settings-store.js';

const API_PREFIX = '/api/';

export async function startServer(config) {
  const store = await new NoteStore(config.dataFile).load();
  const settings = await new SettingsStore(config.settingsFile, config.models, config.defaultModel).load();
  const deps = { config, store, settings };
  const server = createServer((req, res) => {
    const handler = req.url.startsWith(API_PREFIX) ? handleApi : serveStatic;
    handler(req, res, deps).catch(() => {
      if (!res.headersSent) {
        res.writeHead(500);
      }
      res.end();
    });
  });
  await new Promise((resolve) => server.listen(config.port, config.host, resolve));
  return server;
}
