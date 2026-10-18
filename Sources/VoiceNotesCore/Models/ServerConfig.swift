import Foundation

public struct ServerConfig: Codable, Equatable, Sendable {
    public let model: String
    public let models: [TranscriptionModel]

    public init(model: String, models: [TranscriptionModel]) {
        self.model = model
        self.models = models
    }
}
