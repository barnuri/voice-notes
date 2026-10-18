import Foundation

public struct SpeechChunker: Sendable {
    public static let defaultVoiceLevel: Float = 0.2
    public static let defaultMinChunk: TimeInterval = 5
    public static let defaultSilenceGap: TimeInterval = 0.7
    public static let defaultLongChunk: TimeInterval = 12
    public static let defaultWordGap: TimeInterval = 0.25
    public static let defaultMaxChunk: TimeInterval = 20

    public let voiceLevel: Float
    public let minChunk: TimeInterval
    public let silenceGap: TimeInterval
    public let longChunk: TimeInterval
    public let wordGap: TimeInterval
    public let maxChunk: TimeInterval
    public private(set) var hasSpeech = false
    private var chunkStartedAt: Date
    private var lastSpeechAt: Date?

    public init(
        voiceLevel: Float = SpeechChunker.defaultVoiceLevel,
        minChunk: TimeInterval = SpeechChunker.defaultMinChunk,
        silenceGap: TimeInterval = SpeechChunker.defaultSilenceGap,
        longChunk: TimeInterval = SpeechChunker.defaultLongChunk,
        wordGap: TimeInterval = SpeechChunker.defaultWordGap,
        maxChunk: TimeInterval = SpeechChunker.defaultMaxChunk,
        startedAt: Date = Date()
    ) {
        self.voiceLevel = voiceLevel
        self.minChunk = minChunk
        self.silenceGap = silenceGap
        self.longChunk = longChunk
        self.wordGap = wordGap
        self.maxChunk = maxChunk
        chunkStartedAt = startedAt
    }

    public mutating func reset(at date: Date) {
        chunkStartedAt = date
        lastSpeechAt = nil
        hasSpeech = false
    }

    public mutating func observe(level: Float, at date: Date) -> Bool {
        if level >= voiceLevel {
            hasSpeech = true
            lastSpeechAt = date
        }
        let age = date.timeIntervalSince(chunkStartedAt)
        if age >= maxChunk { return true }
        guard age >= minChunk, let lastSpeechAt else { return false }
        let quietFor = date.timeIntervalSince(lastSpeechAt)
        return quietFor >= silenceGap || (age >= longChunk && quietFor >= wordGap)
    }
}
