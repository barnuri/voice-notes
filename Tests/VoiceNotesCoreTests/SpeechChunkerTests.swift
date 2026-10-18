import Foundation
import Testing
@testable import VoiceNotesCore

struct SpeechChunkerTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let speech: Float = 0.8
    private let silence: Float = 0.05

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    private func closes(_ chunker: inout SpeechChunker, level: Float, at seconds: TimeInterval) -> Bool {
        chunker.observe(level: level, at: at(seconds))
    }

    @Test func keepsChunkOpenBeforeMinChunkEvenAfterSilence() {
        var chunker = SpeechChunker(startedAt: start)
        #expect(!closes(&chunker, level: speech, at: 0.5))
        #expect(!closes(&chunker, level: silence, at: 1.5))
        #expect(!closes(&chunker, level: silence, at: SpeechChunker.defaultMinChunk - 0.1))
    }

    @Test func closesAfterSpeechThenSilenceGap() {
        var chunker = SpeechChunker(startedAt: start)
        #expect(!closes(&chunker, level: speech, at: SpeechChunker.defaultMinChunk))
        #expect(!closes(&chunker, level: silence, at: SpeechChunker.defaultMinChunk + 0.5))
        #expect(closes(&chunker, level: silence, at: SpeechChunker.defaultMinChunk + 0.75))
        #expect(chunker.hasSpeech)
    }

    @Test func pureSilenceStaysOpenUntilMaxChunk() {
        var chunker = SpeechChunker(startedAt: start)
        for second in stride(from: 0.0, to: SpeechChunker.defaultMaxChunk, by: 0.5) {
            #expect(!closes(&chunker, level: silence, at: second))
        }
        #expect(!chunker.hasSpeech)
    }

    @Test func forcesCloseAtMaxChunkDuringContinuousSpeech() {
        var chunker = SpeechChunker(startedAt: start)
        #expect(!closes(&chunker, level: speech, at: SpeechChunker.defaultMaxChunk - 0.1))
        #expect(closes(&chunker, level: speech, at: SpeechChunker.defaultMaxChunk))
    }

    @Test func longSpeechClosesAtBriefWordGapAfterLongChunk() {
        var chunker = SpeechChunker(startedAt: start)
        #expect(!closes(&chunker, level: speech, at: SpeechChunker.defaultLongChunk))
        #expect(!closes(&chunker, level: silence, at: SpeechChunker.defaultLongChunk + 0.1))
        #expect(closes(&chunker, level: silence, at: SpeechChunker.defaultLongChunk + 0.3))
    }

    @Test func briefWordGapEarlyDoesNotClose() {
        var chunker = SpeechChunker(startedAt: start)
        #expect(!closes(&chunker, level: speech, at: SpeechChunker.defaultMinChunk + 0.5))
        #expect(!closes(&chunker, level: silence, at: SpeechChunker.defaultMinChunk + 0.8))
    }

    @Test func resetStartsAFreshChunk() {
        var chunker = SpeechChunker(startedAt: start)
        _ = chunker.observe(level: speech, at: at(1))
        chunker.reset(at: at(SpeechChunker.defaultMaxChunk))
        #expect(!chunker.hasSpeech)
        #expect(!closes(&chunker, level: silence, at: SpeechChunker.defaultMaxChunk + 2))
    }
}
