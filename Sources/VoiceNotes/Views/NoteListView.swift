import SwiftUI
import VoiceNotesCore

struct NoteListView: View {
    @Environment(NoteStore.self) private var store
    @Environment(RecordingController.self) private var controller
    @Binding var selection: Note.ID?
    let query: String

    var body: some View {
        let notes = store.filtered(by: query)
        List(selection: $selection) {
            ForEach(notes) { note in
                NoteRow(note: note, isRecording: controller.isRecording(into: note.id))
                    .tag(note.id)
                    .contextMenu {
                        Button("Copy Text") { Clipboard.copy(note.text) }
                        Divider()
                        Button("Delete", role: .destructive) { delete(note.id) }
                            .disabled(controller.isRecording(into: note.id))
                    }
            }
        }
        .overlay {
            if notes.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "No notes yet" : "No matches",
                    systemImage: query.isEmpty ? "waveform" : "magnifyingglass",
                    description: Text(query.isEmpty ? "Press ⌘R to record your first note." : "Try a different word.")
                )
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    selection = store.create().id
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .help("New note (⌘N)")
            }
        }
        .onDeleteCommand {
            if let selection { delete(selection) }
        }
    }

    private func delete(_ id: Note.ID) {
        guard !controller.isRecording(into: id) else { return }
        if selection == id { selection = nil }
        store.delete(id)
    }
}
