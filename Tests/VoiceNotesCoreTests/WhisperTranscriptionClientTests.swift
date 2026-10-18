import Foundation
import Testing
@testable import VoiceNotesCore

struct WhisperTranscriptionClientTests {
    @Test func decodesTrimmedText() {
        #expect(WhisperTranscriptionClient.decodeText(from: Data(#"{"text":" hi there\n"}"#.utf8)) == "hi there")
        #expect(WhisperTranscriptionClient.decodeText(from: Data("nope".utf8)) == nil)
    }

    @Test func readsHubAndWhisperErrorShapes() {
        let hub = Data(#"{"error":{"message":"all attempts failed"}}"#.utf8)
        let whisper = Data(#"{"error":"FFmpeg conversion failed."}"#.utf8)
        #expect(WhisperTranscriptionClient.errorMessage(from: hub) == "all attempts failed")
        #expect(WhisperTranscriptionClient.errorMessage(from: whisper) == "FFmpeg conversion failed.")
        #expect(WhisperTranscriptionClient.errorMessage(from: Data("plain".utf8)) == "plain")
    }

    @Test(arguments: [
        (TranscriptionLanguage.hebrewWithEnglish, true),
        (TranscriptionLanguage.english, false),
        (TranscriptionLanguage.auto, false),
    ])
    func requestSendsLanguageAndPromptWhenSet(language: TranscriptionLanguage, sendsPrompt: Bool) throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("vn-\(UUID()).m4a")
        try Data("AUDIO".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let endpoint = try #require(TranscriptionEndpoint(baseURL: "https://h/v1", model: "m", apiKey: "", language: language))

        let request = try WhisperTranscriptionClient().makeRequest(fileURL: file, endpoint: endpoint)
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
        let model = try #require(body.range(of: "name=\"model\""))
        let fileField = try #require(body.range(of: "name=\"file\""))
        #expect(model.lowerBound < fileField.lowerBound)
        #expect(body.contains("name=\"prompt\"") == sendsPrompt)
        #expect(body.contains("name=\"language\"\r\n\r\n\(language.languageCode)\r\n"))
        #expect(body.range(of: "name=\"language\"")!.lowerBound > model.lowerBound)
        if let prompt = language.prompt {
            #expect(body.contains("\r\n\r\n\(prompt)\r\n"))
            #expect(body.range(of: "name=\"prompt\"")!.lowerBound < fileField.lowerBound)
        }
    }

    @Test func requestPutsModelFirstAndAddsBearerOnlyWithKey() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("vn-\(UUID()).m4a")
        try Data("AUDIO".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let client = WhisperTranscriptionClient()

        let open = try #require(TranscriptionEndpoint(baseURL: "https://h/v1", model: "whisper/x", apiKey: ""))
        let request = try client.makeRequest(fileURL: file, endpoint: open)
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(body.range(of: "name=\"model\"")!.lowerBound < body.range(of: "name=\"file\"")!.lowerBound)
        #expect(body.contains("\r\n\r\nwhisper/x\r\n"))

        let keyed = try #require(TranscriptionEndpoint(baseURL: "https://h/v1", model: "m", apiKey: "k"))
        #expect(try client.makeRequest(fileURL: file, endpoint: keyed).value(forHTTPHeaderField: "Authorization") == "Bearer k")
    }
}
