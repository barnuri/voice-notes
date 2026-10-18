import SwiftUI
import VoiceNotesCore

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SyncService.self) private var sync
    @Environment(DictationController.self) private var dictation
    @Environment(GlobalHotKey.self) private var globalHotKey
    @State private var canTypeIntoApps = KeystrokeTyper.isTrusted(prompt: false)

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                TextField("Server address", text: $settings.baseURL, prompt: Text(AppSettings.defaultBaseURL))
                if sync.availableModels.isEmpty {
                    TextField("Model", text: $settings.model, prompt: Text(AppSettings.defaultModel))
                } else {
                    ModelPicker()
                        .help(ModelPicker.helpText)
                }
                SecureField("API key", text: $settings.apiKey, prompt: Text("Optional"))
                LanguagePicker(selection: $settings.language)
            } header: {
                Text("Transcription")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Any OpenAI-compatible server works. The default sends audio to your local llm-hub, which runs Whisper on this Mac.")
                    Text("The API key is stored in your Keychain.")
                    if let modelError = sync.modelError {
                        Text(modelError)
                            .foregroundStyle(Palette.recording)
                    }
                    if settings.transcriptionEndpoint == nil {
                        Text("Enter an http:// or https:// address and a model name.")
                            .foregroundStyle(Palette.recording)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Button("Use llm-hub Defaults") { settings.resetConnection() }
            Section {
                LabeledContent("Shortcut") {
                    HotKeyRecorder(hotKey: $settings.dictationHotKey)
                }
                if !globalHotKey.isRegistered {
                    Text("This shortcut can't be used. Another app may use it. Choose a different one.")
                        .foregroundStyle(Palette.recording)
                }
                if !canTypeIntoApps {
                    HStack {
                        Text("VoiceNotes needs Accessibility access to type into other apps.")
                        Spacer()
                        Button("Allow…") { canTypeIntoApps = KeystrokeTyper.isTrusted(prompt: true) }
                    }
                }
                if let error = dictation.errorMessage {
                    Text(error).foregroundStyle(Palette.recording)
                }
            } header: {
                Text("Dictation")
            } footer: {
                Text("Press the shortcut in any app and speak. Press it again to type the text where your cursor is.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                canTypeIntoApps = KeystrokeTyper.isTrusted(prompt: false)
            }
            Section("Microphone") {
                MicrophonePicker()
                    .help(MicrophonePicker.helpText)
            }
            Section {
                TextField("Sync server", text: $settings.syncURL, prompt: Text(AppSettings.defaultSyncURL))
                SecureField("Access token", text: $settings.syncToken, prompt: Text("Read from \(AppSettings.syncTokenFilePath)"))
                HStack {
                    syncStatus
                        .font(.caption)
                    Spacer()
                    Button("Sync Now") { Task { await sync.syncNow() } }
                        .disabled(sync.isSyncing || settings.syncEndpoint == nil)
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Notes sync with the VoiceNotes web app so the same history shows on every device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var syncStatus: some View {
        if settings.syncEndpoint == nil {
            Text("Sync is off").foregroundStyle(.secondary)
        } else if sync.isSyncing {
            Text("Syncing…").foregroundStyle(.secondary)
        } else if let error = sync.lastError {
            Text(error).foregroundStyle(Palette.recording)
        } else if let lastSyncedAt = sync.lastSyncedAt {
            Text("Synced \(Text(lastSyncedAt, style: .relative)) ago").foregroundStyle(.secondary)
        }
    }
}
