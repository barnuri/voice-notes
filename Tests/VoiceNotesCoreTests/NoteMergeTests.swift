import Foundation
import Testing
@testable import VoiceNotesCore

struct NoteMergeTests {
    private let id = UUID()
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    @Test func laterUpdateWinsInEitherOrder() {
        let old = Note(id: id, text: "old", createdAt: earlier, updatedAt: earlier)
        let new = Note(id: id, text: "new", createdAt: earlier, updatedAt: later)
        #expect(NoteMerge.merge([old], [new]) == [new])
        #expect(NoteMerge.merge([new], [old]) == [new])
    }

    @Test func deletedWinsAnExactTie() {
        let live = Note(id: id, text: "kept?", createdAt: earlier, updatedAt: later)
        let tombstone = Note(id: id, text: "", createdAt: earlier, updatedAt: later, deletedAt: later)
        #expect(NoteMerge.merge([live], [tombstone]) == [tombstone])
        #expect(NoteMerge.merge([tombstone], [live]) == [tombstone])
    }

    @Test func editAfterDeleteRevives() {
        let tombstone = Note(id: id, text: "", createdAt: earlier, updatedAt: earlier, deletedAt: earlier)
        let revived = Note(id: id, text: "back", createdAt: earlier, updatedAt: later)
        #expect(NoteMerge.merge([tombstone], [revived]) == [revived])
    }

    @Test func keepsDistinctNotesNewestFirst() {
        let older = Note(updatedAt: earlier)
        let newer = Note(updatedAt: later)
        #expect(NoteMerge.merge([older], [newer]) == [newer, older])
    }
}
