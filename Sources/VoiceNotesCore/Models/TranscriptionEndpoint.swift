import Foundation

public struct TranscriptionEndpoint: Equatable, Sendable {
    private static let transcriptionPath = "audio/transcriptions"

    public let url: URL
    public let model: String
    public let apiKey: String
    public let language: TranscriptionLanguage

    public init?(baseURL: String, model: String, apiKey: String, language: TranscriptionLanguage = .hebrewWithEnglish) {
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        guard !trimmedModel.isEmpty,
              let base = ServiceBaseURL.parse(baseURL) else { return nil }
        url = base.appending(path: Self.transcriptionPath)
        self.model = trimmedModel
        self.apiKey = apiKey.trimmingCharacters(in: .whitespaces)
        self.language = language
    }
}
