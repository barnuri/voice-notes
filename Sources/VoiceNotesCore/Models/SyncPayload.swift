import Foundation

struct SyncPayload: Codable, Equatable, Sendable {
    let notes: [Note]
}
