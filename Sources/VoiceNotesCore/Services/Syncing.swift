import Foundation

public protocol Syncing: Sendable {
    func sync(_ records: [Note], endpoint: SyncEndpoint) async throws -> [Note]
    func fetchConfig(endpoint: SyncEndpoint) async throws -> ServerConfig
    func selectModel(_ id: String, endpoint: SyncEndpoint) async throws -> String
}
