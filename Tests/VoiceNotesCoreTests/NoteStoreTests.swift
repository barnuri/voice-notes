import Foundation
import Testing
@testable import VoiceNotesCore

@MainActor
struct NoteStoreTests {
    private let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("vn-store-\(UUID())", isDirectory: true)
        .appendingPathComponent("history.json")

    @Test func persistsAcrossInstancesNewestFirst() {
        let store = NoteStore(fileURL: fileURL)
        let first = store.create()
        let second = store.create()
        store.update(first.id) { $0.text = "edited later" }

        let reloaded = NoteStore(fileURL: fileURL)
        #expect(reloaded.notes.map(\.id) == [first.id, second.id])
        #expect(reloaded.note(id: first.id)?.text == "edited later")
    }

    @Test func deleteHidesNoteAndFilterSkipsIt() {
        let store = NoteStore(fileURL: fileURL)
        let keep = store.create()
        let drop = store.create()
        store.update(keep.id) { $0.text = "Project kickoff" }
        store.update(drop.id) { $0.text = "Project kickoff draft" }
        store.delete(drop.id)

        #expect(store.notes.map(\.id) == [keep.id])
        #expect(store.note(id: drop.id) == nil)
        #expect(store.filtered(by: "kickoff").map(\.id) == [keep.id])
        #expect(store.filtered(by: "missing").isEmpty)
    }

    @Test func deleteKeepsPersistedTombstone() throws {
        let store = NoteStore(fileURL: fileURL)
        let note = store.create()
        store.update(note.id) { $0.text = "secret" }
        let deletedAt = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + 3600).rounded())
        store.delete(note.id, at: deletedAt)

        let tombstone = try #require(NoteStore(fileURL: fileURL).allRecords.first { $0.id == note.id })
        #expect(tombstone.text.isEmpty)
        #expect(tombstone.deletedAt == deletedAt)
        #expect(tombstone.updatedAt == deletedAt)
        #expect(NoteStore(fileURL: fileURL).notes.isEmpty)
    }

    @Test func updateIgnoresDeletedNote() {
        let store = NoteStore(fileURL: fileURL)
        let note = store.create()
        store.delete(note.id)
        store.update(note.id) { $0.text = "late transcript" }
        store.edit(note.id, text: "late edit")

        #expect(store.allRecords.first?.text == "")
    }

    @Test func loadsHistoryWrittenBeforeDeletedAt() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let id = UUID()
        let legacy = """
        [{"createdAt":"2026-10-06T12:00:00Z","id":"\(id.uuidString)","recordedSeconds":3,"text":"old note","updatedAt":"2026-10-06T12:00:00Z"}]
        """
        try Data(legacy.utf8).write(to: fileURL)

        let store = NoteStore(fileURL: fileURL)
        #expect(store.lastError == nil)
        #expect(store.note(id: id)?.text == "old note")
    }

    @Test func applyKeepsNewerLocalEditAndTakesNewerRemote() {
        let store = NoteStore(fileURL: fileURL)
        let local = store.create()
        let other = store.create()
        let base = Date().addingTimeInterval(3600)
        store.edit(local.id, text: "local edit", at: base.addingTimeInterval(10))
        store.edit(other.id, text: "local stale", at: base)
        let remote = [
            Note(id: local.id, text: "remote stale", createdAt: local.createdAt, updatedAt: base),
            Note(id: other.id, text: "remote edit", createdAt: other.createdAt, updatedAt: base.addingTimeInterval(20)),
        ]
        let changesBefore = store.changeCount
        store.apply(merged: remote)

        #expect(store.note(id: local.id)?.text == "local edit")
        #expect(store.note(id: other.id)?.text == "remote edit")
        #expect(store.changeCount == changesBefore)
        #expect(NoteStore(fileURL: fileURL).note(id: other.id)?.text == "remote edit")
    }

    @Test func localMutationsBumpChangeCount() {
        let store = NoteStore(fileURL: fileURL)
        let note = store.create()
        store.update(note.id) { $0.text = "a" }
        store.edit(note.id, text: "b")
        store.delete(note.id)
        #expect(store.changeCount == 4)
    }

    @Test func corruptFileIsMovedAsideNotOverwritten() throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: fileURL)
        let store = NoteStore(fileURL: fileURL)
        store.create()

        let backups = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.contains("corrupt") }
        #expect(store.lastError != nil)
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: folder.appendingPathComponent(backups[0])) == Data("{".utf8))
    }

    @Test func editKeepsOrderAndSavesAfterFlush() {
        let store = NoteStore(fileURL: fileURL)
        let older = store.create()
        let newer = store.create()
        store.edit(older.id, text: "typed")
        #expect(store.notes.map(\.id) == [newer.id, older.id])

        store.flushPendingSave()
        #expect(NoteStore(fileURL: fileURL).note(id: older.id)?.text == "typed")
    }

    @Test func localChangesAlwaysMoveUpdatedAtForward() {
        let store = NoteStore(fileURL: fileURL)
        let note = store.create()
        let ahead = note.updatedAt.addingTimeInterval(60)
        store.edit(note.id, text: "from a fast clock", at: ahead)
        store.edit(note.id, text: "local, earlier clock", at: note.updatedAt)
        let edited = store.note(id: note.id)!
        #expect(edited.updatedAt > ahead)

        store.delete(note.id, at: note.updatedAt)
        let tombstone = store.allRecords.first { $0.id == note.id }!
        #expect(tombstone.updatedAt > edited.updatedAt)
        #expect(tombstone.deletedAt == tombstone.updatedAt)
    }
}
