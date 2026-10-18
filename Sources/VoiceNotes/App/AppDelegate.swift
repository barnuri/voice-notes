import AppKit
import VoiceNotesCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: AppSettings
    let store: NoteStore
    let controller: RecordingController
    let sync: SyncService
    let microphones: MicrophoneCatalog
    let dictation: DictationController
    let globalHotKey = GlobalHotKey()
    private let dictationHUD = DictationHUD()

    override init() {
        let settings = AppSettings()
        AppLog.shared.configure(directory: settings.logDirectory)
        AppLog.info("VoiceNotes started.")
        let store = NoteStore()
        let microphones = MicrophoneCatalog()
        self.settings = settings
        self.store = store
        self.microphones = microphones
        controller = RecordingController(
            store: store,
            recorder: SegmentRecorder(deviceID: { microphones.resolvedDevice(storedID: settings.microphoneID)?.id }),
            transcriber: WhisperTranscriptionClient(),
            endpoint: { settings.transcriptionEndpoint }
        )
        sync = SyncService(
            store: store,
            client: HTTPSyncClient(),
            endpoint: { settings.syncEndpoint },
            onModel: { model in
                if settings.model != model {
                    settings.model = model
                }
            }
        )
        let dictationHUD = dictationHUD
        dictation = DictationController(
            recorder: SegmentRecorder(
                directory: FileManager.default.temporaryDirectory.appendingPathComponent("VoiceNotesDictation"),
                deviceID: { microphones.resolvedDevice(storedID: settings.microphoneID)?.id }
            ),
            transcriber: WhisperTranscriptionClient(),
            endpoint: { settings.transcriptionEndpoint },
            typer: KeystrokeTyper(),
            onPhaseChange: { phase in
                DictationSound.play(for: phase)
                dictationHUD.update(for: phase)
            }
        )
        super.init()
        dictationHUD.attach(dictation, settings: settings)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        sync.start()
        registerDictationHotKey()
    }

    private func registerDictationHotKey() {
        let hotKey = withObservationTracking {
            settings.dictationHotKey
        } onChange: {
            Task { @MainActor [weak self] in self?.registerDictationHotKey() }
        }
        globalHotKey.register(hotKey) { [weak self] in self?.toggleDictation() }
    }

    private func toggleDictation() {
        Task {
            await dictation.toggle()
            if dictation.errorMessage != nil {
                DictationSound.playError()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.info("VoiceNotes quit.")
        store.flushPendingSave()
    }
}
