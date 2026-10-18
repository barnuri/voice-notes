import Foundation
@testable import VoiceNotesCore

@MainActor
final class FakeRecorder: AudioSegmentRecording {
    var permission = true
    var failStart = false
    private(set) var segments: [URL] = []
    private var active: URL?

    var level: Float = 0.8

    func requestPermission() async -> Bool { permission }

    func start() throws {
        if failStart { throw RecorderError.couldNotStart }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fake-\(UUID()).m4a")
        try Data("AUDIO".utf8).write(to: url)
        active = url
    }

    func stop() async -> URL? {
        await Task.yield()
        defer { active = nil }
        if let active { segments.append(active) }
        return active
    }

    func rotate() async throws -> URL? {
        let finished = await stop()
        try start()
        return finished
    }
}
