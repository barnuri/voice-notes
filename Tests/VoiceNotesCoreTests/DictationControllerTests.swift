import Foundation
import Testing
@testable import VoiceNotesCore

@MainActor
struct DictationControllerTests {
    private let recorder = FakeRecorder()
    private let typer = FakeTyper()
    private let endpoint = TranscriptionEndpoint(baseURL: "https://h/v1", model: "m", apiKey: "")
    private let silence: Float = 0.05
    private let start = Date(timeIntervalSince1970: 1_000)

    private func controller(
        _ replies: [Result<String, TranscriptionError>],
        endpoint: TranscriptionEndpoint? = nil,
        onPhaseChange: @escaping @MainActor (DictationPhase) -> Void = { _ in },
        now: @escaping () -> Date = Date.init
    ) -> DictationController {
        let resolved = endpoint ?? self.endpoint
        return DictationController(
            recorder: recorder,
            transcriber: FakeTranscriber(replies),
            endpoint: { resolved },
            typer: typer,
            onPhaseChange: onPhaseChange,
            now: now,
            meterInterval: .seconds(3600)
        )
    }

    private func speakThenStop(_ controller: DictationController) async {
        await controller.toggle()
        await controller.tick()
        await controller.toggle()
    }

    @Test func toggleTwiceTypesTrimmedTranscript() async {
        let controller = controller([.success("  שלום, deploy done \n")])
        await controller.toggle()
        #expect(controller.phase == .listening)
        await controller.tick()
        await controller.toggle()
        #expect(controller.phase == .idle)
        #expect(typer.typed == ["שלום, deploy done"])
        #expect(controller.errorMessage == nil)
    }

    @Test func reportsPhaseChangesInOrder() async {
        var phases: [DictationPhase] = []
        let controller = controller([.success("hi")]) { phases.append($0) }
        await speakThenStop(controller)
        #expect(phases == [.listening, .transcribing, .idle])
    }

    @Test func emptyTranscriptTypesNothing() async {
        let controller = controller([.success("   ")])
        await speakThenStop(controller)
        #expect(typer.typed.isEmpty)
        #expect(controller.errorMessage == nil)
    }

    @Test func deniedPermissionStaysIdle() async {
        recorder.permission = false
        let controller = controller([])
        await controller.toggle()
        #expect(controller.phase == .idle)
        #expect(controller.errorMessage == RecorderError.permissionDenied.errorDescription)
    }

    @Test func recorderFailureStaysIdle() async {
        recorder.failStart = true
        let controller = controller([])
        await controller.toggle()
        #expect(controller.phase == .idle)
        #expect(controller.errorMessage == RecorderError.couldNotStart.errorDescription)
    }

    @Test func transcriptionErrorIsReportedAndNothingTyped() async {
        let controller = controller([.failure(.unreachable(host: "h"))])
        await speakThenStop(controller)
        #expect(controller.phase == .idle)
        #expect(typer.typed.isEmpty)
        #expect(controller.errorMessage == TranscriptionError.unreachable(host: "h").errorDescription)
    }

    @Test func typingErrorIsReported() async {
        typer.failure = .accessibilityDenied
        let controller = controller([.success("hello")])
        await speakThenStop(controller)
        #expect(controller.errorMessage == DictationError.accessibilityDenied.errorDescription)
    }

    @Test func removesRecordingAfterTyping() async throws {
        let controller = controller([.success("hello")])
        await speakThenStop(controller)
        let url = try #require(recorder.segments.first)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func typesEachChunkWhileStillListening() async {
        var current = start
        let controller = controller([.success("first part."), .success("second part.")], now: { current })
        await controller.toggle()
        current = start.addingTimeInterval(SpeechChunker.defaultMinChunk)
        await controller.tick()
        recorder.level = silence
        current = start.addingTimeInterval(SpeechChunker.defaultMinChunk + 1)
        await controller.tick()
        for _ in 0..<200 where typer.typed.isEmpty {
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(controller.phase == .listening)
        #expect(typer.typed == ["first part."])

        recorder.level = 0.8
        await controller.tick()
        await controller.toggle()
        #expect(typer.typed == ["first part.", " second part."])
    }

    @Test func silentChunkIsNotTranscribed() async {
        recorder.level = silence
        let transcriber = FakeTranscriber([.success("תודה רבה")])
        let controller = DictationController(
            recorder: recorder,
            transcriber: transcriber,
            endpoint: { [endpoint] in endpoint },
            typer: typer
        )
        await speakThenStop(controller)
        #expect(transcriber.callCount == 0)
        #expect(typer.typed.isEmpty)
    }

    @Test func missingEndpointDoesNotStartListening() async {
        let controller = DictationController(
            recorder: recorder,
            transcriber: FakeTranscriber([]),
            endpoint: { nil },
            typer: typer
        )
        await controller.toggle()
        #expect(controller.phase == .idle)
        #expect(controller.errorMessage == TranscriptionError.notConfigured.errorDescription)
    }

    @Test func pauseTypesSpokenChunkThenResumeContinues() async {
        let controller = controller([.success("before pause."), .success("after pause.")])
        await speakThenPause(controller)
        #expect(controller.phase == .paused)
        #expect(controller.level == 0)
        await controller.resume()
        #expect(controller.phase == .listening)
        await controller.tick()
        await controller.stop()
        #expect(controller.phase == .idle)
        #expect(typer.typed == ["before pause.", " after pause."])
        #expect(recorder.segments.count == 2)
    }

    @Test func stopWhilePausedFinishesWithoutError() async {
        let controller = controller([.success("only part.")])
        await speakThenPause(controller)
        await controller.toggle()
        #expect(controller.phase == .idle)
        #expect(controller.errorMessage == nil)
        #expect(typer.typed == ["only part."])
    }

    @Test func tickPublishesLevel() async {
        let controller = controller([])
        await controller.toggle()
        recorder.level = 0.4
        await controller.tick()
        #expect(controller.level == 0.4)
        await controller.stop()
    }

    private func speakThenPause(_ controller: DictationController) async {
        await controller.toggle()
        await controller.tick()
        await controller.pause()
    }
}
