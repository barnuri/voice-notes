import SwiftUI
import VoiceNotesCore

struct RecordingCommands: Commands {
    let controller: RecordingController
    @FocusedValue(\.selectedNoteID) private var selectedNoteID

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                NotificationCenter.default.post(name: .newNoteRequested, object: nil)
            }
            .keyboardShortcut("n")
        }
        CommandMenu("Recording") {
            Button(controller.phase.primaryActionTitle) {
                Task { await controller.togglePrimary(into: selectedNoteID ?? nil) }
            }
                .keyboardShortcut("r")
            Button("Finish Recording") { Task { await controller.finish() } }
                .keyboardShortcut(.return)
                .disabled(controller.phase == .idle)
        }
    }
}
