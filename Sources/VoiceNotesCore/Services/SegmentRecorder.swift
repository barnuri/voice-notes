import AVFoundation
import Foundation

@MainActor
public final class SegmentRecorder: NSObject, AudioSegmentRecording {
    private static let silenceFloorDecibels: Float = -50
    private static let finishTimeout: Duration = .seconds(5)
    private static let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 32_000,
    ]

    private let session = AVCaptureSession()
    private let output = AVCaptureAudioFileOutput()
    private let directory: URL
    private let deviceID: @MainActor () -> String?
    private var input: AVCaptureDeviceInput?
    private var recordingURL: URL?
    private var finishWaiters: [String: CheckedContinuation<Bool, Never>] = [:]

    public init(
        directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceNotes"),
        deviceID: @escaping @MainActor () -> String? = { nil }
    ) {
        self.directory = directory
        self.deviceID = deviceID
        super.init()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    public var level: Float {
        guard output.isRecording, let channel = output.connections.first?.audioChannels.first else { return 0 }
        return max(0, min(1, 1 - channel.averagePowerLevel / Self.silenceFloorDecibels))
    }

    public func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    public func start() throws {
        try attachInput(for: selectedDevice())
        if !session.isRunning {
            session.startRunning()
        }
        guard session.isRunning else { throw RecorderError.couldNotStart }
        let url = try makeSegmentURL()
        output.startRecording(to: url, outputFileType: .m4a, recordingDelegate: self)
        recordingURL = url
    }

    public func stop() async -> URL? {
        guard let url = recordingURL else { return nil }
        recordingURL = nil
        let finished = await finishRecording(url) { output.stopRecording() }
        session.stopRunning()
        return finished
    }

    public func rotate() async throws -> URL? {
        guard let previous = recordingURL else {
            try start()
            return nil
        }
        let next = try makeSegmentURL()
        recordingURL = next
        return await finishRecording(previous) {
            output.startRecording(to: next, outputFileType: .m4a, recordingDelegate: self)
        }
    }

    private func selectedDevice() throws -> AVCaptureDevice {
        let stored = deviceID().flatMap { AVCaptureDevice(uniqueID: $0) }
        guard let device = stored ?? AVCaptureDevice.default(for: .audio) else { throw RecorderError.couldNotStart }
        return device
    }

    private func attachInput(for device: AVCaptureDevice) throws {
        if let input, input.device.uniqueID == device.uniqueID, input.device.isConnected { return }
        let newInput = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if let input {
            session.removeInput(input)
            self.input = nil
        }
        guard session.canAddInput(newInput) else { throw RecorderError.couldNotStart }
        session.addInput(newInput)
        input = newInput
        output.audioSettings = Self.audioSettings
    }

    private func finishRecording(_ url: URL, trigger: () -> Void) async -> URL? {
        let isPlayable = await withCheckedContinuation { continuation in
            finishWaiters[url.lastPathComponent] = continuation
            trigger()
            scheduleFinishTimeout(for: url)
        }
        return isPlayable ? url : nil
    }

    private func scheduleFinishTimeout(for url: URL) {
        Task { [weak self] in
            try? await Task.sleep(for: Self.finishTimeout)
            self?.resolveFinish(of: url, isPlayable: false)
        }
    }

    private func resolveFinish(of url: URL, isPlayable: Bool) {
        finishWaiters.removeValue(forKey: url.lastPathComponent)?.resume(returning: isPlayable)
    }

    private func makeSegmentURL() throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("segment-\(UUID().uuidString).m4a")
    }

    private nonisolated static func isPlayable(after error: (any Error)?) -> Bool {
        guard let error else { return true }
        return (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
    }
}

extension SegmentRecorder: AVCaptureFileOutputRecordingDelegate {
    public nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        let isPlayable = Self.isPlayable(after: error)
        Task { @MainActor in
            self.resolveFinish(of: outputFileURL, isPlayable: isPlayable)
        }
    }
}
