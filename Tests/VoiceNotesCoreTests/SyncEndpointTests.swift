import Foundation
import Testing
@testable import VoiceNotesCore

struct SyncEndpointTests {
    @Test(arguments: [
        "http://127.0.0.1:5555",
        "http://127.0.0.1:5555/",
        " http://127.0.0.1:5555 ",
    ])
    func buildsSyncURL(base: String) throws {
        let endpoint = try #require(SyncEndpoint(baseURL: base, token: " t \n"))
        #expect(endpoint.url.absoluteString == "http://127.0.0.1:5555/api/sync")
        #expect(endpoint.configURL.absoluteString == "http://127.0.0.1:5555/api/config")
        #expect(endpoint.settingsURL.absoluteString == "http://127.0.0.1:5555/api/settings")
        #expect(endpoint.token == "t")
    }

    @Test(arguments: ["", "127.0.0.1:5555", "ftp://host", "http://"])
    func rejectsInvalidBase(base: String) {
        #expect(SyncEndpoint(baseURL: base, token: "t") == nil)
    }

    @Test func allowsEmptyToken() throws {
        let endpoint = try #require(SyncEndpoint(baseURL: "https://h:5555", token: "  "))
        #expect(endpoint.token.isEmpty)
    }
}
