import SwiftUI
import VoiceNotesCore

struct MicrophonePicker: View {
    static let helpText = "Microphone used for recording"

    @Environment(MicrophoneCatalog.self) private var catalog
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Picker("Microphone", selection: selection) {
            Text(systemDefaultTitle).tag(AppSettings.systemDefaultMicrophoneID)
            ForEach(catalog.devices) { device in
                Text(device.name).tag(device.id)
            }
        }
    }

    private var systemDefaultTitle: String {
        guard let name = catalog.defaultDevice?.name else { return "System default" }
        return "System default (\(name))"
    }

    private var selection: Binding<String> {
        Binding(
            get: {
                let isAvailable = catalog.devices.contains { $0.id == settings.microphoneID }
                return isAvailable ? settings.microphoneID : AppSettings.systemDefaultMicrophoneID
            },
            set: { settings.microphoneID = $0 }
        )
    }
}
