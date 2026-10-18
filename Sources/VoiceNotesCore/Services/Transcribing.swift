import Foundation

public protocol Transcribing: Sendable {
    func transcribe(fileURL: URL, endpoint: TranscriptionEndpoint) async throws -> String
}
