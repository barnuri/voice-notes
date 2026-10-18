# VoiceNotes

Speech-to-text notes and dictation for macOS, with a web app for your phone. Transcription
runs on any OpenAI-compatible `/v1/audio/transcriptions` endpoint, so your audio can stay on
your own Mac.

- **Mac app**: records notes and transcribes them while you talk. A global shortcut types
  what you say into the active app, chunk by chunk. While you dictate, a floating pill shows
  the level and has pause and stop buttons.
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
| `VOICENOTES_DATA_FILE` | `~/Library/Application Support/VoiceNotes/server-notes.json` | Notes storage |
| `VOICENOTES_SETTINGS_FILE` | `~/Library/Application Support/VoiceNotes/server-settings.json` | Selected model |

## Development

```sh
swift test             # Mac app core
(cd web && npm test)   # web app and server
```

The Mac app writes its log to the folder that the `logDirectory` default names
(`build-app.sh --install` sets it to `logs/` in this repo). Without that default, the log
goes to `~/Library/Logs/VoiceNotes`.
