//
//  SIWATokenRevocationTests.swift
//  YalaTests
//
//  B1 (SIWA revoke 5.1.1(v)): revocación con deps inyectadas (sin red ni singletons), composición del
//  canje (`SIWAExchangeSeam.performExchange`), lógica post-credencial del capture (`SIWAExchangeCapture`
//  — el delegate de ASAuthorization no se instancia en tests) y roundtrip Keychain del PAR
//  (`SIWARefreshTokenStore` con service único por test). Sin `makeTestContext` → suites sin `.serialized`.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Revocación (deps inyectadas)

@MainActor
@Suite
struct SIWATokenRevocationTests {

    /// Control mutable compartido por los closures mock (molde `AccountDeletionServiceTests.Ctrl`).
    final class Ctrl {
        var events: [String] = []
        var pair: SIWARefreshTokenStore.Pair?
        var currentAppleUserID: String?
        var jwt: String? = "jwt-live"
        var revokeSucceeds = true
        var revokedWith: (jwt: String, token: String)?
    }

    private func makeDeps(_ c: Ctrl) -> SIWATokenRevocation.Dependencies {
        SIWATokenRevocation.Dependencies(
            readPair: { c.events.append("read"); return c.pair },
            currentAppleUserID: { c.currentAppleUserID },
            accessToken: { c.jwt },
            revoke: { jwt, token in
                c.events.append("revoke")
                c.revokedWith = (jwt, token)
                return c.revokeSucceeds
            },
            clearPair: { c.events.append("clear") }
        )
    }

    @Test func validPair_match_posts_andClearsPair() async {
        let c = Ctrl()
        c.pair = SIWARefreshTokenStore.Pair(refreshToken: "r-token", appleUserID: "apple-A")
        c.currentAppleUserID = "apple-A"

        await SIWATokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read", "revoke", "clear"])
        #expect(c.revokedWith?.jwt == "jwt-live")
        #expect(c.revokedWith?.token == "r-token")
    }

    @Test func noPair_skips_noPost_noClear() async {
        let c = Ctrl()
        c.pair = nil

        await SIWATokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read"])
    }

    /// AJUSTE #1: par de OTRA cuenta de Apple (hazard cross-cuenta M1) → no-op SIN POST y SIN limpiar
    /// (el par sigue siendo válido para su dueño; borrar la secundaria JAMÁS revoca al dueño).
    @Test func stalePair_userMismatch_skips_noPost_noClear() async {
        let c = Ctrl()
        c.pair = SIWARefreshTokenStore.Pair(refreshToken: "r-token-owner", appleUserID: "apple-OWNER")
        c.currentAppleUserID = "apple-GUEST"

        await SIWATokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read"])
        #expect(c.revokedWith == nil)
    }

    @Test func noCurrentAppleUserID_treatedAsStale_skips() async {
        let c = Ctrl()
        c.pair = SIWARefreshTokenStore.Pair(refreshToken: "r-token", appleUserID: "apple-A")
        c.currentAppleUserID = nil

        await SIWATokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read"])
    }

    @Test func revokeFails_doesNotThrow_doesNotClear() async {
        let c = Ctrl()
        c.pair = SIWARefreshTokenStore.Pair(refreshToken: "r-token", appleUserID: "apple-A")
        c.currentAppleUserID = "apple-A"
        c.revokeSucceeds = false

        await SIWATokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        // POST corrió pero NO se limpia (un retry del borrado lo reintenta).
        #expect(c.events == ["read", "revoke"])
    }

    @Test func noJwt_doesNotPost_doesNotClear() async {
        let c = Ctrl()
        c.pair = SIWARefreshTokenStore.Pair(refreshToken: "r-token", appleUserID: "apple-A")
        c.currentAppleUserID = "apple-A"
        c.jwt = nil

        await SIWATokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read"])
    }
}

// MARK: - Composición del canje

@MainActor
@Suite
struct SIWAExchangeSeamTests {

    final class Ctrl {
        var events: [String] = []
        var jwt: String? = "jwt-live"
        var exchangeResult: String? = "apple-refresh"
        var exchangedWith: (jwt: String, code: String)?
        var storedPair: SIWARefreshTokenStore.Pair?
        var storeThrows = false
    }

    struct StoreError: Error {}

    private func makeDeps(_ c: Ctrl) -> SIWAExchangeSeam.Dependencies {
        SIWAExchangeSeam.Dependencies(
            accessToken: { c.jwt },
            exchange: { jwt, code in
                c.events.append("exchange")
                c.exchangedWith = (jwt, code)
                return c.exchangeResult
            },
            storePair: { pair in
                c.events.append("store")
                if c.storeThrows { throw StoreError() }
                c.storedPair = pair
            }
        )
    }

    @Test func happyPath_exchanges_andStoresPairWithAppleUserID() async {
        let c = Ctrl()

        await SIWAExchangeSeam.performExchange(
            authorizationCode: "auth-code", appleUserID: "apple-A", deps: makeDeps(c))

        #expect(c.events == ["exchange", "store"])
        #expect(c.exchangedWith?.jwt == "jwt-live")
        #expect(c.exchangedWith?.code == "auth-code")
        // AJUSTE #1: el par se escribe JUNTO — el token queda atribuido al appleUserID de ESTE sign-in.
        #expect(c.storedPair == SIWARefreshTokenStore.Pair(refreshToken: "apple-refresh", appleUserID: "apple-A"))
    }

    @Test func exchangeFails_noStore_noThrow() async {
        let c = Ctrl()
        c.exchangeResult = nil

        await SIWAExchangeSeam.performExchange(
            authorizationCode: "auth-code", appleUserID: "apple-A", deps: makeDeps(c))

        #expect(c.events == ["exchange"])
        #expect(c.storedPair == nil)
    }

    @Test func noJwt_noExchange_noStore() async {
        let c = Ctrl()
        c.jwt = nil

        await SIWAExchangeSeam.performExchange(
            authorizationCode: "auth-code", appleUserID: "apple-A", deps: makeDeps(c))

        #expect(c.events.isEmpty)
    }

    @Test func storeThrows_isBestEffort_noCrash() async {
        let c = Ctrl()
        c.storeThrows = true

        await SIWAExchangeSeam.performExchange(
            authorizationCode: "auth-code", appleUserID: "apple-A", deps: makeDeps(c))

        #expect(c.events == ["exchange", "store"])
        #expect(c.storedPair == nil)
    }
}

// MARK: - Capture post-credencial (delegate no instanciable en tests)

@MainActor
@Suite
struct SIWAExchangeCaptureTests {

    @Test func code_decodesUTF8_nonEmpty() {
        #expect(SIWAExchangeCapture.code(from: Data("abc123".utf8)) == "abc123")
        #expect(SIWAExchangeCapture.code(from: Data()) == nil)
        #expect(SIWAExchangeCapture.code(from: nil) == nil)
    }

    @Test func dispatch_hookNil_isNoOp() {
        // Default de producción sin componer / tests: byte-idéntico (guard del hook ANTES de mirar el code).
        SIWAExchangeCapture.dispatch(hook: nil, codeData: Data("abc".utf8), appleUserID: "apple-A")
        // Sin hook no hay efecto observable — el test documenta que NO crashea ni exige code válido.
    }

    @Test func dispatch_hookInstalled_receivesDecodedCodeAndUser() {
        var received: (code: String, user: String)?
        SIWAExchangeCapture.dispatch(
            hook: { code, user in received = (code, user) },
            codeData: Data("the-code".utf8),
            appleUserID: "apple-A"
        )
        #expect(received?.code == "the-code")
        #expect(received?.user == "apple-A")
    }

    @Test func dispatch_missingCode_doesNotInvokeHook() {
        var invoked = false
        SIWAExchangeCapture.dispatch(
            hook: { _, _ in invoked = true },
            codeData: nil,
            appleUserID: "apple-A"
        )
        #expect(!invoked)
    }
}

// MARK: - Roundtrip Keychain del PAR

@MainActor
@Suite
struct SIWARefreshTokenStoreTests {

    /// Service único por test: aísla del Keychain real de la app y de otros tests (sin `.serialized`).
    private func makeStore() -> (store: SIWARefreshTokenStore, raw: CloudAuthKeychainStorage) {
        let storage = CloudAuthKeychainStorage(service: "test.siwa.\(UUID().uuidString)")
        return (SIWARefreshTokenStore(storage: storage), storage)
    }

    @Test func writeReadClear_roundtrip() throws {
        let (store, _) = makeStore()
        defer { store.clear() }
        let pair = SIWARefreshTokenStore.Pair(refreshToken: "r-token", appleUserID: "apple-A")

        try store.write(pair)
        #expect(store.read() == pair)

        store.clear()
        #expect(store.read() == nil)
    }

    @Test func rewrite_overwritesPreviousPair() throws {
        let (store, _) = makeStore()
        defer { store.clear() }
        try store.write(SIWARefreshTokenStore.Pair(refreshToken: "old", appleUserID: "apple-OLD"))
        try store.write(SIWARefreshTokenStore.Pair(refreshToken: "new", appleUserID: "apple-NEW"))

        // Re-sign-in: el par completo más fresco gana (jamás token nuevo con user viejo).
        #expect(store.read() == SIWARefreshTokenStore.Pair(refreshToken: "new", appleUserID: "apple-NEW"))
    }

    /// SERIO #1 del review adversarial — invariante anti-cruce: `write` BORRA el par previo ANTES de
    /// escribir, así una sobrescritura matada entre pasos JAMÁS deja `(token del dueño, user nuevo)`.
    /// Se ejercita reproduciendo por tabla cada estado intermedio de la secuencia de `write` (clear →
    /// store(user) → store(token)) sobre un par preexistente del DUEÑO: en ninguno el reader devuelve
    /// un par CRUZADO (o nil, o el par del dueño intacto, o el par nuevo completo).
    @Test func writeSequence_intermediateStates_neverYieldCrossedPair() throws {
        let owner = SIWARefreshTokenStore.Pair(refreshToken: "token-OWNER", appleUserID: "apple-OWNER")
        let incoming = SIWARefreshTokenStore.Pair(refreshToken: "token-GUEST", appleUserID: "apple-GUEST")
        let crossed = SIWARefreshTokenStore.Pair(refreshToken: owner.refreshToken, appleUserID: incoming.appleUserID)

        // Estados tras cada paso de write(incoming) sobre owner preexistente (kill después del paso N):
        let steps: [(String, (SIWARefreshTokenStore, CloudAuthKeychainStorage) throws -> Void)] = [
            ("kill tras clear", { store, _ in store.clear() }),
            ("kill tras store(user)", { store, raw in
                store.clear()
                try raw.store(key: SIWARefreshTokenStore.userKey, value: Data(incoming.appleUserID.utf8))
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
            #expect(result == nil || result == owner || result == incoming, "estado '\(label)': \(String(describing: result))")
        }
    }

    @Test func halfPair_tokenWithoutUser_readsNil() throws {
        let (store, raw) = makeStore()
        defer { store.clear() }
        // Kill entre writes: solo el token presente → el reader lo trata como AUSENCIA (skip del revoke).
        try raw.store(key: SIWARefreshTokenStore.tokenKey, value: Data("orphan-token".utf8))

        #expect(store.read() == nil)
    }

    @Test func halfPair_userWithoutToken_readsNil() throws {
        let (store, raw) = makeStore()
        defer { store.clear() }
        try raw.store(key: SIWARefreshTokenStore.userKey, value: Data("apple-A".utf8))

        #expect(store.read() == nil)
    }

    @Test func emptyStore_readsNil_andClearIsIdempotent() {
        let (store, _) = makeStore()
        #expect(store.read() == nil)
        store.clear()  // itemNotFound = éxito
        #expect(store.read() == nil)
    }
}
