//
//  EntryReadinessLogicTests.swift
//  YalaTests
//
//  Las entradas que deciden con estado aún sin cargar (Pro, consentimiento, eje de sesión) esperan al arranque
//  (ticket share-image-reading-does-not-always-start).
//

import Testing
@testable import Yala

@Suite("EntryReadinessLogic")
struct EntryReadinessLogicTests {

    @Test(arguments: ["shared-image", "image-entry", "voice-entry", "new-transaction", "activate-full"])
    func decidingHosts_waitBeforeBootstrap(host: String) {
        #expect(EntryReadinessLogic.waitsForBootstrap(host: host, isInitialized: false))
        #expect(!EntryReadinessLogic.waitsForBootstrap(host: host, isInitialized: true))
    }

    /// Una pestaña no decide nada: sigue por el aplazamiento del router, que ya la conserva entre arranques.
    @Test(arguments: ["panel", "statistics", "planning", "budgets", "records", "groups"])
    func navigationHosts_neverWait(host: String) {
        #expect(!EntryReadinessLogic.waitsForBootstrap(host: host, isInitialized: false))
        #expect(!EntryReadinessLogic.waitsForBootstrap(host: host, isInitialized: true))
    }

    @Test func missingHost_neverWaits() {
        #expect(!EntryReadinessLogic.waitsForBootstrap(host: nil, isInitialized: false))
    }

    @Test func controlAction_runsOnlyAfterBootstrap() {
        #expect(!EntryReadinessLogic.controlActionMayRun(isInitialized: false))
        #expect(EntryReadinessLogic.controlActionMayRun(isInitialized: true))
    }
}
