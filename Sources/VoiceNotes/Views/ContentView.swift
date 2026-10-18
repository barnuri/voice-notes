import SwiftUI
import VoiceNotesCore

struct ContentView: View {
    @Environment(NoteStore.self) private var store
    @Environment(RecordingController.self) private var controller
    @State private var selection: Note.ID?
    @State private var query = ""

    var body: some View {
        NavigationSplitView {
            NoteListView(selection: $selection, query: query)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            VStack(spacing: 0) {
                if let storeError = store.lastError {
                    ErrorBanner(message: storeError, onDismiss: { store.lastError = nil })
                }
                if let selection, store.note(id: selection) != nil {
                    NoteEditorView(noteID: selection)
                } else {
                    EmptyNoteView()
                }
                RecorderBar(selection: selection)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    CopyButton(text: selection.flatMap { store.note(id: $0)?.text } ?? "")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: "Search notes")
        .focusedSceneValue(\.selectedNoteID, selection)
        .onChange(of: controller.noteID) { _, recordingID in
            if let recordingID { selection = recordingID }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNoteRequested)) { _ in
            selection = store.create().id
        }
        .onAppear {
            if selection == nil { selection = store.notes.first?.id }
        }
    }
}
