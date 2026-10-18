import assert from 'node:assert/strict';
import { test } from 'node:test';
import { DEFAULT_LANGUAGE_ID, LANGUAGES, languageById } from '../public/shared/languages.js';

test('ids match the Mac app and unknown ids fall back to the default', () => {
  assert.deepEqual(LANGUAGES.map((l) => l.id), ['hebrewWithEnglish', 'english', 'auto']);
  assert.equal(DEFAULT_LANGUAGE_ID, 'hebrewWithEnglish');
  assert.equal(languageById('nope').id, 'hebrewWithEnglish');
});

test('Hebrew sends a mixed-script prompt so English words stay in English', () => {
  const hebrew = languageById('hebrewWithEnglish');
  assert.equal(hebrew.code, 'he');
  assert.match(hebrew.prompt, /[֐-׿]/);
  assert.match(hebrew.prompt, /deploy/);
  assert.equal(languageById('auto').code, 'auto');
});
