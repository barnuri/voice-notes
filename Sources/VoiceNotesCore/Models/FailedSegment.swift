import Foundation

public struct FailedSegment: Equatable, Sendable {
    public let audioURL: URL
    public let noteID: Note.ID
    public let hasSpeech: Bool
}
