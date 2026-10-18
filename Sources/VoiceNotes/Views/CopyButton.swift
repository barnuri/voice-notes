import SwiftUI

struct CopyButton: View {
    private static let feedbackDuration: Duration = .seconds(1.5)
    let text: String
    @State private var didCopy = false

    var body: some View {
        Button {
            Clipboard.copy(text)
            didCopy = true
            Task {
                try? await Task.sleep(for: Self.feedbackDuration)
                didCopy = false
            }
        } label: {
            Label(didCopy ? "Copied" : "Copy Text", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .disabled(text.isEmpty)
        .help("Copy the whole note (⇧⌘C)")
        .accessibilityLabel(didCopy ? "Copied" : "Copy text")
    }
}
