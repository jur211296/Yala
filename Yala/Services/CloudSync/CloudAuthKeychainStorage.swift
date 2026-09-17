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

// MARK: - Purga del service entero (frontera de persona)

extension CloudAuthKeychainStorage {

    /// **Borra TODO lo que este service guarda**, no una lista de keys.
    ///
    /// Bajo `com.yala.cloudauth` viven CINCO cosas y todas son credenciales de la persona que firmó:
    /// la sesión del SDK (`storageKey` de `AuthClient`), el perfil capturado (correo, nombre,
    /// `appleUserID`), el provider del último sign-in, el PAR SIWA (refresh token de Apple) y el PAR
    /// Google. En una frontera de relevo —«Empezar desde cero», o el primer arranque tras instalar en un
    /// teléfono que cambió de dueño— no hay ninguna que deba quedarse, y una lista de `account` sería
    /// exactamente por donde divergiría de lo que este service acabe guardando mañana.
    ///
    /// **No sustituye a `CloudAuthService.signOut()`, va DESPUÉS de él.** El `AuthClient` se construye
    /// con `autoRefreshToken: true`: su refresco en vuelo REPONDRÍA la sesión sobre el llavero recién
    /// purgado. Primero se para al SDK (que además limpia su copia en memoria), luego se barre lo que
    /// el sign-out conserva a propósito —los dos pares de provider— y lo que no llega a tocar cuando el
    /// backend no está configurado (`guard let client else { return }`).
    ///
    /// - Returns: `true` si el service quedó vacío. `errSecItemNotFound` es éxito (no había nada).
    ///   Un `false` es la diferencia entre un residuo temporal y uno permanente: quien lo llame no debe
    ///   escribir su marca de «ya hecho» sin mirarlo.
    func purgeAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// ¿El service quedó vacío? **No es cinturón sobre tirantes: es la única forma de saber que la purga
    /// se sostuvo.** `CloudAuthService.signOut()` NO para el auto-refresh del SDK —`stopAutoRefreshToken`
    /// no se llama en ningún sitio del repo, medido— así que un refresco que ya estaba en vuelo puede
    /// aterrizar DESPUÉS del `SecItemDelete` y volver a escribir la sesión. Sin esta lectura, el retiro se
    /// daría por hecho, el arm se borraría y la sesión de la persona anterior quedaría resucitada **para
    /// siempre**, con un breadcrumb diciendo que todo fue bien.
    ///
    /// Un error del Keychain que no sea `errSecItemNotFound` se lee como «no está vacío»: ante la duda,
    /// el arm se conserva y el arranque siguiente lo reintenta.
    func isEmpty() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecItemNotFound
    }
}
