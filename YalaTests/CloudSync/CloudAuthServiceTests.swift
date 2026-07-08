//
//  CloudAuthServiceTests.swift
//  YalaTests / CloudSync
//
//  Lógica pura del subsistema de auth I7c que se puede testear sin red ni device:
//   - nonce: charset URL-safe, longitud, raw≠hashed, SHA-256 hex correcto (vector conocido).
//   - CloudBackendConfig: `isConfigured` en el scheme de tests (DEV_BUILD → staging configurado).
//   - CloudAuthKeychainStorage: round-trip + el atributo de accesibilidad es
//     `AfterFirstUnlockThisDeviceOnly` (crítico para el auto-refresh en background).
//

import Foundation
import Security
import Testing

@testable import Yala

@Suite("CloudAuth · nonce + config + storage I7c")
struct CloudAuthServiceTests {

    // MARK: - Nonce

    @Test func nonce_lengthAndCharset() {
        let nonce = CloudAuthService.randomNonceString(length: 40)
        #expect(nonce.count == 40)
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        #expect(nonce.allSatisfy { allowed.contains($0) })
    }

    @Test func nonce_isRandom_notRepeating() {
        #expect(CloudAuthService.randomNonceString() != CloudAuthService.randomNonceString())
    }

    @Test func sha256Hex_knownVector() {
        // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
        #expect(CloudAuthService.sha256Hex("abc")
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func sha256Hex_lengthAndRawDiffersFromHashed() {
        let raw = CloudAuthService.randomNonceString()
        let hashed = CloudAuthService.sha256Hex(raw)
        #expect(hashed.count == 64)  // 32 bytes en hex
        #expect(hashed != raw)       // el request de Apple lleva el HASH, signInWithIdToken el RAW
        #expect(hashed.allSatisfy { $0.isHexDigit && ($0.isNumber || $0.isLowercase) })
    }

    // MARK: - Config

    @Test func config_isConfigured_inTestScheme() {
        // Los tests corren bajo Yala Dev (DEV_BUILD) → staging configurado.
        #expect(CloudBackendConfig.isConfigured)
        #expect(CloudBackendConfig.supabaseURL != nil)
        #expect(!CloudBackendConfig.anonKey.isEmpty)
    }

    // MARK: - Captura de perfil (regla anti-sangrado de PII entre cuentas, fix R2 #1)

    @Test func profileCapture_sameAccount_onlyFillsGaps() {
        // Misma cuenta, perfil ya capturado: NO se sobrescribe (Apple no repite email/fullName).
        let d = CloudAuthProfileCapture.decide(
            storedAppleUserID: "apple-A", incomingAppleUserID: "apple-A",
            hasStoredEmail: true, hasStoredFullName: true,
            hasIncomingEmail: true, hasIncomingFullName: true
        )
        #expect(d == .init(clearStoredProfile: false, writeEmail: false, writeFullName: false))
    }

    @Test func profileCapture_sameAccount_fillsMissingPieces() {
        let d = CloudAuthProfileCapture.decide(
            storedAppleUserID: "apple-A", incomingAppleUserID: "apple-A",
            hasStoredEmail: false, hasStoredFullName: true,
            hasIncomingEmail: true, hasIncomingFullName: true
        )
        #expect(d == .init(clearStoredProfile: false, writeEmail: true, writeFullName: false))
    }

    @Test func profileCapture_firstSignInOnDevice_writesEverythingIncoming() {
        let d = CloudAuthProfileCapture.decide(
            storedAppleUserID: nil, incomingAppleUserID: "apple-A",
            hasStoredEmail: false, hasStoredFullName: false,
            hasIncomingEmail: true, hasIncomingFullName: false
        )
        #expect(d == .init(clearStoredProfile: false, writeEmail: true, writeFullName: false))
    }

    @Test func profileCapture_accountChanged_overwritesEvenWithStoredProfile() {
        // El caso del sangrado: B firma tras A. El guard "solo huecos" NO aplica — se borra el perfil
        // de A y se escribe el de B (lo que venga).
        let d = CloudAuthProfileCapture.decide(
            storedAppleUserID: "apple-A", incomingAppleUserID: "apple-B",
            hasStoredEmail: true, hasStoredFullName: true,
            hasIncomingEmail: true, hasIncomingFullName: true
        )
        #expect(d == .init(clearStoredProfile: true, writeEmail: true, writeFullName: true))
    }

    @Test func profileCapture_accountChanged_withoutIncomingData_stillClears() {
        // B firma sin entregar email/nombre (no es su primer sign-in de esa cuenta en Apple): el
        // perfil de A igualmente se BORRA — mejor perfil vacío que el de otra persona.
        let d = CloudAuthProfileCapture.decide(
            storedAppleUserID: "apple-A", incomingAppleUserID: "apple-B",
            hasStoredEmail: true, hasStoredFullName: true,
            hasIncomingEmail: false, hasIncomingFullName: false
        )
        #expect(d == .init(clearStoredProfile: true, writeEmail: false, writeFullName: false))
    }

    // MARK: - Keychain storage (round-trip + accesibilidad)

    @Test func keychainStorage_roundTrip() throws {
        let service = "test.cloudauth.\(UUID().uuidString)"
        let storage = CloudAuthKeychainStorage(service: service)
        defer { try? storage.remove(key: "k") }

        #expect(try storage.retrieve(key: "k") == nil)
        try storage.store(key: "k", value: Data("hello".utf8))
        #expect(try storage.retrieve(key: "k") == Data("hello".utf8))
        // Sobrescritura.
        try storage.store(key: "k", value: Data("world".utf8))
        #expect(try storage.retrieve(key: "k") == Data("world".utf8))
        try storage.remove(key: "k")
        #expect(try storage.retrieve(key: "k") == nil)
    }

    @Test func keychainStorage_accessibleAfterFirstUnlockThisDeviceOnly() throws {
        let service = "test.cloudauth.\(UUID().uuidString)"
        let storage = CloudAuthKeychainStorage(service: service)
        defer { try? storage.remove(key: "k") }
        try storage.store(key: "k", value: Data("v".utf8))

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "k",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        #expect(status == errSecSuccess)
        let attrs = result as? [String: Any]
        let accessible = attrs?[kSecAttrAccessible as String] as? String
        #expect(accessible == (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String))
    }
}
