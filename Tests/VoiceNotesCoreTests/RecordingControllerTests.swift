import Foundation
import Testing
@testable import VoiceNotesCore

@MainActor
struct RecordingControllerTests {
    private let store = NoteStore(fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("vn-ctrl-\(UUID())", isDirectory: true)
        .appendingPathComponent("history.json"))
    private let recorder = FakeRecorder()
    private let endpoint = TranscriptionEndpoint(baseURL: "https://h/v1", model: "m", apiKey: "")

    private let speech: Float = 0.8
    private let silence: Float = 0.05
    private let start = Date(timeIntervalSince1970: 1_000)

    private func controller(
        _ replies: [Result<String, TranscriptionError>],
        transcriber: FakeTranscriber? = nil,
        now: @escaping () -> Date = Date.init
    ) -> RecordingController {
        let endpoint = endpoint
        return RecordingController(
            store: store,
            recorder: recorder,
            transcriber: transcriber ?? FakeTranscriber(replies),
            endpoint: { endpoint },
            now: now,
            meterInterval: .seconds(3600)
        )
    }

    private func drain(_ controller: RecordingController) async {
        for _ in 0..<200 where controller.isTranscribing {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func pauseResumeAppendsSegmentsInOrder() async {
        let controller = controller([.success("first part."), .success("second part.")])
        await controller.record(into: nil)
        #expect(controller.phase == .recording)
        await controller.pause()
        #expect(controller.phase == .paused)
        await controller.resume()
        await controller.finish()
        await drain(controller)

        let note = store.note(id: controller.noteID!)
        #expect(note?.text == "first part. second part.")
        #expect(controller.phase == .idle)
        #expect(recorder.segments.count == 2)
    }

    @Test func appendsAfterUserEditsWhilePaused() async {
        let controller = controller([.success("one"), .success("two")])
        await controller.record(into: nil)
        await controller.pause()
        await drain(controller)
        store.update(controller.noteID!) { $0.text = "One, edited.\n" }
        await controller.resume()
        await controller.pause()
        await drain(controller)

        #expect(store.note(id: controller.noteID!)?.text == "One, edited.\ntwo")
    }

    @Test func recordsIntoSelectedNote() async {
        let existing = store.create()
        store.update(existing.id) { $0.text = "Earlier." }
        let controller = controller([.success("Later.")])
        await controller.record(into: existing.id)
        await controller.finish()
        await drain(controller)

        #expect(controller.noteID == existing.id)
        #expect(store.note(id: existing.id)?.text == "Earlier. Later.")
    }

    @Test func failedSegmentIsKeptAndRetried() async {
        let controller = controller([.failure(.unreachable(host: "h")), .success("recovered")])
        await controller.record(into: nil)
        await controller.pause()
        await drain(controller)
        #expect(controller.failedSegments.count == 1)
        #expect(controller.errorMessage?.contains("Can't reach") == true)

        controller.retryFailed()
        await drain(controller)
        #expect(controller.failedSegments.isEmpty)
        #expect(controller.errorMessage == nil)
        #expect(store.note(id: controller.noteID!)?.text == "recovered")
    }

    @Test func retryGoesBackToTheNoteThatFailed() async {
        let controller = controller([.failure(.unreachable(host: "h")), .success("later note"), .success("first note")])
        await controller.record(into: nil)
        let firstNote = controller.noteID!
        await controller.finish()
        await drain(controller)

        let second = store.create()
        await controller.record(into: second.id)
        await controller.finish()
        await drain(controller)
        controller.retryFailed()
        await drain(controller)

        #expect(store.note(id: firstNote)?.text == "first note")
        #expect(store.note(id: second.id)?.text == "later note")
    }

    @Test func failedFirstStartReturnsToIdle() async {
        recorder.failStart = true
        let controller = controller([])
        await controller.record(into: nil)
        #expect(controller.phase == .idle)
        #expect(controller.errorMessage == RecorderError.couldNotStart.errorDescription)
    }

    @Test func togglePrimaryCyclesRecordPauseResume() async {
        let controller = controller([.success("a")])
        await controller.togglePrimary(into: nil)
        #expect(controller.phase == .recording)
        #expect(controller.isRecording(into: controller.noteID!))
        await controller.togglePrimary(into: nil)
        #expect(controller.phase == .paused)
        await controller.togglePrimary(into: nil)
        #expect(controller.phase == .recording)
        await controller.finish()
        #expect(!controller.isRecording(into: controller.noteID!))
    }

    @Test func deniedPermissionShowsMessageAndStaysIdle() async {
        recorder.permission = false
        let controller = controller([])
        await controller.record(into: nil)
        #expect(controller.phase == .idle)
        #expect(controller.noteID == nil)
        #expect(controller.errorMessage == RecorderError.permissionDenied.errorDescription)
    }

    @Test func speechThenSilenceRotatesAndTranscribesWhileRecording() async {
        var current = start
        let controller = controller([.success("live part.")], now: { current })
        await controller.record(into: nil)
        current = start.addingTimeInterval(SpeechChunker.defaultMinChunk)
        await controller.tick()
        recorder.level = silence
        current = start.addingTimeInterval(SpeechChunker.defaultMinChunk + 1)
        await controller.tick()
        #expect(controller.phase == .recording)
        #expect(recorder.segments.count == 1)
        await drain(controller)

        let note = store.note(id: controller.noteID!)
        #expect(note?.text == "live part.")
        #expect(note?.recordedSeconds == SpeechChunker.defaultMinChunk + 1)
        #expect(controller.phase == .recording)
        current = start.addingTimeInterval(SpeechChunker.defaultMinChunk + 2.5)
        #expect(controller.elapsed == SpeechChunker.defaultMinChunk + 2.5)
    }

    @Test func silentChunkIsStillTranscribedOnPause() async {
        recorder.level = silence
        let transcriber = FakeTranscriber([.success("quiet words")])
        let controller = controller([], transcriber: transcriber)
        await controller.record(into: nil)
        await controller.pause()
        await drain(controller)

        #expect(transcriber.callCount == 1)
        #expect(store.note(id: controller.noteID!)?.text == "quiet words")
        #expect(controller.failedSegments.isEmpty)
    }

    @Test func silentChunkAtMaxChunkIsStillTranscribed() async {
        recorder.level = silence
        var current = start
        let transcriber = FakeTranscriber([.success("quiet words")])
        let controller = controller([], transcriber: transcriber, now: { current })
        await controller.record(into: nil)
        current = start.addingTimeInterval(SpeechChunker.defaultMaxChunk)
        await controller.tick()
        await drain(controller)

        #expect(recorder.segments.count == 1)
        #expect(transcriber.callCount == 1)
        #expect(store.note(id: controller.noteID!)?.text == "quiet words")
        #expect(store.note(id: controller.noteID!)?.recordedSeconds == SpeechChunker.defaultMaxChunk)
    }

    @Test func keepsOrderAcrossRotationAndPause() async {
        var current = start
        let controller = controller([.success("first chunk."), .success("second chunk.")], now: { current })
        await controller.record(into: nil)
        current = start.addingTimeInterval(SpeechChunker.defaultMinChunk + 0.5)
        await controller.tick()
        recorder.level = silence
        current = start.addingTimeInterval(SpeechChunker.defaultMinChunk + 1.5)
        await controller.tick()
        recorder.level = speech
        current = start.addingTimeInterval(SpeechChunker.defaultMinChunk + 3.5)
        await controller.tick()
        await controller.pause()
        await drain(controller)

        let note = store.note(id: controller.noteID!)
        #expect(note?.text == "first chunk. second chunk.")
        #expect(note?.recordedSeconds == SpeechChunker.defaultMinChunk + 3.5)
        #expect(controller.elapsed == SpeechChunker.defaultMinChunk + 3.5)
        #expect(recorder.segments.count == 2)
    }

    @Test func missingEndpointKeepsSegmentForRetry() async {
        let controller = RecordingController(
            store: store,
            recorder: recorder,
            transcriber: FakeTranscriber([]),
            endpoint: { nil }
        )
        await controller.record(into: nil)
        await controller.pause()
        await drain(controller)
        #expect(controller.failedSegments.count == 1)
        #expect(controller.errorMessage == TranscriptionError.notConfigured.errorDescription)
    }

    @Test(arguments: ["", "  \n"])
    func emptyTranscriptOfSpeechIsKeptForRetry(text: String) async {
        var current = start
        let controller = controller([.success(text), .success("second try")], now: { current })
        await controller.record(into: nil)
        current = start.addingTimeInterval(1)
        await controller.tick()
        await controller.pause()
        await drain(controller)

        #expect(controller.failedSegments.count == 1)
        #expect(controller.errorMessage == TranscriptionError.emptyResult.errorDescription)
        #expect(FileManager.default.fileExists(atPath: recorder.segments[0].path))
        #expect(store.note(id: controller.noteID!)?.text == "")

        controller.retryFailed()
        await drain(controller)
        #expect(controller.failedSegments.isEmpty)
        #expect(store.note(id: controller.noteID!)?.text == "second try")
    }

    @Test(arguments: ["", "  \n"])
    func emptyTranscriptWithoutSpeechIsDiscardedSilently(text: String) async {
        recorder.level = silence
        var current = start
        let controller = controller([.success(text)], now: { current })
        await controller.record(into: nil)
        current = start.addingTimeInterval(1)
        await controller.tick()
        await controller.pause()
        await drain(controller)

        #expect(controller.failedSegments.isEmpty)
        #expect(controller.errorMessage == nil)
        #expect(!FileManager.default.fileExists(atPath: recorder.segments[0].path))
        #expect(store.note(id: controller.noteID!)?.text == "")
    }
}
