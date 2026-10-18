import Foundation
import Security

public struct KeychainStore: Sendable {
    private let service: String
    private let account: String

    public init(service: String = "com.barnuri.voicenotes", account: String = "api-key") {
        self.service = service
        self.account = account
    }

    public func read() -> String {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    @discardableResult
    public func write(_ value: String) -> Bool {
        SecItemDelete(baseQuery as CFDictionary)
        guard !value.isEmpty else { return true }
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
