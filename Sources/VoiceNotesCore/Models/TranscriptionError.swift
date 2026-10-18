import Foundation

public enum TranscriptionError: LocalizedError, Equatable {
    case notConfigured
    case unreachable(host: String)
    case server(status: Int, message: String)
    case unreadableResponse
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Add a server address and model in Settings."
        case .unreachable(let host):
            "Can't reach the transcription server at \(host). Check that llm-hub is running."
        case .server(let status, let message):
            "The transcription server answered \(status): \(message)"
        case .unreadableResponse:
            "The transcription server sent a response VoiceNotes can't read."
        case .emptyResult:
            "Whisper heard speech but returned no text. Try again, or check the language and model."
        }
    }
}
