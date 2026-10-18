import Foundation

public enum DictationError: LocalizedError, Equatable {
    case accessibilityDenied
    case recordingNotSaved

    public var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            "VoiceNotes can't type into other apps. Allow it in System Settings → Privacy & Security → Accessibility. The text is on the clipboard."
        case .recordingNotSaved:
            "The dictation recording didn't save. Try again."
        }
    }
}
