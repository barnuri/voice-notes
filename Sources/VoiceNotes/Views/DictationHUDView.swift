import SwiftUI
import VoiceNotesCore

struct DictationHUDView: View {
    private static let waveformWidth: CGFloat = 72
    private static let waveformHeight: CGFloat = 22
    private static let buttonDiameter: CGFloat = 28

    let dictation: DictationController
    let shortcut: String

    var body: some View {
        HStack(spacing: 12) {
            LevelWaveform(
                level: { dictation.level },
                isActive: dictation.phase == .listening,
                tint: tint,
                width: Self.waveformWidth,
                height: Self.waveformHeight
            )
            Text(statusTitle)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .frame(minWidth: 64, alignment: .leading)
            if dictation.phase == .transcribing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: Self.buttonDiameter * 2 + 8)
            } else {
                controlButton(
                    symbol: dictation.phase == .paused ? "mic.fill" : "pause.fill",
                    title: dictation.phase == .paused ? "Resume" : "Pause",
                    fill: tint
                ) {
                    Task { dictation.phase == .paused ? await dictation.resume() : await dictation.pause() }
                }
                controlButton(symbol: "stop.fill", title: "Stop and type (\(shortcut))", fill: .secondary.opacity(0.35)) {
                    Task { await dictation.stop() }
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dictation")
    }

    private var tint: Color {
        dictation.phase == .paused ? Palette.paused : Palette.recording
    }

    private var statusTitle: String {
        switch dictation.phase {
        case .listening: "Listening"
        case .paused: "Paused"
        case .transcribing, .idle: "Finishing"
        }
    }

    private func controlButton(symbol: String, title: String, fill: some ShapeStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}
