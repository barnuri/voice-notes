# VoiceNotes

Speech-to-text notes and dictation for macOS and Windows, with a web app for any browser.
Transcription runs on any OpenAI-compatible `/v1/audio/transcriptions` endpoint, so your audio
can stay on your own machine.

- **Mac app**: records notes and transcribes them while you talk. A global shortcut types
  what you say into the active app, chunk by chunk. While you dictate, a floating pill shows
  the level and has pause and stop buttons.
- **Windows app** (`windows/`): a tray app with the same dictation shortcut, live typing and
  floating pill.
- **Web app** (`web/`): the same notes in a browser or an installable PWA. It syncs with the
  Mac app through a small Node server.
- **Languages**: Hebrew with English words typed as spoken, English, or auto-detect.

## Transcription backend

The app and the web server send audio to one base URL and choose a model by id.

### Option A: llm-hub (recommended for local models)

[llm-hub](https://github.com/barnuri/llm-hub) is a local OpenAI-compatible gateway. It can
start a `whisper-server` for each model when the first request arrives, and stop it when the
model is idle. Its README section "Local speech-to-text" shows the profile setup.

The defaults of VoiceNotes match these llm-hub profiles:

| Model id | Weights | Use |
|---|---|---|
| `ivrit/ivrit-large-v3-turbo` | [ivrit-ai/whisper-large-v3-turbo-ggml](https://huggingface.co/ivrit-ai/whisper-large-v3-turbo-ggml) | Hebrew, fast |
| `ivrit_large/ivrit-large-v3` | [ivrit-ai/whisper-large-v3-ggml](https://huggingface.co/ivrit-ai/whisper-large-v3-ggml) | Hebrew, slower |
| `whisper/whisper-large-v3` | [ggml-large-v3.bin](https://huggingface.co/ggerganov/whisper.cpp) | English and other languages |
| `parakeet/mlx-community/parakeet-tdt-0.6b-v2` | [parakeet-tdt-0.6b-v2](https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v2) on [mlx-audio](https://github.com/Blaizzy/mlx-audio) | English only, fastest |

Install `whisper-server` with `brew install whisper-cpp`. Run it with `--beam-size 5`, which
is more accurate than the greedy default.

### Option B: any OpenAI-compatible endpoint

- **Mac app**: in Settings, set the server address (for example `https://api.openai.com/v1`),
  the model (`whisper-1`) and the API key. The key is stored in the Keychain. Plain `http` is
  accepted only for loopback addresses.
- **Web server**: set `VOICENOTES_HUB_URL` to the server root (without `/v1`) and set
  `VOICENOTES_MODELS` to a comma-separated list of model ids.

## Install

### macOS

Requirements: macOS 14 or later, Xcode command line tools (Swift 6), Node 22 or later.

```sh
zsh scripts/build-app.sh --install   # builds, signs and installs ~/Applications/VoiceNotes.app
zsh scripts/install-web.sh           # runs the web server as a launchd agent on port 5555
```

- `build-app.sh` signs with the first Apple Development, Developer ID or "VoiceNotes Local
  Signing" identity in your keychain. Set `SIGN_IDENTITY` to pick a different one. A stable
  identity keeps the microphone and Accessibility permissions across rebuilds. Without one,
  the app is ad-hoc signed and macOS asks for the permissions again after every build.
- Dictation types text with synthetic key presses, so it needs the Accessibility permission.
  Settings has a button that opens it. Without the permission, the text goes to the
  clipboard.
- If [Tailscale](https://tailscale.com) is installed, `install-web.sh` also publishes the web
  app to your tailnet over HTTPS. Without Tailscale, the web app is reachable from this Mac
  only.

### Web server on Windows and Linux

The Mac app runs on macOS only. The web server runs on Windows and Linux too.
Requirements: Node 22 or later on `PATH`.

```sh
bash scripts/install-web-linux.sh                                   # Linux: systemd user service
powershell -ExecutionPolicy Bypass -File scripts\install-web.ps1    # Windows: scheduled task at logon
```

- On Linux, the script installs `~/.config/systemd/user/voicenotes-web.service` and starts it.
  Read the log with `journalctl --user -u voicenotes-web`. The service stops when you log out,
  unless you run `loginctl enable-linger $USER`.
- On Windows, the script registers the "VoiceNotes Web" task for your user and starts it. It
  does not need administrator rights. The log goes to `%LOCALAPPDATA%\VoiceNotes\logs\web.log`.
- If Tailscale is installed, both scripts also publish the web app to your tailnet over HTTPS.
  On Linux, `tailscale serve` can need `sudo tailscale set --operator=$USER` first.

The server keeps its data in a folder that depends on the OS:

| OS | Data folder |
|---|---|
| macOS | `~/Library/Application Support/VoiceNotes` |
| Windows | `%APPDATA%\VoiceNotes` |
| Linux and other | `$XDG_DATA_HOME/voicenotes`, or `~/.local/share/voicenotes` |

## Windows dictation app

`windows/` holds a Windows tray app (C# .NET 10, WinForms) that types your speech into any app.

- Press **Ctrl+Alt+Space** to start dictation, and press it again to stop. A floating pill shows
  the level and has pause/resume and stop buttons. Clicking the pill does not take focus from the
  app you type into.
- The app sends 5–20 s speech chunks to `<server>/audio/transcriptions` and types each result
  when it arrives. It skips chunks with no speech.
- If Windows blocks typing (for example into an app that runs as administrator), the app copies
  the text to the clipboard and shows a notification.
- Settings (tray icon, then Settings): server address (default `http://127.0.0.1:8888/v1`), model
  (default `ivrit/ivrit-large-v3-turbo`), optional API key (encrypted with Windows DPAPI),
  language, shortcut, and Start with Windows.
- Files: settings in `%APPDATA%\VoiceNotes\windows-settings.json`, logs in
  `%LOCALAPPDATA%\VoiceNotes\logs\voicenotes.log`, temporary audio in `%TEMP%\VoiceNotesDictation`.

Build and test (the tests also run on macOS and Linux):

```sh
dotnet test windows/tests/VoiceNotes.Core.Tests
dotnet publish windows/src/VoiceNotes.Windows -p:PublishProfile=win-x64
```

The single-file `VoiceNotes.exe` is written to `windows/src/VoiceNotes.Windows/bin/publish/win-x64/`.
CI (`.github/workflows/windows.yml`) builds it on every change under `windows/` and uploads it as
the `VoiceNotes-win-x64` artifact.

## Web server configuration

| Variable | Default | Meaning |
|---|---|---|
| `VOICENOTES_HUB_URL` | `http://127.0.0.1:8888` | Transcription server root |
| `VOICENOTES_MODELS` | the llm-hub ids above | Comma-separated model ids to offer |
| `VOICENOTES_MODEL` | `ivrit/ivrit-large-v3-turbo` | Default model |
| `VOICENOTES_HOST` | `127.0.0.1` | Bind address |
| `VOICENOTES_PORT` | `5555` | Port |
| `VOICENOTES_TOKEN` / `VOICENOTES_TOKEN_FILE` | none | Access token of 24 or more characters. Required when the host is not loopback |
| `VOICENOTES_PUBLIC_URL` | none | URL the app shows for other devices |
| `VOICENOTES_DATA_FILE` | `server-notes.json` in the data folder | Notes storage |
| `VOICENOTES_SETTINGS_FILE` | `server-settings.json` in the data folder | Selected model |

## Development

```sh
swift test                                        # Mac app core
(cd web && npm test)                              # web app and server
dotnet test windows/tests/VoiceNotes.Core.Tests   # Windows app core
```

The Mac app writes its log to the folder that the `logDirectory` default names
(`build-app.sh --install` sets it to `logs/` in this repo). Without that default, the log
goes to `~/Library/Logs/VoiceNotes`.
