// Browser-safe: the transcription languages offered in the web UI. No node: imports.

const HEBREW_WITH_ENGLISH_PROMPT = 'שלום, היום עשינו deploy לשרת ושלחנו email לצוות לפני ה-meeting.';

export const LANGUAGES = [
  { id: 'hebrewWithEnglish', title: 'Hebrew + English words', shortTitle: 'עב+EN', code: 'he', prompt: HEBREW_WITH_ENGLISH_PROMPT },
  { id: 'english', title: 'English', shortTitle: 'EN', code: 'en', prompt: null },
  { id: 'auto', title: 'Auto-detect', shortTitle: 'Auto', code: 'auto', prompt: null },
];

export const DEFAULT_LANGUAGE_ID = 'hebrewWithEnglish';

export function languageById(id) {
  return LANGUAGES.find((language) => language.id === id) || languageById(DEFAULT_LANGUAGE_ID);
}
