import { ApiClient } from './api-client.js';
import { copyText } from './clipboard.js';
import { formatDuration, noteTitle, relativeTime } from './format.js';
import { LevelWaveform } from './level-waveform.js';
import { MicRecorder } from './mic-recorder.js';
import { NotesModel } from './notes-model.js';
import { RecordingSession } from './recording-session.js';
import { clearToken, readToken, saveToken, takeTokenFromHash } from './token-store.js';
import { DEFAULT_LANGUAGE_ID, LANGUAGES, languageById } from '../shared/languages.js';

const DEFAULT_MODEL = 'whisper/whisper-large-v3';
const COPIED_FEEDBACK_MS = 1500;
const RING_LENGTH = 182.2;
const MIN_RING_LEVEL = 0.04;
const LANGUAGE_KEY = 'voicenotes.language';
const MIC_KEY = 'voicenotes.mic';
const DEFAULT_MIC_LABEL = 'Default microphone';
const CONFIG_CHECK_MS = 20_000;
const UPDATE_MESSAGE = 'VoiceNotes was updated. Reload to get the new version.';
const ICONS = {
  mic: '<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10a7 7 0 0 0 14 0h-2a5 5 0 0 1-10 0H5zM11 19h2v3h-2z"/>',
  pause: '<rect x="6" y="4" width="4" height="16" rx="1.5"/><rect x="14" y="4" width="4" height="16" rx="1.5"/>',
};
const PHASE_TEXT = {
  idle: { title: 'Ready', action: 'Start recording' },
  recording: { title: 'Listening', action: 'Pause' },
  paused: { title: 'Paused', action: 'Resume' },
};

const $ = (id) => document.getElementById(id);
const els = {
  tokenScreen: $('token-screen'), tokenForm: $('token-form'), tokenInput: $('token-input'), tokenError: $('token-error'),
  app: $('app'), newNote: $('new-note'), search: $('search'), list: $('note-list'), listEmpty: $('list-empty'),
  syncStatus: $('sync-status'), back: $('back'), meta: $('note-meta'), deleteNote: $('delete-note'),
  copyTop: $('copy-top'), copy: $('copy'), banner: $('banner'), bannerText: $('banner-text'),
  bannerLink: $('banner-link'), bannerRetry: $('banner-retry'), bannerDismiss: $('banner-dismiss'),
  editor: $('editor'), editorEmpty: $('editor-empty'), record: $('record'), recordIcon: $('record-icon'),
  ringLevel: $('ring-level'), statusTitle: $('status-title'), statusDetail: $('status-detail'),
  pause: $('pause'), done: $('done'), language: $('language'), waveform: $('waveform'),
  model: $('model'), modelDescription: $('model-description'), mic: $('mic'),
};

let notes;
let session;
let mic;
let publicUrl = '';
let modelId = DEFAULT_MODEL;
let models = [];
let selectedId = null;
let query = '';
let frame = null;
let languageId = readLanguage();
const waveform = new LevelWaveform(els.waveform);
let waveformPhase = 'idle';

function showTokenScreen(message = '') {
  els.app.hidden = true;
  els.tokenScreen.hidden = false;
  els.tokenError.hidden = !message;
  els.tokenError.textContent = message;
  els.tokenInput.focus();
}

async function connect(token) {
  const api = new ApiClient(token);
  try {
    return { api, config: await api.config() };
  } catch (error) {
    if (error.isUnauthorized) {
      return { error: 'That token didn’t work. Copy it again from your Mac.' };
    }
    return { api, config: { model: DEFAULT_MODEL, publicUrl: '' }, offline: error.message };
  }
}

async function boot() {
  const fromLink = takeTokenFromHash(location);
  if (fromLink) {
    saveToken(localStorage, fromLink);
    history.replaceState(null, '', location.pathname + location.search);
  }
  const token = readToken(localStorage);
  const result = await connect(token);
  if (result.error) {
    clearToken(localStorage);
    showTokenScreen(result.error);
    return;
  }
  startApp(result);
}

function startApp({ api, config, offline }) {
  publicUrl = config.publicUrl || '';
  applyModels(config);
  mic = new MicRecorder();
  mic.deviceId = readStored(MIC_KEY);
  setupMicPicker();
  notes = new NotesModel({ api, storage: localStorage });
  session = new RecordingSession({
    mic, notes, api, model: () => modelId, language: () => languageById(languageId),
  });
  notes.addEventListener('change', render);
  notes.addEventListener('sync', handleSyncResult);
  notes.addEventListener('syncstart', renderSync);
  session.addEventListener('change', render);
  selectedId = notes.list()[0]?.id ?? null;
  els.tokenScreen.hidden = true;
  els.app.hidden = false;
  notes.start();
  setupModelPicker(api);
  watchConfig(api, config.version);
  if (offline) {
    session.error = offline;
  }
  render();
}

function watchConfig(api, loadedVersion) {
  setInterval(async () => {
    const latest = await api.config().catch(() => null);
    if (!latest) {
      return;
    }
    applyModels(latest);
    const outdated = loadedVersion && latest.version && latest.version !== loadedVersion;
    if (outdated && session.phase === 'idle' && session.pending === 0) {
      session.error = UPDATE_MESSAGE;
      render();
    }
  }, CONFIG_CHECK_MS);
}

function applyModels(config) {
  if (Array.isArray(config.models) && config.models.length) {
    models = config.models;
  }
  if (config.model) {
    modelId = config.model;
  }
  renderModelPicker();
}

function renderModelPicker() {
  const options = models.length ? models : [{ id: modelId, title: modelId, description: '' }];
  if (els.model.options.length !== options.length) {
    els.model.replaceChildren(...options.map((model) => new Option(model.title, model.id)));
  }
  els.model.value = modelId;
  els.modelDescription.textContent = options.find((model) => model.id === modelId)?.description ?? '';
}

function readStored(key) {
  try {
    return localStorage.getItem(key) || '';
  } catch {
    return '';
  }
}

async function renderMicPicker() {
  const inputs = await MicRecorder.listInputs().catch(() => []);
  const selected = mic.activeDeviceId || mic.deviceId;
  const options = [new Option(DEFAULT_MIC_LABEL, ''), ...inputs.map((input) => new Option(input.label, input.id))];
  els.mic.replaceChildren(...options);
  els.mic.value = inputs.some((input) => input.id === selected) ? selected : '';
  els.mic.disabled = session?.phase !== 'idle';
}

function setupMicPicker() {
  renderMicPicker();
  navigator.mediaDevices?.addEventListener?.('devicechange', renderMicPicker);
  els.mic.addEventListener('change', () => {
    mic.deviceId = els.mic.value;
    try {
      localStorage.setItem(MIC_KEY, mic.deviceId);
    } catch {
      // The choice then lasts for this page only.
    }
  });
}

function setupModelPicker(api) {
  els.model.addEventListener('change', async () => {
    const chosen = els.model.value;
    const previous = modelId;
    modelId = chosen;
    renderModelPicker();
    try {
      modelId = await api.selectModel(chosen);
    } catch (error) {
      modelId = previous;
      session.error = `Couldn’t switch model: ${error.message}`;
      render();
    }
    renderModelPicker();
  });
}

function handleSyncResult() {
  if (notes.syncError?.isUnauthorized) {
    notes.stop();
    clearToken(localStorage);
    showTokenScreen('The access token changed. Paste the new one from your Mac.');
    return;
  }
  renderSync();
}

function readLanguage() {
  try {
    return languageById(localStorage.getItem(LANGUAGE_KEY) || DEFAULT_LANGUAGE_ID).id;
  } catch {
    return DEFAULT_LANGUAGE_ID;
  }
}

function setupLanguagePicker() {
  els.language.replaceChildren(...LANGUAGES.map((language) => new Option(language.title, language.id)));
  els.language.value = languageId;
  els.language.addEventListener('change', () => {
    languageId = languageById(els.language.value).id;
    try {
      localStorage.setItem(LANGUAGE_KEY, languageId);
    } catch {
      // The choice then lasts for this page only.
    }
  });
}

function selectedNote() {
  return selectedId ? notes.get(selectedId) : null;
}

function render() {
  if (selectedId && !notes.get(selectedId)) {
    selectedId = session.noteId && notes.get(session.noteId) ? session.noteId : null;
  }
  if (session.phase !== 'idle' && session.noteId) {
    selectedId = session.noteId;
  }
  renderList();
  renderEditor();
  renderBar();
  renderBanner();
  renderSync();
  scheduleFrame();
}

function renderList() {
  const items = notes.list(query);
  els.list.replaceChildren(...items.map(noteItem));
  els.listEmpty.hidden = items.length > 0;
  els.listEmpty.textContent = query ? 'No matches. Try a different word.' : 'No notes yet. Press record to make your first one.';
}

function noteItem(note) {
  const item = document.createElement('li');
  item.className = 'note-item';
  item.role = 'option';
  item.tabIndex = 0;
  item.dataset.id = note.id;
  item.setAttribute('aria-selected', String(note.id === selectedId));

  const title = document.createElement('div');
  title.className = 'note-title';
  if (session.isRecordingInto(note.id)) {
    const dot = document.createElement('i');
    dot.className = 'live-dot';
    dot.setAttribute('aria-label', 'Recording');
    title.append(dot);
  }
  const text = document.createElement('span');
  text.dir = 'auto';
  text.textContent = noteTitle(note);
  title.append(text);

  const sub = document.createElement('div');
  sub.className = 'note-sub';
  sub.append(relativeTime(note.updatedAt));
  if (note.recordedSeconds > 0) {
    const length = document.createElement('span');
    length.textContent = formatDuration(note.recordedSeconds);
    sub.append(length);
  }
  item.append(title, sub);
  return item;
}

function renderEditor() {
  const note = selectedNote();
  els.editorEmpty.hidden = Boolean(note);
  els.editor.disabled = !note;
  els.deleteNote.hidden = !note;
  els.deleteNote.disabled = Boolean(note && session.isRecordingInto(note.id));
  els.meta.textContent = note ? noteMeta(note) : '';
  const text = note?.text ?? '';
  if (els.editor.value !== text) {
    const { selectionStart, selectionEnd } = els.editor;
    const wasFocused = document.activeElement === els.editor;
    els.editor.value = text;
    if (wasFocused) {
      els.editor.setSelectionRange(selectionStart, selectionEnd);
    }
  }
  for (const button of [els.copy, els.copyTop]) {
    button.disabled = !text;
  }
}

function noteMeta(note) {
  const created = new Date(note.createdAt).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
  return note.recordedSeconds > 0 ? `${created} · ${formatDuration(note.recordedSeconds)} recorded` : created;
}

function renderBar() {
  const phase = PHASE_TEXT[session.phase];
  els.record.dataset.phase = session.phase;
  els.record.setAttribute('aria-label', phase.action);
  els.record.title = `${phase.action} (Ctrl/⌘ Enter)`;
  els.recordIcon.innerHTML = session.phase === 'recording' ? ICONS.pause : ICONS.mic;
  els.pause.hidden = session.phase === 'idle';
  els.pause.textContent = phase.action;
  els.done.hidden = session.phase === 'idle';
  els.waveform.hidden = session.phase === 'idle';
  els.waveform.dataset.phase = session.phase;
  if (waveformPhase === 'idle' && session.phase === 'recording') {
    waveform.reset();
  }
  if (waveformPhase !== session.phase) {
    renderMicPicker();
  }
  waveformPhase = session.phase;
  els.statusTitle.textContent = session.phase === 'idle' && session.pending > 0 ? 'Almost done' : phase.title;
  renderStatusDetail();
}

function renderStatusDetail() {
  const parts = [];
  if (session.phase !== 'idle') {
    parts.push(formatDuration(session.elapsedSeconds));
  }
  els.statusDetail.replaceChildren(parts.join(''));
  if (session.pending > 0) {
    const spinner = document.createElement('i');
    spinner.className = 'spinner';
    spinner.setAttribute('aria-hidden', 'true');
    els.statusDetail.append(parts.length ? '  ' : '', spinner, 'Writing it down…');
  }
}

function renderBanner() {
  const insecure = !MicRecorder.isAvailable();
  const message = session.error || (insecure ? micHelpText() : '');
  els.banner.hidden = !message;
  els.bannerText.textContent = message;
  els.bannerRetry.hidden = session.failed.length === 0;
  els.bannerDismiss.hidden = !session.error;
  const isUpdate = session.error === UPDATE_MESSAGE;
  const showSecureLink = !isUpdate && insecure && Boolean(publicUrl) && !location.href.startsWith(publicUrl);
  els.bannerLink.hidden = !(isUpdate || showSecureLink);
  els.bannerLink.textContent = isUpdate ? 'Reload' : 'Open securely';
  els.bannerLink.href = isUpdate ? location.pathname : publicUrl;
  els.bannerLink.target = isUpdate ? '_self' : '_blank';
  els.bannerLink.rel = 'noopener';
}

function micHelpText() {
  if (!globalThis.isSecureContext) {
    return publicUrl
      ? 'Recording needs a secure connection. Open VoiceNotes at its https address to use the microphone.'
      : 'Recording needs a secure (https) connection. You can still read and edit notes here.';
  }
  return 'This browser can’t record audio. You can still read and edit notes here.';
}

function renderSync() {
  els.syncStatus.classList.toggle('error', Boolean(notes.syncError));
  if (notes.syncError) {
    els.syncStatus.textContent = `Not synced: ${notes.syncError.message}`;
  } else if (notes.lastSyncedAt) {
    els.syncStatus.textContent = `Synced ${relativeTime(notes.lastSyncedAt.toISOString())} · same notes as your Mac`;
  } else {
    els.syncStatus.textContent = 'Syncing…';
  }
}

function scheduleFrame() {
  if (frame !== null || session.phase !== 'recording') {
    if (session.phase !== 'recording') {
      els.ringLevel.style.strokeDashoffset = String(RING_LENGTH);
    }
    return;
  }
  frame = requestAnimationFrame(() => {
    frame = null;
    const level = Math.max(MIN_RING_LEVEL, mic.level());
    els.ringLevel.style.strokeDashoffset = String(RING_LENGTH * (1 - level));
    waveform.push(mic.level());
    renderStatusDetail();
    scheduleFrame();
  });
}

function select(id) {
  if (session.phase !== 'idle' && id !== session.noteId) {
    return;
  }
  selectedId = id;
  els.app.dataset.view = 'note';
  render();
}

async function copyCurrent(button) {
  const text = selectedNote()?.text ?? '';
  if (!text) {
    return;
  }
  const copied = await copyText(text, els.editor);
  for (const target of [els.copy, els.copyTop]) {
    target.classList.toggle('copied', copied);
    target.querySelector('span').textContent = copied ? 'Copied' : 'Copy text';
  }
  if (!copied) {
    session.error = 'Copy didn’t work here. Select the text and copy it manually.';
    render();
    return;
  }
  button.focus();
  setTimeout(() => {
    for (const target of [els.copy, els.copyTop]) {
      target.classList.remove('copied');
      target.querySelector('span').textContent = 'Copy text';
    }
  }, COPIED_FEEDBACK_MS);
}

function wireEvents() {
  els.tokenForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const token = els.tokenInput.value.trim();
    const result = await connect(token);
    if (result.error) {
      showTokenScreen(result.error);
      return;
    }
    saveToken(localStorage, token);
    els.tokenInput.value = '';
    startApp(result);
  });
  els.newNote.addEventListener('click', () => {
    if (session.phase !== 'idle') {
      return;
    }
    select(notes.create().id);
    els.editor.focus();
  });
  els.search.addEventListener('input', () => {
    query = els.search.value;
    renderList();
  });
  els.list.addEventListener('click', (event) => {
    const item = event.target.closest('.note-item');
    if (item) {
      select(item.dataset.id);
    }
  });
  els.list.addEventListener('keydown', (event) => {
    const item = event.target.closest('.note-item');
    if (item && (event.key === 'Enter' || event.key === ' ')) {
      event.preventDefault();
      select(item.dataset.id);
    }
  });
  els.back.addEventListener('click', () => {
    els.app.dataset.view = 'list';
  });
  els.editor.addEventListener('input', () => {
    if (selectedId) {
      notes.edit(selectedId, els.editor.value);
    }
  });
  els.deleteNote.addEventListener('click', () => {
    const note = selectedNote();
    if (!note || session.isRecordingInto(note.id)) {
      return;
    }
    if (!confirm(`Delete “${noteTitle(note)}”? This removes it from every device.`)) {
      return;
    }
    notes.remove(note.id);
    selectedId = null;
    els.app.dataset.view = 'list';
    render();
  });
  els.record.addEventListener('click', () => session.toggle(selectedId));
  els.pause.addEventListener('click', () => session.toggle(selectedId));
  els.done.addEventListener('click', () => session.finish());
  els.copy.addEventListener('click', () => copyCurrent(els.copy));
  els.copyTop.addEventListener('click', () => copyCurrent(els.copyTop));
  els.bannerRetry.addEventListener('click', () => session.retry());
  els.bannerDismiss.addEventListener('click', () => session.dismissError());
  document.addEventListener('keydown', (event) => {
    if (!session || !(event.metaKey || event.ctrlKey)) {
      return;
    }
    if (event.key === 'Enter') {
      event.preventDefault();
      if (event.shiftKey) {
        session.finish();
      } else {
        session.toggle(selectedId);
      }
    } else if (event.shiftKey && event.key.toLowerCase() === 'c') {
      event.preventDefault();
      copyCurrent(els.copy);
    }
  });
  document.addEventListener('visibilitychange', () => {
    if (notes && document.visibilityState === 'visible') {
      notes.syncNow();
    }
  });
  window.addEventListener('beforeunload', (event) => {
    if (session && (session.phase !== 'idle' || session.pending > 0)) {
      event.preventDefault();
    }
  });
}

setupLanguagePicker();
wireEvents();
boot();
