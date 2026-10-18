import Foundation

enum NoteMerge {
    static func merge(_ a: [Note], _ b: [Note]) -> [Note] {
        var winners: [Note.ID: Note] = [:]
        for candidate in a + b {
            if let current = winners[candidate.id], !prefers(candidate, over: current) { continue }
            winners[candidate.id] = candidate
        }
        return winners.values.sorted(by: isNewer)
    }

    private static func prefers(_ candidate: Note, over current: Note) -> Bool {
        guard candidate.updatedAt == current.updatedAt else { return candidate.updatedAt > current.updatedAt }
        return candidate.isDeleted && !current.isDeleted
    }

    private static func isNewer(_ lhs: Note, _ rhs: Note) -> Bool {
        guard lhs.updatedAt == rhs.updatedAt else { return lhs.updatedAt > rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
