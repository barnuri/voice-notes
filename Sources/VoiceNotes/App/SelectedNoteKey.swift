import SwiftUI
import VoiceNotesCore

struct SelectedNoteKey: FocusedValueKey {
    typealias Value = Note.ID?
}

extension FocusedValues {
    var selectedNoteID: Note.ID?? {
        get { self[SelectedNoteKey.self] }
        set { self[SelectedNoteKey.self] = newValue }
    }
}

extension Notification.Name {
    static let newNoteRequested = Notification.Name("VoiceNotes.newNoteRequested")
}
