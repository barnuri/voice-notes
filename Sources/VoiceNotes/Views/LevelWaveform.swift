import SwiftUI

struct LevelWaveform: View {
    static let standardWidth: CGFloat = 150
    static let standardHeight: CGFloat = 36
    private static let barWidth: CGFloat = 3
    private static let barGap: CGFloat = 2
    private static let minBarHeight: CGFloat = 3
    private static let levelCurve: Float = 0.6
    private static let sampleInterval: Duration = .milliseconds(70)
    private static let easing: Animation = .easeOut(duration: 0.07)

    let level: () -> Float
    let isActive: Bool
    var tint: Color = Palette.recording
    var width: CGFloat = standardWidth
    var height: CGFloat = standardHeight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var history: [Float] = []

    var body: some View {
        HStack(spacing: Self.barGap) {
            ForEach(history.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: Self.barWidth / 2)
                    .frame(width: Self.barWidth, height: barHeight(for: history[index]))
            }
        }
        .frame(width: width, height: height, alignment: .trailing)
        .foregroundStyle(isActive ? tint : Color.secondary)
        .animation(reduceMotion ? nil : Self.easing, value: history)
        .accessibilityHidden(true)
        .onAppear { history = Array(repeating: 0, count: capacity) }
        .task(id: isActive) { await sampleWhileActive() }
    }

    private var capacity: Int {
        Int(width / (Self.barWidth + Self.barGap))
    }

    private func sampleWhileActive() async {
        while isActive, !Task.isCancelled {
            if !history.isEmpty {
                history.removeFirst()
            }
            history.append(level())
            try? await Task.sleep(for: Self.sampleInterval)
        }
    }

    private func barHeight(for level: Float) -> CGFloat {
        max(Self.minBarHeight, CGFloat(pow(min(max(level, 0), 1), Self.levelCurve)) * height)
    }
}
