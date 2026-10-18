import SwiftUI
import VoiceNotesCore

struct NoteEditorView: View {
    @Environment(NoteStore.self) private var store
    let noteID: Note.ID
    @FocusState private var isFocused: Bool

    var body: some View {
        let text = Binding(
            get: { store.note(id: noteID)?.text ?? "" },
            set: { store.edit(noteID, text: $0) }
        )
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .font(Palette.transcriptFont)
                .lineSpacing(Palette.transcriptLineSpacing)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .accessibilityLabel("Note text")
            if text.wrappedValue.isEmpty {
                Text("Press record and start talking. Pause any time to see your words here, then edit them freely.")
                    .font(Palette.transcriptFont)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: Palette.readingWidth, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
