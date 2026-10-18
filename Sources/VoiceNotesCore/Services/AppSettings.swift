import Foundation
import Observation

@MainActor
@Observable
public final class AppSettings {
    public nonisolated static let defaultBaseURL = "http://127.0.0.1:8888/v1"
    public nonisolated static let defaultModel = "whisper/whisper-large-v3"
    public nonisolated static let defaultSyncURL = "http://127.0.0.1:5555"
    public nonisolated static let syncTokenFilePath = "~/.config/voice-notes/token"
    public nonisolated static let systemDefaultMicrophoneID = ""
    private static let baseURLKey = "baseURL"
    private static let modelKey = "model"
    private static let syncURLKey = "syncURL"
    private static let languageKey = "transcriptionLanguage"
    private static let microphoneIDKey = "microphoneID"
    private static let dictationHotKeyKey = "dictationHotKey"
    private static let logDirectoryKey = "logDirectory"
    private static let defaultLogDirectoryPath = "~/Library/Logs/VoiceNotes"

    public var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Self.baseURLKey) }
    }
    public var model: String {
        didSet { defaults.set(model, forKey: Self.modelKey) }
    }
    public var apiKey: String {
        didSet { keychain.write(apiKey) }
    }
    public var syncURL: String {
        didSet { defaults.set(syncURL, forKey: Self.syncURLKey) }
    }
    public var syncToken: String {
        didSet { syncKeychain.write(syncToken) }
    }
    public var language: TranscriptionLanguage {
        didSet { defaults.set(language.rawValue, forKey: Self.languageKey) }
    }
    public var microphoneID: String {
        didSet { defaults.set(microphoneID, forKey: Self.microphoneIDKey) }
    }
    public var dictationHotKey: HotKey {
        didSet { defaults.set(try? JSONEncoder().encode(dictationHotKey), forKey: Self.dictationHotKeyKey) }
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let syncKeychain: KeychainStore

    public init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore(),
        syncKeychain: KeychainStore = KeychainStore(account: "sync-token")
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.syncKeychain = syncKeychain
        baseURL = defaults.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL
        model = defaults.string(forKey: Self.modelKey) ?? Self.defaultModel
        apiKey = keychain.read()
        syncURL = defaults.string(forKey: Self.syncURLKey) ?? Self.defaultSyncURL
        syncToken = syncKeychain.read()
        language = defaults.string(forKey: Self.languageKey).flatMap(TranscriptionLanguage.init(rawValue:)) ?? .hebrewWithEnglish
        microphoneID = defaults.string(forKey: Self.microphoneIDKey) ?? Self.systemDefaultMicrophoneID
        dictationHotKey = defaults.data(forKey: Self.dictationHotKeyKey)
            .flatMap { try? JSONDecoder().decode(HotKey.self, from: $0) } ?? .defaultDictation
    }

    public var logDirectory: URL {
        let path = defaults.string(forKey: Self.logDirectoryKey) ?? Self.defaultLogDirectoryPath
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }

    public var transcriptionEndpoint: TranscriptionEndpoint? {
        TranscriptionEndpoint(baseURL: baseURL, model: model, apiKey: apiKey, language: language)
    }

    public var effectiveSyncToken: String {
        let typed = syncToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.isEmpty else { return typed }
        guard let contents = try? String(contentsOf: Self.syncTokenFileURL, encoding: .utf8) else { return "" }
        return contents.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var syncEndpoint: SyncEndpoint? {
        SyncEndpoint(baseURL: syncURL, token: effectiveSyncToken)
    }

    public func resetConnection() {
        baseURL = Self.defaultBaseURL
        model = Self.defaultModel
    }

    private static var syncTokenFileURL: URL {
        URL(fileURLWithPath: (syncTokenFilePath as NSString).expandingTildeInPath)
    }
}
