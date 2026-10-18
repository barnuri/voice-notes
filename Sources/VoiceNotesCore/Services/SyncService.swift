import Foundation
import Observation

@MainActor
@Observable
public final class SyncService {
    private static let syncInterval: Duration = .seconds(30)
    private static let changeDebounce: Duration = .seconds(2)
    private static let pollInterval: Duration = .milliseconds(500)

    public private(set) var lastSyncedAt: Date?
    public private(set) var lastError: String? {
        didSet {
            if let lastError, lastError != oldValue { AppLog.error("Sync: \(lastError)") }
        }
    }
    public private(set) var isSyncing = false
    public private(set) var availableModels: [TranscriptionModel] = []
    public private(set) var modelError: String? {
        didSet {
            if let modelError, modelError != oldValue { AppLog.error("Models: \(modelError)") }
        }
    }

    private let store: NoteStore
    private let client: Syncing
    private let endpoint: @MainActor () -> SyncEndpoint?
    private let onModel: @MainActor (String) -> Void
    private let clock: any Clock<Duration>
    private let now: () -> Date
    private var scheduleTask: Task<Void, Never>?

    public init(
        store: NoteStore,
        client: Syncing,
        endpoint: @escaping @MainActor () -> SyncEndpoint?,
        onModel: @escaping @MainActor (String) -> Void,
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.client = client
        self.endpoint = endpoint
        self.onModel = onModel
        self.clock = clock
        self.now = now
    }

    public func syncNow() async {
        guard !isSyncing, let endpoint = endpoint() else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let merged = try await client.sync(store.allRecords, endpoint: endpoint)
            store.apply(merged: merged)
            lastSyncedAt = now()
            lastError = nil
        } catch {
            lastError = error.userMessage
            return
        }
        await refreshConfig(endpoint: endpoint)
    }

    public func selectModel(_ id: String) async {
        guard let endpoint = endpoint() else { return }
        do {
            onModel(try await client.selectModel(id, endpoint: endpoint))
            modelError = nil
        } catch {
            modelError = error.userMessage
        }
    }

    public func start() {
        guard scheduleTask == nil else { return }
        scheduleTask = Task { [weak self] in
            await self?.syncNow()
            await self?.runSchedule()
        }
    }

    public func stop() {
        scheduleTask?.cancel()
        scheduleTask = nil
    }

    private func refreshConfig(endpoint: SyncEndpoint) async {
        do {
            let config = try await client.fetchConfig(endpoint: endpoint)
            availableModels = config.models
            onModel(config.model)
            modelError = nil
        } catch {
            modelError = error.userMessage
        }
    }

    private func runSchedule() async {
        var observedChangeCount = store.changeCount
        var sinceLastSync: Duration = .zero
        var sinceLastChange: Duration?
        while !Task.isCancelled {
            try? await clock.sleep(for: Self.pollInterval)
            sinceLastSync += Self.pollInterval
            sinceLastChange = sinceLastChange.map { $0 + Self.pollInterval }
            if store.changeCount != observedChangeCount {
                observedChangeCount = store.changeCount
                sinceLastChange = .zero
            }
            let changesSettled = sinceLastChange.map { $0 >= Self.changeDebounce } ?? false
            guard !Task.isCancelled, changesSettled || sinceLastSync >= Self.syncInterval else { continue }
            await syncNow()
            sinceLastSync = .zero
            sinceLastChange = nil
        }
    }
}
