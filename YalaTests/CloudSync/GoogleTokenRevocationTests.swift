//
//  GoogleTokenRevocationTests.swift
//  YalaTests
//
//  Sesión 3 Google Sign-In (simetría 5.1.1(v)): revocación del grant OAuth con deps inyectadas (sin SDK,
//  sin red ni singletons) — molde exacto `SIWATokenRevocationTests`. Cubre el MATCH DOBLE del §0 del plan:
//  (1) `pair.sub == currentSub` (par de ESTA cuenta — hazard cross-cuenta M1) y (2) `sdkUserID ==
//  pair.googleUserID` (la sesión SDK es DEL MISMO humano que el par — jamás disconnect sobre la sesión de
//  otro). El roundtrip Keychain del PAR vive en `CloudAuthServiceTests.GoogleUserPairStoreTests` (sesión 1).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite
struct GoogleTokenRevocationTests {

    /// Control mutable compartido por los closures mock (molde `SIWATokenRevocationTests.Ctrl`).
    final class Ctrl {
        var events: [String] = []
        var pair: GoogleUserPairStore.Pair?
        var currentSub: String?
        var sdkUserID: String?
        var disconnectSucceeds = true
    }

    private func makeDeps(_ c: Ctrl) -> GoogleTokenRevocation.Dependencies {
        GoogleTokenRevocation.Dependencies(
            readPair: { c.events.append("read"); return c.pair },
            currentSub: { c.currentSub },
            sdkUserID: { c.events.append("sdk"); return c.sdkUserID },
            disconnect: { c.events.append("disconnect"); return c.disconnectSucceeds },
            clearPair: { c.events.append("clear") }
        )
    }

    @Test func validPair_doubleMatch_disconnects_andClearsPair() async {
        let c = Ctrl()
        c.pair = GoogleUserPairStore.Pair(googleUserID: "google-A", sub: "sub-a")
        c.currentSub = "sub-a"
        c.sdkUserID = "google-A"

        await GoogleTokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read", "sdk", "disconnect", "clear"])
    }

    @Test func noPair_skips_noDisconnect_noClear() async {
        let c = Ctrl()
        c.pair = nil

        await GoogleTokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read"])
    }

    /// Match #1 (§0): par de OTRA cuenta Supabase (hazard cross-cuenta M1 — p.ej. residuo del dueño bajo
    /// la secundaria) → no-op SIN consultar el SDK, SIN disconnect y SIN limpiar (sigue válido para su
    /// dueño; borrar la secundaria JAMÁS revoca al dueño).
    @Test func stalePair_subMismatch_skips_noDisconnect_noClear() async {
        let c = Ctrl()
        c.pair = GoogleUserPairStore.Pair(googleUserID: "google-OWNER", sub: "sub-owner")
        c.currentSub = "sub-guest"
        c.sdkUserID = "google-OWNER"

        await GoogleTokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read"])
    }

    @Test func noCurrentSub_treatedAsStale_skips() async {
        let c = Ctrl()
        c.pair = GoogleUserPairStore.Pair(googleUserID: "google-A", sub: "sub-a")
        c.currentSub = nil

        await GoogleTokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read"])
    }

    /// Sin sesión SDK restaurable (p.ej. post-reinstalación): skip legítimo SIN limpiar — el grant queda
    /// vivo pero el token es inerte (residual documentado, D1 del plan de sesión 1).
    @Test func noSDKSession_skips_noDisconnect_noClear() async {
        let c = Ctrl()
        c.pair = GoogleUserPairStore.Pair(googleUserID: "google-A", sub: "sub-a")
        c.currentSub = "sub-a"
        c.sdkUserID = nil

        await GoogleTokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read", "sdk"])
    }

    /// Match #2 (§0): la sesión del SDK pertenece a OTRO humano que el par (sign-in SDK de B triunfó con
    /// exchange Supabase fallido) → JAMÁS disconnect (revocaría el grant de B, no el de la cuenta que se
    /// borra) y SIN limpiar.
    @Test func staleSDKSession_userMismatch_neverDisconnects() async {
        let c = Ctrl()
        c.pair = GoogleUserPairStore.Pair(googleUserID: "google-A", sub: "sub-a")
        c.currentSub = "sub-a"
        c.sdkUserID = "google-B"

        await GoogleTokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        #expect(c.events == ["read", "sdk"])
    }

    @Test func disconnectFails_doesNotThrow_doesNotClear() async {
        let c = Ctrl()
        c.pair = GoogleUserPairStore.Pair(googleUserID: "google-A", sub: "sub-a")
        c.currentSub = "sub-a"
        c.sdkUserID = "google-A"
        c.disconnectSucceeds = false

        await GoogleTokenRevocation.revokeIfNeeded(deps: makeDeps(c))

        // disconnect corrió pero NO se limpia (un retry del borrado — .failed(.localClose) — lo reintenta).
        #expect(c.events == ["read", "sdk", "disconnect"])
    }
}
