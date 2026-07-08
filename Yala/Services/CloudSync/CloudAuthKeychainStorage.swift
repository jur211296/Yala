//
//  CloudAuthKeychainStorage.swift
//  Yala
//
//  Storage de la sesión de Supabase Auth (JWT + refresh token) conforme al protocolo `AuthLocalStorage`
//  del SDK. Queries Keychain DEDICADAS (service propio) — NO reutiliza `KeychainService` a propósito:
//  aquel usa `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` y otros consumidores dependen de él; el
//  refresh token del Modo Nube necesita `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` para que el
//  auto-refresh en background (tras un reboot, sin desbloqueo aún) pueda leer/rotar la sesión.
//
//  `ThisDeviceOnly`: la sesión JAMÁS viaja al Keychain de iCloud (cada device firma su propia sesión).
//  `nonisolated` + `Sendable`: el SDK invoca `store/retrieve/remove` desde su propio executor.
//

import Foundation
import Security

import Auth

/// Persistencia Keychain de la sesión de auth, aislada de `KeychainService`.
nonisolated struct CloudAuthKeychainStorage: AuthLocalStorage {

    /// Service Keychain propio (namespacing dedicado; NO colisiona con `com.yala.app` de KeychainService).
    private let service: String

    init(service: String = "com.yala.cloudauth") {
        self.service = service
    }

    // MARK: - AuthLocalStorage

    func store(key: String, value: Data) throws {
        // SecItemUpdate-primero con fallback a SecItemAdd (fix R2 #4): el patrón delete-then-add deja
        // una ventana sin item si el proceso muere entre ambos; update es atómico para el caso común
        // (rotación del refresh token). El add del fallback fija la accesibilidad.
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let update: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = value
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw CloudAuthKeychainError.osStatus(addStatus)
            }
        default:
            throw CloudAuthKeychainError.osStatus(updateStatus)
        }
    }

    func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw CloudAuthKeychainError.osStatus(status)
        }
    }

    func remove(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CloudAuthKeychainError.osStatus(status)
        }
    }
}

/// Error tipado del Keychain (sin PII — solo el `OSStatus`).
nonisolated enum CloudAuthKeychainError: Error, Equatable {
    case osStatus(OSStatus)
}
