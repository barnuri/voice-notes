import Foundation
import Testing
@testable import VoiceNotesCore

struct LiveHubTests {
    private static let audioPath = ProcessInfo.processInfo.environment["VOICENOTES_LIVE_AUDIO"]

    @Test(.enabled(if: audioPath != nil, "set VOICENOTES_LIVE_AUDIO to an m4a file to run against local llm-hub"))
    func transcribesThroughLocalHub() async throws {
        let endpoint = try #require(TranscriptionEndpoint(
            baseURL: AppSettings.defaultBaseURL,
            model: AppSettings.defaultModel,
            apiKey: ""
        ))
        let text = try await WhisperTranscriptionClient()
            .transcribe(fileURL: URL(fileURLWithPath: Self.audioPath!), endpoint: endpoint)
        #expect(!text.isEmpty)
        print("live transcript: \(text)")
    }
}
