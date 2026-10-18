import Foundation

@MainActor
public protocol AudioSegmentRecording: AnyObject {
    var level: Float { get }
    func requestPermission() async -> Bool
    func start() throws
    func stop() async -> URL?
    func rotate() async throws -> URL?
}
