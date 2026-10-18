import Foundation
import Testing
@testable import VoiceNotesCore

struct HTTPSyncClientTests {
    @Test func requestPostsRecordsWithBearerAndFractionalDates() throws {
        let endpoint = try #require(SyncEndpoint(baseURL: "https://h:5555", token: "secret"))
        let stamp = Date(timeIntervalSince1970: 1_791_288_000.5)
        let note = Note(text: "hello", createdAt: stamp, updatedAt: stamp, deletedAt: stamp)
        let request = try HTTPSyncClient().makeRequest(records: [note], endpoint: endpoint)

        #expect(request.url?.absoluteString == "https://h:5555/api/sync")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(request.httpBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [[String: Any]]])
        let record = try #require(object["notes"]?.first)
        #expect((record["id"] as? String)?.lowercased() == note.id.uuidString.lowercased())
        #expect(record["text"] as? String == "hello")
        #expect(record["updatedAt"] as? String == "2026-10-06T12:00:00.500Z")
        #expect(record["deletedAt"] as? String == "2026-10-06T12:00:00.500Z")
    }

    @Test func liveNoteOmitsDeletedAt() throws {
        let endpoint = try #require(SyncEndpoint(baseURL: "https://h:5555", token: "secret"))
        let request = try HTTPSyncClient().makeRequest(records: [Note()], endpoint: endpoint)
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
        #expect(!body.contains("deletedAt"))
    }

    @Test func configRequestGetsConfigWithBearer() throws {
        let endpoint = try #require(SyncEndpoint(baseURL: "https://h:5555", token: "secret"))
        let request = HTTPSyncClient().makeConfigRequest(endpoint: endpoint)

        #expect(request.url?.absoluteString == "https://h:5555/api/config")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.httpBody == nil)
    }

    @Test func configRequestOmitsAuthorizationWithoutToken() throws {
        let endpoint = try #require(SyncEndpoint(baseURL: "https://h:5555", token: ""))
        let request = HTTPSyncClient().makeConfigRequest(endpoint: endpoint)

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func selectModelRequestPutsModelJSONWithBearer() throws {
        let endpoint = try #require(SyncEndpoint(baseURL: "https://h:5555", token: "secret"))
        let request = try HTTPSyncClient().makeSelectModelRequest("ivrit/ivrit-large-v3-turbo", endpoint: endpoint)

        #expect(request.url?.absoluteString == "https://h:5555/api/settings")
        #expect(request.httpMethod == "PUT")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(request.httpBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(object == ["model": "ivrit/ivrit-large-v3-turbo"])
    }

    @Test func decodesServerRecordsWithLowercaseIds() throws {
        let id = UUID()
        let json = """
        {"notes":[{"id":"\(id.uuidString.lowercased())","text":"x","createdAt":"2026-10-06T12:00:00.123Z","updatedAt":"2026-10-06T12:00:00Z","recordedSeconds":1.5}]}
        """
        let payload = try ISO8601DateCoding.makeDecoder().decode(SyncPayload.self, from: Data(json.utf8))
        #expect(payload.notes.first?.id == id)
        #expect(payload.notes.first?.deletedAt == nil)
    }
}
