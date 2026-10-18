import Foundation
@testable import VoiceNotesCore

final class FakeSyncClient: Syncing, @unchecked Sendable {
    private let lock = NSLock()
    private let reply: Result<[Note], SyncError>
    private let configReply: Result<ServerConfig, SyncError>
    private let selectReply: Result<String, SyncError>
    private var received: [[Note]] = []
    private var selected: [String] = []

    init(
        _ reply: Result<[Note], SyncError>,
        config: Result<ServerConfig, SyncError> = .success(ServerConfig(model: "", models: [])),
        select: Result<String, SyncError> = .failure(.unreadableResponse)
    ) {
        self.reply = reply
        configReply = config
        selectReply = select
    }

    var calls: [[Note]] { lock.withLock { received } }
    var selections: [String] { lock.withLock { selected } }

    func sync(_ records: [Note], endpoint: SyncEndpoint) async throws -> [Note] {
        lock.withLock { received.append(records) }
        return try reply.get()
    }

    func fetchConfig(endpoint: SyncEndpoint) async throws -> ServerConfig {
        try configReply.get()
    }

    func selectModel(_ id: String, endpoint: SyncEndpoint) async throws -> String {
        lock.withLock { selected.append(id) }
        return try selectReply.get()
    }
}
