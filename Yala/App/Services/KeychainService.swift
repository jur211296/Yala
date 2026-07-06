//
//  KeychainService.swift
//  Yala
//
//  Secure storage service using iOS Keychain.
//  Used for sensitive configuration values.
//

import Foundation
import Security

/// Service for secure storage using iOS Keychain
struct KeychainService {

    /// Service identifier for Keychain items
    private static let service = "com.yala.app"

    // MARK: - Public API

    /// Save a boolean value to Keychain
    static func setBool(_ value: Bool, forKey key: String) {
        let data = Data([value ? 1 : 0])
        save(data: data, forKey: key)
    }

    /// Get a boolean value from Keychain
    static func getBool(forKey key: String) -> Bool {
        guard let data = load(forKey: key), let byte = data.first else {
            return false
        }
        return byte == 1
    }

    /// Save an integer value to Keychain
    static func setInt(_ value: Int, forKey key: String) {
        var intValue = value
        let data = Data(bytes: &intValue, count: MemoryLayout<Int>.size)
        save(data: data, forKey: key)
    }

    /// Get an integer value from Keychain
    static func getInt(forKey key: String) -> Int {
        guard let data = load(forKey: key), data.count == MemoryLayout<Int>.size else {
            return 0
        }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }

    /// Save a string value to Keychain
    static func setString(_ value: String, forKey key: String) {
        save(data: Data(value.utf8), forKey: key)
    }

    /// Get a string value from Keychain (nil if absent)
    static func getString(forKey key: String) -> String? {
        guard let data = load(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a value from Keychain
    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private Helpers

    private static func save(data: Data, forKey key: String) {
        // Delete existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Accessible only when device is unlocked
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        #if DEBUG
        if status != errSecSuccess {
            print("KeychainService: Error saving \(key): \(status)")
        }
        #endif
    }

    private static func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }
}
