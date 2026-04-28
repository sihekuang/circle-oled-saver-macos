import Foundation
import Security

/// Small wrapper around macOS Keychain (Keychain Services) for storing a single
/// secret string per service. Used to persist the Anthropic credential the
/// user pastes into Settings — either an OAuth access token or an Admin API
/// key.
public enum KeychainStore {
    public enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    /// Keychain service identifier for Circle's stored Anthropic credential.
    /// Both CircleApp and CircleSaver read from this same service.
    public static let claudeCredentialService = "com.shoebillsoft.circle.claude-credential"

    /// Fetches the secret stored under `service`, or nil if absent.
    public static func get(service: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Writes `value` under `service`, replacing any existing entry.
    public static func set(_ value: String, service: String) throws {
        let data = Data(value.utf8)
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]

        // Try update first; fall back to add.
        let updateAttrs: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    /// Removes the entry under `service`.
    @discardableResult
    public static func delete(service: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
