import Foundation
import Observation

@MainActor
@Observable
public final class RecordingController {
    public static let defaultMeterInterval: Duration = .milliseconds(50)

    public private(set) var phase: RecordingPhase = .idle
    public private(set) var noteID: Note.ID?
    public private(set) var level: Float = 0
    public private(set) var pendingSegments = 0
    public private(set) var failedSegments: [FailedSegment] = []
    public var errorMessage: String? {
        didSet {
            if let errorMessage { AppLog.error("Recording: \(errorMessage)") }
        }
    }

    private let store: NoteStore
    private let recorder: AudioSegmentRecording
    private let transcriber: Transcribing
    private let endpoint: @MainActor () -> TranscriptionEndpoint?
    private let now: () -> Date
    private let meterInterval: Duration
    private var segmentStartedAt: Date?
    private var finishedSeconds: TimeInterval = 0
    private var chunker = SpeechChunker()
    private var meterTask: Task<Void, Never>?
    private var queueTail: Task<Void, Never>?
    private var operationTail: Task<Void, Never>?

    public init(
        store: NoteStore,
        recorder: AudioSegmentRecording,
        transcriber: Transcribing,
        endpoint: @escaping @MainActor () -> TranscriptionEndpoint?,
        now: @escaping () -> Date = Date.init,
        meterInterval: Duration = defaultMeterInterval
    ) {
        self.store = store
        self.recorder = recorder
        self.transcriber = transcriber
        self.endpoint = endpoint
        self.now = now
        self.meterInterval = meterInterval
    }

    public var elapsed: TimeInterval {
        guard let segmentStartedAt else { return finishedSeconds }
        return finishedSeconds + now().timeIntervalSince(segmentStartedAt)
    }

    public var isTranscribing: Bool { pendingSegments > 0 }

    public func isRecording(into id: Note.ID) -> Bool {
        phase != .idle && noteID == id
    }

    public func togglePrimary(into selectedNoteID: Note.ID?) async {
        switch phase {
        case .idle: await record(into: selectedNoteID)
        case .recording: await pause()
        case .paused: await resume()
        }
    }

    public func record(into existingNoteID: Note.ID?) async {
        guard phase == .idle else { return }
        guard await recorder.requestPermission() else {
            errorMessage = RecorderError.permissionDenied.errorDescription
            return
        }
        await serialized {
            guard self.phase == .idle else { return }
            let targetID = existingNoteID.flatMap { self.store.note(id: $0)?.id } ?? self.store.create().id
            self.noteID = targetID
            self.finishedSeconds = 0
            self.startSegment(phaseOnFailure: .idle)
        }
    }

    public func pause() async {
        await serialized {
            guard self.phase == .recording else { return }
            await self.closeSegment()
            self.phase = .paused
        }
    }

    public func resume() async {
        await serialized {
            guard self.phase == .paused else { return }
            self.startSegment(phaseOnFailure: .paused)
        }
    }

    public func finish() async {
        await serialized {
            if self.phase == .recording {
                await self.closeSegment()
            }
            self.phase = .idle
            self.finishedSeconds = 0
        }
    }

    public func retryFailed() {
        let retries = failedSegments
        failedSegments.removeAll()
        errorMessage = nil
        retries.forEach { enqueue($0.audioURL, noteID: $0.noteID, hasSpeech: $0.hasSpeech) }
    }

    private func startSegment(phaseOnFailure: RecordingPhase) {
        do {
            try recorder.start()
            let startedAt = now()
            segmentStartedAt = startedAt
            chunker.reset(at: startedAt)
            phase = .recording
            errorMessage = nil
            startMetering()
        } catch {
            errorMessage = Self.recorderErrorMessage(for: error)
            phase = phaseOnFailure
        }
    }

    func tick() async {
        level = recorder.level
        guard phase == .recording, chunker.observe(level: level, at: now()) else { return }
        await serialized { await self.rotateSegment() }
    }

    private func rotateSegment() async {
        guard phase == .recording else { return }
        let hasSpeech = chunker.hasSpeech
        let rotatedAt = now()
        let url: URL?
        do {
            url = try await recorder.rotate()
        } catch {
            errorMessage = Self.recorderErrorMessage(for: error)
            await closeSegment()
            phase = .paused
            return
        }
        let seconds = takeSegmentSeconds(until: rotatedAt)
        segmentStartedAt = rotatedAt
        chunker.reset(at: rotatedAt)
        complete(url, seconds: seconds, hasSpeech: hasSpeech)
    }

    private func closeSegment() async {
        meterTask?.cancel()
        level = 0
        let seconds = takeSegmentSeconds(until: now())
        let hasSpeech = chunker.hasSpeech
        segmentStartedAt = nil
        complete(await recorder.stop(), seconds: seconds, hasSpeech: hasSpeech)
    }

    private func takeSegmentSeconds(until date: Date) -> TimeInterval {
        let seconds = segmentStartedAt.map { date.timeIntervalSince($0) } ?? 0
        finishedSeconds += seconds
        return seconds
    }

    private func complete(_ url: URL?, seconds: TimeInterval, hasSpeech: Bool) {
        guard let noteID, let url else { return }
        store.update(noteID) { $0.recordedSeconds += seconds }
        enqueue(url, noteID: noteID, hasSpeech: hasSpeech)
    }

    private func enqueue(_ url: URL, noteID: Note.ID, hasSpeech: Bool) {
        pendingSegments += 1
        let previous = queueTail
        queueTail = Task { [weak self] in
            await previous?.value
            await self?.transcribe(url, noteID: noteID, hasSpeech: hasSpeech)
        }
    }

    private func transcribe(_ url: URL, noteID: Note.ID, hasSpeech: Bool) async {
        defer { pendingSegments -= 1 }
        guard let endpoint = endpoint() else {
            keepForRetry(url, noteID: noteID, hasSpeech: hasSpeech, error: TranscriptionError.notConfigured)
            return
        }
        do {
            let text = try await transcriber.transcribe(fileURL: url, endpoint: endpoint)
            let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isEmpty, !hasSpeech {
                try? FileManager.default.removeItem(at: url)
                return
            }
            guard !isEmpty else { throw TranscriptionError.emptyResult }
            let completedAt = now()
            store.update(noteID) { $0.append(transcript: text, at: completedAt) }
            try? FileManager.default.removeItem(at: url)
        } catch {
            keepForRetry(url, noteID: noteID, hasSpeech: hasSpeech, error: error)
        }
    }

    private func keepForRetry(_ url: URL, noteID: Note.ID, hasSpeech: Bool, error: Error) {
        failedSegments.append(FailedSegment(audioURL: url, noteID: noteID, hasSpeech: hasSpeech))
        errorMessage = error.userMessage
    }

    private static func recorderErrorMessage(for error: Error) -> String? {
        (error as? LocalizedError)?.errorDescription ?? RecorderError.couldNotStart.errorDescription
    }

    private func serialized(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = operationTail
        let current = Task {
            await previous?.value
            await operation()
        }
        operationTail = current
        await current.value
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
