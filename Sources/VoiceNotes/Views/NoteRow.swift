import SwiftUI
import VoiceNotesCore

struct NoteRow: View {
    let note: Note
    let isRecording: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if isRecording {
                    Circle().fill(Palette.recording).frame(width: 7, height: 7)
                        .accessibilityLabel("Recording")
                }
                Text(note.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text(note.updatedAt, format: .relative(presentation: .named))
                if note.recordedSeconds > 0 {
                    Text(Duration.seconds(note.recordedSeconds), format: .time(pattern: .minuteSecond))
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}
