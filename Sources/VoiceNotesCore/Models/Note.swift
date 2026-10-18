import Foundation

public struct Note: Codable, Identifiable, Equatable, Sendable {
    private static let titleLength = 60
    private static let hyphenLineBreak = #"-\s*\n\s*"#

    public let id: UUID
    public var text: String
    public let createdAt: Date
    public var updatedAt: Date
    public var recordedSeconds: TimeInterval
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        text: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        recordedSeconds: TimeInterval = 0,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recordedSeconds = recordedSeconds
        self.deletedAt = deletedAt
    }

    public var isDeleted: Bool { deletedAt != nil }

    public var title: String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard !firstLine.isEmpty else { return "New note" }
        guard firstLine.count > Self.titleLength else { return firstLine }
        return String(firstLine.prefix(Self.titleLength)) + "…"
    }

    public func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(trimmed)
    }

    public mutating func append(transcript: String, at date: Date = Date()) {
        let addition = transcript
            .replacingOccurrences(of: Self.hyphenLineBreak, with: "-", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !addition.isEmpty else { return }
        let needsSpace = !(text.last?.isWhitespace ?? true)
        text += (needsSpace ? " " : "") + addition
        updatedAt = date
    }
}
