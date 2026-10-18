import SwiftUI

struct ErrorBanner: View {
    @Environment(\.openSettings) private var openSettings
    let message: String
    var showsSettings = false
    var onRetry: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.paused)
            Text(message)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if let onRetry {
                Button("Try Again", action: onRetry)
            }
            if showsSettings {
                Button("Settings") { openSettings() }
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Palette.paused.opacity(0.12))
    }
}
