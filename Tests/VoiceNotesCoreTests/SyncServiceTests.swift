import Foundation
import Testing
@testable import VoiceNotesCore

@MainActor
struct SyncServiceTests {
    private let store = NoteStore(fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("vn-sync-\(UUID())", isDirectory: true)
        .appendingPathComponent("history.json"))
    private let endpoint = SyncEndpoint(baseURL: "https://h:5555", token: "t")
    private let syncedAt = Date(timeIntervalSince1970: 1_791_288_000)

    private let ivrit = TranscriptionModel(id: "ivrit/ivrit-large-v3-turbo", title: "ivrit.ai Hebrew", description: "")
    private let whisper = TranscriptionModel(id: "whisper/whisper-large-v3-turbo", title: "Whisper large-v3-turbo", description: "")

    private func service(
        _ client: FakeSyncClient,
        endpoint: SyncEndpoint?,
        onModel: @escaping @MainActor (String) -> Void = { _ in }
    ) -> SyncService {
        let syncedAt = syncedAt
        return SyncService(store: store, client: client, endpoint: { endpoint }, onModel: onModel, now: { syncedAt })
    }

    @Test func successAppliesRemoteRecordsAndStampsTime() async {
        let local = store.create()
        let remote = Note(text: "from the web")
        let client = FakeSyncClient(.success([remote]))
        let sync = service(client, endpoint: endpoint)
        await sync.syncNow()

        #expect(client.calls.first?.map(\.id) == [local.id])
        #expect(Set(store.notes.map(\.id)) == [local.id, remote.id])
        #expect(sync.lastSyncedAt == syncedAt)
        #expect(sync.lastError == nil)
        #expect(!sync.isSyncing)
    }

    @Test func failureReportsErrorAndKeepsLocalNotes() async {
        let local = store.create()
        let sync = service(FakeSyncClient(.failure(.unauthorized)), endpoint: endpoint)
        await sync.syncNow()

        #expect(sync.lastError == SyncError.unauthorized.errorDescription)
        #expect(sync.lastSyncedAt == nil)
        #expect(store.notes.map(\.id) == [local.id])
    }

    @Test func missingEndpointDoesNothing() async {
        let client = FakeSyncClient(.success([Note()]))
        let sync = service(client, endpoint: nil)
        await sync.syncNow()

        #expect(client.calls.isEmpty)
        #expect(sync.lastSyncedAt == nil)
        #expect(store.allRecords.isEmpty)
    }

    @Test func startSyncsImmediately() async {
        let client = FakeSyncClient(.success([]))
        let sync = service(client, endpoint: endpoint)
        sync.start()
        for _ in 0..<200 where client.calls.isEmpty {
            try? await Task.sleep(for: .milliseconds(5))
        }
        sync.stop()

        #expect(client.calls.count == 1)
    }

    @Test func successfulSyncPublishesModelsAndAppliesServerModel() async {
        var applied: [String] = []
        let config = ServerConfig(model: ivrit.id, models: [ivrit, whisper])
        let sync = service(FakeSyncClient(.success([]), config: .success(config)), endpoint: endpoint) { applied.append($0) }
        await sync.syncNow()

        #expect(sync.availableModels == [ivrit, whisper])
        #expect(applied == [ivrit.id])
        #expect(sync.modelError == nil)
    }

    @Test func configFailureSetsModelErrorWithoutBreakingSync() async {
        var applied: [String] = []
        let client = FakeSyncClient(.success([]), config: .failure(.unauthorized))
        let sync = service(client, endpoint: endpoint) { applied.append($0) }
        await sync.syncNow()

        #expect(sync.lastSyncedAt == syncedAt)
        #expect(sync.lastError == nil)
        #expect(sync.modelError == SyncError.unauthorized.errorDescription)
        #expect(sync.availableModels.isEmpty)
        #expect(applied.isEmpty)
    }

    @Test func failedSyncSkipsConfig() async {
        var applied: [String] = []
        let config = ServerConfig(model: ivrit.id, models: [ivrit])
        let client = FakeSyncClient(.failure(.unauthorized), config: .success(config))
        let sync = service(client, endpoint: endpoint) { applied.append($0) }
        await sync.syncNow()

        #expect(sync.availableModels.isEmpty)
        #expect(applied.isEmpty)
    }

    @Test func selectModelAppliesServerAnswer() async {
        var applied: [String] = []
        let config = ServerConfig(model: ivrit.id, models: [ivrit, whisper])
        let client = FakeSyncClient(.success([]), config: .success(config), select: .success(whisper.id))
        let sync = service(client, endpoint: endpoint) { applied.append($0) }
        await sync.syncNow()
        await sync.selectModel(whisper.id)

        #expect(client.selections == [whisper.id])
        #expect(applied == [ivrit.id, whisper.id])
        #expect(sync.availableModels == [ivrit, whisper])
        #expect(sync.modelError == nil)
    }

    @Test func selectModelFailureKeepsModelAndReportsError() async {
        var applied: [String] = []
        let message = "unknown model"
        let client = FakeSyncClient(.success([]), select: .failure(.server(status: 400, message: message)))
        let sync = service(client, endpoint: endpoint) { applied.append($0) }
        await sync.selectModel("nope")

        #expect(client.selections == ["nope"])
        #expect(applied.isEmpty)
        #expect(sync.modelError == SyncError.server(status: 400, message: message).errorDescription)
    }
}
