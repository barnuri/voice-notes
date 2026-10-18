import SwiftUI
import VoiceNotesCore

struct LanguagePicker: View {
    @Binding var selection: TranscriptionLanguage

    var body: some View {
        Picker("Language", selection: $selection) {
            ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                Text(language.title).tag(language)
            }
        }
    }
}
