import Foundation
import Observation

@MainActor
@Observable
public final class NoteStore {
    public var lastError: String?
    public private(set) var changeCount = 0
    private static let editSaveDelay: Duration = .milliseconds(400)
    private let fileURL: URL
    private var records: [Note] = []
    private var pendingSave: Task<Void, Never>?

    public init(fileURL: URL = NoteStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    public nonisolated static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("VoiceNotes", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    public var notes: [Note] {
        records.filter { !$0.isDeleted }
    }

    public var allRecords: [Note] {
        records
    }

    public func note(id: Note.ID) -> Note? {
        liveIndex(of: id).map { records[$0] }
    }

    public func filtered(by query: String) -> [Note] {
        notes.filter { $0.matches(query) }
    }

    @discardableResult
    public func create() -> Note {
        let note = Note()
        records.insert(note, at: 0)
        changeCount += 1
        save()
        return note
    }

    public func update(_ id: Note.ID, at date: Date = Date(), _ change: (inout Note) -> Void) {
        guard let index = liveIndex(of: id) else { return }
        change(&records[index])
        records[index].updatedAt = Self.stamp(date, after: records[index].updatedAt)
        let updated = records.remove(at: index)
        records.insert(updated, at: 0)
        changeCount += 1
        save()
    }

    public func edit(_ id: Note.ID, text: String, at date: Date = Date()) {
        guard let index = liveIndex(of: id), records[index].text != text else { return }
        records[index].text = text
        records[index].updatedAt = Self.stamp(date, after: records[index].updatedAt)
        changeCount += 1
        scheduleSave()
    }

    public func flushPendingSave() {
        guard pendingSave != nil else { return }
        save()
    }

    public func delete(_ id: Note.ID, at date: Date = Date()) {
        guard let index = liveIndex(of: id) else { return }
        records[index].text = ""
        records[index].updatedAt = Self.stamp(date, after: records[index].updatedAt)
        records[index].deletedAt = records[index].updatedAt
        changeCount += 1
        save()
    }

    public func apply(merged remote: [Note]) {
        records = NoteMerge.merge(records, remote)
        save()
    }

    private func liveIndex(of id: Note.ID) -> Int? {
        records.firstIndex { $0.id == id && !$0.isDeleted }
    }

    private static let minimumStampStep: TimeInterval = 0.001

    private static func stamp(_ date: Date, after previous: Date) -> Date {
        max(date, previous.addingTimeInterval(minimumStampStep))
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try ISO8601DateCoding.makeDecoder().decode([Note].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            let backupURL = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backupURL)
            lastError = "Your history couldn't be read, so it was moved to \(backupURL.lastPathComponent)."
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: Self.editSaveDelay)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Self.makeEncoder().encode(records).write(to: fileURL, options: .atomic)
        } catch {
            lastError = "Couldn't save your history: \(error.localizedDescription)"
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = ISO8601DateCoding.makeEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
