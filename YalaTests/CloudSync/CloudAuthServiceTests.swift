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

    // MARK: - Provider persistido (Google Sign-In sesión 1)

    @Test func providerKey_roundTrip_storeReadClear() throws {
        // La key `cloudauth.provider` es credencial de SESIÓN (se escribe en ambos sign-ins, se borra
        // en signOut). Round-trip con service aislado (molde keychainStorage_roundTrip).
        let service = "test.cloudauth.\(UUID().uuidString)"
        let storage = CloudAuthKeychainStorage(service: service)
        let key = "cloudauth.provider"
        defer { try? storage.remove(key: key) }

        #expect(try storage.retrieve(key: key) == nil)
        try storage.store(key: key, value: Data("google".utf8))
        #expect(try storage.retrieve(key: key) == Data("google".utf8))
        // Re-sign-in con el otro provider: el más fresco gana.
        try storage.store(key: key, value: Data("apple".utf8))
        #expect(try storage.retrieve(key: key) == Data("apple".utf8))
        // signOut → clear.
        try storage.remove(key: key)
        #expect(try storage.retrieve(key: key) == nil)
    }
}

// MARK: - Roundtrip Keychain del PAR Google (googleUserID, sub) — molde SIWARefreshTokenStoreTests

@MainActor
@Suite
struct GoogleUserPairStoreTests {

    /// Service único por test: aísla del Keychain real de la app y de otros tests (sin `.serialized`).
    private func makeStore() -> (store: GoogleUserPairStore, raw: CloudAuthKeychainStorage) {
        let storage = CloudAuthKeychainStorage(service: "test.googlepair.\(UUID().uuidString)")
        return (GoogleUserPairStore(storage: storage), storage)
    }

    @Test func writeReadClear_roundtrip() throws {
        let (store, _) = makeStore()
        defer { store.clear() }
        let pair = GoogleUserPairStore.Pair(googleUserID: "google-A", sub: "sub-a")

        try store.write(pair)
        #expect(store.read() == pair)

        store.clear()
        #expect(store.read() == nil)
    }

    @Test func rewrite_overwritesBothKeys() throws {
        let (store, _) = makeStore()
        defer { store.clear() }
        try store.write(GoogleUserPairStore.Pair(googleUserID: "google-OLD", sub: "sub-old"))
        try store.write(GoogleUserPairStore.Pair(googleUserID: "google-NEW", sub: "sub-new"))

        // Re-sign-in: el par completo más fresco gana (write pisa AMBAS keys, jamás mezcla).
        #expect(store.read() == GoogleUserPairStore.Pair(googleUserID: "google-NEW", sub: "sub-new"))
    }

    /// Invariante anti-cruce (heredada del SERIO #1 de B1): `write` hace CLEAR del par previo ANTES
    /// de escribir → ningún estado intermedio (kill entre writes) produce un par CRUZADO
    /// `(googleUserID nuevo, sub viejo)`: o nil, o el par del dueño intacto, o el par nuevo completo.
    @Test func writeSequence_intermediateStates_neverYieldCrossedPair() throws {
        let owner = GoogleUserPairStore.Pair(googleUserID: "google-OWNER", sub: "sub-owner")
        let incoming = GoogleUserPairStore.Pair(googleUserID: "google-GUEST", sub: "sub-guest")
        let crossed = GoogleUserPairStore.Pair(googleUserID: incoming.googleUserID, sub: owner.sub)

        let steps: [(String, (GoogleUserPairStore, CloudAuthKeychainStorage) throws -> Void)] = [
            ("kill tras clear", { store, _ in store.clear() }),
            ("kill tras store(user)", { store, raw in
                store.clear()
                try raw.store(key: GoogleUserPairStore.userIDKey, value: Data(incoming.googleUserID.utf8))
            }),
            ("write completo", { store, _ in try store.write(incoming) }),
        ]
        for (label, run) in steps {
            let (store, raw) = makeStore()
            defer { store.clear() }
            try store.write(owner)
            try run(store, raw)
            let result = store.read()
            #expect(result != crossed, "estado '\(label)' produjo un par CRUZADO")
            #expect(result == nil || result == owner || result == incoming,
                    "estado '\(label)': \(String(describing: result))")
        }
    }

    @Test func halfPair_userWithoutSub_readsNil() throws {
        let (store, raw) = makeStore()
        defer { store.clear() }
        // Kill entre writes: solo el userID presente → el reader lo trata como AUSENCIA.
        try raw.store(key: GoogleUserPairStore.userIDKey, value: Data("google-A".utf8))

        #expect(store.read() == nil)
    }

    @Test func halfPair_subWithoutUser_readsNil() throws {
        let (store, raw) = makeStore()
        defer { store.clear() }
        try raw.store(key: GoogleUserPairStore.subKey, value: Data("sub-a".utf8))

        #expect(store.read() == nil)
    }

    @Test func emptyValues_readAsNil() throws {
        let (store, raw) = makeStore()
        defer { store.clear() }
        try raw.store(key: GoogleUserPairStore.userIDKey, value: Data())
        try raw.store(key: GoogleUserPairStore.subKey, value: Data("sub-a".utf8))

        #expect(store.read() == nil)
    }
}
