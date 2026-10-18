import { posix, win32 } from 'node:path';

const APP_DIR = 'VoiceNotes';
const XDG_APP_DIR = 'voicenotes';

export function appDataDir(platform, env, homedir) {
  if (platform === 'darwin') {
    return posix.join(homedir, 'Library', 'Application Support', APP_DIR);
  }
  if (platform === 'win32') {
    const roaming = env.APPDATA || win32.join(homedir, 'AppData', 'Roaming');
    return win32.join(roaming, APP_DIR);
  }
  const dataHome = env.XDG_DATA_HOME || posix.join(homedir, '.local', 'share');
  return posix.join(dataHome, XDG_APP_DIR);
}
