import Foundation
import Security

/// Generic passwords remain local to the user's Keychain. Never log input data.
struct KeychainStore {
    let service: String

    init(service: String = "com.calli.secrets") {
        self.service = service
    }

    struct Failure: Error {
        let status: OSStatus
    }

    func get(account: String) throws -> Data? {
        var query = itemQuery(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure(status: status) }
        guard let data = result as? Data else { throw Failure(status: errSecDecode) }
        return data
    }

    func set(_ data: Data, account: String) throws {
        let query = itemQuery(account: account)
        let attributes: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData] = data
            newItem[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(newItem as CFDictionary, nil)
            // Another writer may have inserted the account after our update.
            if status == errSecDuplicateItem {
                status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            }
        }
        guard status == errSecSuccess else { throw Failure(status: status) }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(itemQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure(status: status)
        }
    }

    private func itemQuery(account: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: account,
         kSecAttrSynchronizable: false]
    }
}
