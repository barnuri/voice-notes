import SwiftUI
import VoiceNotesCore

struct RecordButton: View {
    private static let diameter: CGFloat = 56
    private static let ringWidth: CGFloat = 4
    @Environment(RecordingController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusedValue(\.selectedNoteID) private var selectedNoteID

    var body: some View {
        Button {
            Task { await controller.togglePrimary(into: selectedNoteID ?? nil) }
        } label: {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: Self.ringWidth)
                Circle()
                    .trim(from: 0, to: controller.phase == .recording ? CGFloat(max(0.04, controller.level)) : 0)
                    .stroke(tint, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: controller.level)
                Circle()
                    .fill(tint)
                    .padding(Self.ringWidth + 4)
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
        .help("\(accessibilityTitle) (⌘R)")
    }

    private var tint: Color {
        controller.phase == .paused ? Palette.paused : Palette.recording
    }

    private var symbol: String {
        switch controller.phase {
        case .idle: "mic.fill"
        case .recording: "pause.fill"
        case .paused: "mic.fill"
        }
    }

    private var accessibilityTitle: String {
        controller.phase.primaryActionTitle
    }
}
