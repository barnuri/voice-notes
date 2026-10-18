import Foundation
import Testing
@testable import VoiceNotesCore

struct TranscriptionEndpointTests {
    @Test(arguments: [
        "http://127.0.0.1:8888/v1",
        "http://127.0.0.1:8888/v1/",
        " http://127.0.0.1:8888/v1 ",
    ])
    func buildsTranscriptionURL(base: String) throws {
        let endpoint = try #require(TranscriptionEndpoint(baseURL: base, model: "m", apiKey: ""))
        #expect(endpoint.url.absoluteString == "http://127.0.0.1:8888/v1/audio/transcriptions")
    }

    @Test(arguments: ["", "127.0.0.1:8888", "ftp://host/v1", "http://", "http://192.168.1.5:8888/v1"])
    func rejectsInvalidBase(base: String) {
        #expect(TranscriptionEndpoint(baseURL: base, model: "m", apiKey: "") == nil)
    }

    @Test(arguments: ["http://localhost:8888/v1", "http://[::1]:8888/v1", "https://box.example.ts.net/v1"])
    func allowsLoopbackHTTPAndAnyHTTPS(base: String) {
        #expect(TranscriptionEndpoint(baseURL: base, model: "m", apiKey: "") != nil)
    }

    @Test func rejectsEmptyModel() {
        #expect(TranscriptionEndpoint(baseURL: "https://h/v1", model: "  ", apiKey: "") == nil)
    }
}
