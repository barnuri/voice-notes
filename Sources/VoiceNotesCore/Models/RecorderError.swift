import Foundation

public enum RecorderError: LocalizedError, Equatable {
    case permissionDenied
    case couldNotStart

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "VoiceNotes can't use the microphone. Allow it in System Settings → Privacy & Security → Microphone."
        case .couldNotStart:
            "The microphone didn't start. Check that an input device is connected."
        }
    }
}
