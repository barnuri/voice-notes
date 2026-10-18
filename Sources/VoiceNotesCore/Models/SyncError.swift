import Foundation

public enum SyncError: LocalizedError, Equatable {
    case unreachable(host: String)
    case unauthorized
    case server(status: Int, message: String)
    case unreadableResponse

    public var errorDescription: String? {
        switch self {
        case .unreachable(let host):
            "Can't reach the sync server at \(host). Check that it's running."
        case .unauthorized:
            "The sync server rejected the access token. Check it in Settings."
        case .server(let status, let message):
            "The sync server answered \(status): \(message)"
        case .unreadableResponse:
            "The sync server sent a response VoiceNotes can't read."
        }
    }
}
