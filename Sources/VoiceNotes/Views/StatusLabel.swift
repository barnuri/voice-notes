import SwiftUI
import VoiceNotesCore

struct StatusLabel: View {
    @Environment(RecordingController.self) private var controller

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            HStack(spacing: 6) {
                if controller.phase != .idle {
                    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                        Text(Duration.seconds(controller.elapsed), format: .time(pattern: .minuteSecond))
                            .monospacedDigit()
                    }
                }
                if controller.isTranscribing {
                    ProgressView().controlSize(.mini)
                    Text("Writing it down…")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch controller.phase {
        case .idle: controller.isTranscribing ? "Almost done" : "Ready"
        case .recording: "Listening"
        case .paused: "Paused"
        }
    }
}
