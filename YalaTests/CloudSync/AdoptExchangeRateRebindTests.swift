//
//  AdoptExchangeRateRebindTests.swift
//  YalaTests
//
//  El reparto del casado de tipos de cambio del adopt (card hov2): qué identidad de la cuenta toma cada tipo de cambio
//  local sin identidad. Lógica pura; el recorrido entero con el ejecutor real está en `MigrationWorkExecutorTests`
//  (`adoptReconcile_exchangeRatesTheAccountHas_takeItsIdentity` y sus dos controles).
//

import Foundation
import Testing

@testable import Yala

@Suite("Adopt — los tipos de cambio toman la identidad de la cuenta (hov2)")
struct AdoptExchangeRateRebindTests {

    private let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    private let c = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!

    @Test func withSeveralInTheAccount_takesTheSmallestID() {
        let plan = AdoptExchangeRateRebind.plan(
            candidates: [.init(index: 0, anchor: "d1")], backendLive: [b: "d1", a: "d1"], taken: [],
            localAnchors: ["d1"])
        #expect(plan == [0: a])
    }

    /// Dos filas locales del mismo día: una puede ser la del líder, que traerá la identidad del backend más tarde. No se
    /// casa ninguna, ni siquiera si la otra ya tiene identidad (lo cazó la review).
    @Test func twoLocalRowsForTheSameDay_noneIsRebound() {
        let both = AdoptExchangeRateRebind.plan(
            candidates: [.init(index: 0, anchor: "d1"), .init(index: 1, anchor: "d1")], backendLive: [a: "d1", b: "d1"],
            taken: [], localAnchors: ["d1", "d1"])
        #expect(both.isEmpty)
        let oneWithIdentity = AdoptExchangeRateRebind.plan(
            candidates: [.init(index: 1, anchor: "d1")], backendLive: [a: "d1"], taken: [c], localAnchors: ["d1", "d1"])
        #expect(oneWithIdentity.isEmpty)
    }

    @Test func anIDALocalRowAlreadyCarries_isNotGivenAgain() {
        let plan = AdoptExchangeRateRebind.plan(
            candidates: [.init(index: 0, anchor: "d1")], backendLive: [a: "d1", b: "d1"], taken: [a],
            localAnchors: ["d1", "d2"])
        #expect(plan == [0: b])
    }

    @Test func noMatchingAnchor_noAssignment() {
        let plan = AdoptExchangeRateRebind.plan(
            candidates: [.init(index: 0, anchor: "d2")], backendLive: [a: "d1", c: "d3"], taken: [], localAnchors: ["d2"])
        #expect(plan.isEmpty)
    }

    @Test func backendAnchor_readsDateAndBase_andRefusesWhatItCannotRead() {
        let fields: [String: WireValue] = ["date_key": .string("2026-09-23"), "base": .string("USD")]
        #expect(AdoptExchangeRateRebind.backendAnchor(fields: fields)
                == SyncContentAnchor.exchangeRate(dateKey: "2026-09-23", base: "USD"))
        #expect(AdoptExchangeRateRebind.backendAnchor(fields: ["date_key": .string("2026-09-23")]) == nil)
        #expect(AdoptExchangeRateRebind.backendAnchor(fields: ["date_key": .null, "base": .string("USD")]) == nil)
    }
}
