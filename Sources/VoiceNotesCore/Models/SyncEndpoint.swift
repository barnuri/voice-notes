import Foundation

public struct SyncEndpoint: Equatable, Sendable {
    private static let syncPath = "api/sync"
    private static let configPath = "api/config"
    private static let settingsPath = "api/settings"

    public let url: URL
    public let configURL: URL
    public let settingsURL: URL
    public let token: String

    public init?(baseURL: String, token: String) {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = ServiceBaseURL.parse(baseURL) else { return nil }
        url = base.appending(path: Self.syncPath)
        configURL = base.appending(path: Self.configPath)
        settingsURL = base.appending(path: Self.settingsPath)
        self.token = trimmedToken
    }
}
