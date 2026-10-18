import Foundation
import os

public final class AppLog: @unchecked Sendable {
    private enum Level: String {
        case info = "INFO"
        case error = "ERROR"
    }

    public static let shared = AppLog()

    private static let logFileName = "voicenotes.log"
    private static let rotatedLogFileName = "voicenotes.1.log"
    private static let standardErrorFileName = "stderr.log"
    private static let maxLogFileBytes: UInt64 = 5_000_000

    private let queue = DispatchQueue(label: "com.barnuri.voicenotes.log")
    private let logger = Logger(subsystem: "com.barnuri.voicenotes", category: "app")
    private var logFileURL: URL?

    public static func info(_ message: String) { shared.write(.info, message) }
    public static func error(_ message: String) { shared.write(.error, message) }

    public func configure(directory: URL) {
        queue.sync {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                logger.error("Log directory \(directory.path, privacy: .public) can't be created: \(error.localizedDescription, privacy: .public)")
                return
            }
            let url = directory.appendingPathComponent(Self.logFileName)
            rotateIfTooLarge(url, rotatedURL: directory.appendingPathComponent(Self.rotatedLogFileName))
            logFileURL = url
            freopen(directory.appendingPathComponent(Self.standardErrorFileName).path, "a", stderr)
        }
    }

    private func write(_ level: Level, _ message: String) {
        switch level {
        case .info: logger.info("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
        let line = "\(Date.now.formatted(.iso8601)) \(level.rawValue) \(message)\n"
        queue.async { [weak self] in
            guard let url = self?.logFileURL else { return }
            Self.append(Data(line.utf8), to: url)
        }
    }

    private func rotateIfTooLarge(_ url: URL, rotatedURL: URL) {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        guard size > Self.maxLogFileBytes else { return }
        try? FileManager.default.removeItem(at: rotatedURL)
        try? FileManager.default.moveItem(at: url, to: rotatedURL)
    }

    private static func append(_ data: Data, to url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }
}
