import assert from 'node:assert/strict';
import { test } from 'node:test';
import { appDataDir } from '../src/services/app-data-dir.js';

test('uses Application Support on macOS', () => {
  assert.equal(
    appDataDir('darwin', { XDG_DATA_HOME: '/ignored' }, '/Users/me'),
    '/Users/me/Library/Application Support/VoiceNotes',
  );
});

test('uses APPDATA on Windows', () => {
  assert.equal(
    appDataDir('win32', { APPDATA: 'D:\\Profiles\\me\\Roaming' }, 'C:\\Users\\me'),
    'D:\\Profiles\\me\\Roaming\\VoiceNotes',
  );
});

test('falls back to the roaming profile folder on Windows without APPDATA', () => {
  assert.equal(appDataDir('win32', {}, 'C:\\Users\\me'), 'C:\\Users\\me\\AppData\\Roaming\\VoiceNotes');
});

test('uses XDG_DATA_HOME on Linux', () => {
  assert.equal(appDataDir('linux', { XDG_DATA_HOME: '/data/me' }, '/home/me'), '/data/me/voicenotes');
});

test('falls back to ~/.local/share on Linux and other platforms', () => {
  assert.equal(appDataDir('linux', {}, '/home/me'), '/home/me/.local/share/voicenotes');
  assert.equal(appDataDir('freebsd', { XDG_DATA_HOME: '' }, '/home/me'), '/home/me/.local/share/voicenotes');
});
