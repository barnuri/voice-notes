import SwiftUI

struct EmptyNoteView: View {
    var body: some View {
        ContentUnavailableView(
            "Start talking",
            systemImage: "mic",
            description: Text("Press the record button or ⌘R. Your words show up here each time you pause.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
