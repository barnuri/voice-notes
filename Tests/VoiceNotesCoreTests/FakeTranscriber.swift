import Foundation
@testable import VoiceNotesCore

final class FakeTranscriber: Transcribing, @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [Result<String, TranscriptionError>]
    private var calls = 0

    init(_ replies: [Result<String, TranscriptionError>]) {
        self.replies = replies
    }

    var callCount: Int { lock.withLock { calls } }

    func transcribe(fileURL: URL, endpoint: TranscriptionEndpoint) async throws -> String {
        let reply = lock.withLock {
            calls += 1
            return replies.isEmpty ? .success("") : replies.removeFirst()
        }
        return try reply.get()
    }
}
