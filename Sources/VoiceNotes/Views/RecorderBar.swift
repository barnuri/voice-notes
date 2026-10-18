import SwiftUI
import VoiceNotesCore

struct RecorderBar: View {
    private static let microphoneTitleLimit = 18

    @Environment(RecordingController.self) private var controller
    @Environment(NoteStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(SyncService.self) private var sync
    @Environment(MicrophoneCatalog.self) private var microphones
    let selection: Note.ID?

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            if let message = controller.errorMessage {
                ErrorBanner(
                    message: message,
                    showsSettings: true,
                    onRetry: controller.failedSegments.isEmpty ? nil : { controller.retryFailed() },
                    onDismiss: { controller.errorMessage = nil }
                )
            }
            Divider()
            HStack(spacing: 18) {
                RecordButton()
                StatusLabel()
                if controller.phase != .idle {
                    LevelWaveform(level: { controller.level }, isActive: controller.phase == .recording)
                }
                Menu(settings.language.shortTitle) {
                    LanguagePicker(selection: $settings.language)
                        .pickerStyle(.inline)
                        .labelsHidden()
                }
                .fixedSize()
                .help("Transcription language")
                Menu {
                    MicrophonePicker()
                        .pickerStyle(.inline)
                        .labelsHidden()
                } label: {
                    Label(microphoneTitle, systemImage: "mic")
                }
                .fixedSize()
                .disabled(controller.phase == .recording)
                .help(MicrophonePicker.helpText)
                if !sync.availableModels.isEmpty {
                    Menu(selectedModelTitle) {
                        ModelPicker()
                            .pickerStyle(.inline)
                            .labelsHidden()
                    }
                    .fixedSize()
                    .help(ModelPicker.helpText)
                }
                Spacer()
                if controller.phase != .idle {
                    Button(controller.phase.primaryActionTitle) {
                        Task { await controller.togglePrimary(into: selection) }
                    }
                        .help(controller.phase == .recording ? "Pause and transcribe (⌘R)" : "Keep recording (⌘R)")
                    Button("Done") { Task { await controller.finish() } }
                        .help("Finish this recording (⌘↩)")
                }
                CopyButton(text: currentText)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.copy)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(.bar)
    }

    private var currentText: String {
        let id = controller.noteID ?? selection
        return id.flatMap { store.note(id: $0)?.text } ?? ""
    }

    private var selectedModelTitle: String {
        sync.availableModels.first { $0.id == settings.model }?.title ?? settings.model
    }

    private var microphoneTitle: String {
        let name = microphones.resolvedDevice(storedID: settings.microphoneID)?.name ?? "No microphone"
        guard name.count > Self.microphoneTitleLimit else { return name }
        return name.prefix(Self.microphoneTitleLimit - 1) + "…"
    }

}
