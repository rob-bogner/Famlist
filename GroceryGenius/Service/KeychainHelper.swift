// filepath: GroceryGenius/Service/KeychainHelper.swift
// MARK: - KeychainHelper
// Lightweight wrapper around Keychain for storing small strings.
// No UIKit, only Security framework. Uses kSecAttrAccessibleAfterFirstUnlock.

import Foundation
import Security

enum KeychainHelper {
    // Use bundle identifier as service name when available to namespace entries
    private static var service: String { Bundle.main.bundleIdentifier ?? "GroceryGenius" }

    static func getString(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func setString(_ value: String, _ key: String, synchronizable: Bool = false) -> Bool {
        let data = Data(value.utf8)
        // Try update first
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        var attrsToUpdate: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        if synchronizable { attrsToUpdate[kSecAttrSynchronizable] = kCFBooleanTrue }
        let updateStatus = SecItemUpdate(query as CFDictionary, attrsToUpdate as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        // Add if update failed (e.g., item missing)
        query[kSecValueData] = data
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        if synchronizable { query[kSecAttrSynchronizable] = kCFBooleanTrue }
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        return addStatus == errSecSuccess
    }
}
