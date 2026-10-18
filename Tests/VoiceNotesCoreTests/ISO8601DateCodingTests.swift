import Foundation
import Testing
@testable import VoiceNotesCore

struct ISO8601DateCodingTests {
    private struct Stamp: Codable {
        let at: Date
    }

    private let noon = Date(timeIntervalSince1970: 1_791_288_000)

    private func decode(_ text: String) throws -> Date {
        try ISO8601DateCoding.makeDecoder().decode(Stamp.self, from: Data(#"{"at":"\#(text)"}"#.utf8)).at
    }

    @Test func decodesWithAndWithoutFractionalSeconds() throws {
        #expect(try decode("2026-10-06T12:00:00Z") == noon)
        #expect(abs(try decode("2026-10-06T12:00:00.123Z").timeIntervalSince(noon) - 0.123) < 0.0005)
    }

    @Test func rejectsNonDates() {
        #expect(throws: DecodingError.self) { try decode("yesterday") }
    }

    @Test func encodesFractionalSeconds() throws {
        let data = try ISO8601DateCoding.makeEncoder().encode(Stamp(at: noon.addingTimeInterval(0.25)))
        #expect(String(decoding: data, as: UTF8.self) == #"{"at":"2026-10-06T12:00:00.250Z"}"#)
    }

    @Test func roundTripKeepsMilliseconds() throws {
        let original = noon.addingTimeInterval(0.789)
        let data = try ISO8601DateCoding.makeEncoder().encode(Stamp(at: original))
        let decoded = try ISO8601DateCoding.makeDecoder().decode(Stamp.self, from: data).at
        #expect(abs(decoded.timeIntervalSince(original)) < 0.0005)
        #expect(try ISO8601DateCoding.makeEncoder().encode(Stamp(at: decoded)) == data)
    }
}
