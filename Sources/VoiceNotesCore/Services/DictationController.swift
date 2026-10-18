import Foundation
import Observation

@MainActor
@Observable
public final class DictationController {
    public static let defaultMeterInterval: Duration = .milliseconds(50)

    public private(set) var phase: DictationPhase = .idle {
        didSet {
            if phase != oldValue { onPhaseChange(phase) }
        }
    }
    public private(set) var level: Float = 0
    public private(set) var errorMessage: String? {
        didSet {
            if let errorMessage { AppLog.error("Dictation: \(errorMessage)") }
        }
    }

    private let recorder: AudioSegmentRecording
    private let transcriber: Transcribing
    private let endpoint: @MainActor () -> TranscriptionEndpoint?
    private let typer: TextTyping
    private let onPhaseChange: @MainActor (DictationPhase) -> Void
    private let now: () -> Date
    private let meterInterval: Duration
    @ObservationIgnored private var chunker = SpeechChunker()
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private var rotation: Task<Void, Never>?
    @ObservationIgnored private var queueTail: Task<Void, Never>?
    @ObservationIgnored private var hasTypedThisSession = false

    public init(
        recorder: AudioSegmentRecording,
        transcriber: Transcribing,
        endpoint: @escaping @MainActor () -> TranscriptionEndpoint?,
        typer: TextTyping,
        onPhaseChange: @escaping @MainActor (DictationPhase) -> Void = { _ in },
        now: @escaping () -> Date = Date.init,
        meterInterval: Duration = defaultMeterInterval
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.endpoint = endpoint
        self.typer = typer
        self.onPhaseChange = onPhaseChange
        self.now = now
        self.meterInterval = meterInterval
    }

    public func toggle() async {
        switch phase {
        case .idle: await startListening()
        case .listening, .paused: await stop()
        case .transcribing: return
        }
    }

    public func pause() async {
        guard phase == .listening else { return }
        phase = .paused
        await closeChunk()
    }

    public func resume() async {
        guard phase == .paused else { return }
        startRecording()
    }

    public func stop() async {
        guard phase == .listening || phase == .paused else { return }
        let wasListening = phase == .listening
        phase = .transcribing
        if wasListening {
            await closeChunk()
        }
        await queueTail?.value
        phase = .idle
    }

    func tick() async {
        level = recorder.level
        guard phase == .listening, rotation == nil,
              chunker.observe(level: recorder.level, at: now()) else { return }
        let task = Task { await self.rotateChunk() }
        rotation = task
        await task.value
        rotation = nil
    }

    private func startListening() async {
        errorMessage = nil
        guard await recorder.requestPermission() else {
            errorMessage = RecorderError.permissionDenied.errorDescription
            return
        }
        guard phase == .idle else { return }
        guard endpoint() != nil else {
            errorMessage = TranscriptionError.notConfigured.errorDescription
            return
        }
        hasTypedThisSession = false
        startRecording()
    }

    private func startRecording() {
        do {
            try recorder.start()
            chunker.reset(at: now())
            phase = .listening
            startMetering()
        } catch {
            errorMessage = error.userMessage
        }
    }

    private func closeChunk() async {
        meterTask?.cancel()
        level = 0
        await rotation?.value
        let hasSpeech = chunker.hasSpeech
        guard let url = await recorder.stop() else {
            errorMessage = DictationError.recordingNotSaved.errorDescription
            return
        }
        enqueue(url, hasSpeech: hasSpeech)
    }

    private func rotateChunk() async {
        let hasSpeech = chunker.hasSpeech
        do {
            let url = try await recorder.rotate()
            chunker.reset(at: now())
            if let url { enqueue(url, hasSpeech: hasSpeech) }
        } catch {
            errorMessage = error.userMessage
        }
    }

    private func enqueue(_ url: URL, hasSpeech: Bool) {
        let previous = queueTail
        queueTail = Task { [weak self] in
            await previous?.value
            await self?.transcribeAndType(url, hasSpeech: hasSpeech)
        }
    }

    private func transcribeAndType(_ url: URL, hasSpeech: Bool) async {
        defer { try? FileManager.default.removeItem(at: url) }
        guard hasSpeech, let endpoint = endpoint() else { return }
        do {
            let text = try await transcriber.transcribe(fileURL: url, endpoint: endpoint)
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            guard !text.isEmpty else { return }
            try typer.type(hasTypedThisSession ? " " + text : text)
            hasTypedThisSession = true
        } catch {
            errorMessage = error.userMessage
        }
    }

    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                try? await Task.sleep(for: self.meterInterval)
            }
        }
    }
}
