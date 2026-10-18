import SwiftUI
import VoiceNotesCore

struct ModelPicker: View {
    static let helpText = "Whisper model (shared with the web app)"

    @Environment(SyncService.self) private var sync
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Picker("Model", selection: selection) {
            ForEach(sync.availableModels) { model in
                Text(model.title).tag(model.id)
            }
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: { settings.model },
            set: { id in Task { await sync.selectModel(id) } }
        )
    }
}
