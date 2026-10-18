import { loadConfig } from './services/config.js';
import { startServer } from './server.js';

const config = loadConfig();
const server = await startServer(config);
const { address, port } = server.address();
console.log(`VoiceNotes web on http://${address}:${port} (llm-hub ${config.hubUrl})`);
