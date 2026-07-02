//
//  PendingIntentSaveSignalTests.swift
//  YalaTests
//
//  Unit tests para el store del flag cross-launch que un App Intent background usa para
//  avisar a la app que guardó datos (ver PendingIntentSaveSignal).
//

import Foundation
import Testing

@testable import Yala

struct PendingIntentSaveSignalTests {

    /// Helper: UserDefaults aislado por test (regla del proyecto — nunca .standard).
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test func markThenConsume_returnsTimestampAndClears() {
        let defaults = makeDefaults()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        PendingIntentSaveSignal.mark(now: now, defaults: defaults)
        let consumed = PendingIntentSaveSignal.consume(defaults: defaults)

        #expect(consumed?.timeIntervalSince1970 == now.timeIntervalSince1970)
        // Segundo consume: ya se limpió → nil.
        #expect(PendingIntentSaveSignal.consume(defaults: defaults) == nil)
    }

    @Test func consume_withoutMark_returnsNil() {
        let defaults = makeDefaults()
        #expect(PendingIntentSaveSignal.consume(defaults: defaults) == nil)
    }

    @Test func markTwice_lastWriteWins() {
        let defaults = makeDefaults()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Date(timeIntervalSince1970: 1_700_000_500)

        PendingIntentSaveSignal.mark(now: first, defaults: defaults)
        PendingIntentSaveSignal.mark(now: second, defaults: defaults)

        #expect(PendingIntentSaveSignal.consume(defaults: defaults)?.timeIntervalSince1970 == second.timeIntervalSince1970)
    }

    @Test func consume_nonDoubleGarbage_returnsNilAndClears() {
        let defaults = makeDefaults()
        // Valor corrupto no-numérico bajo la key: consume debe devolver nil Y limpiar
        // (fuerza la implementación `object(forKey:) as? Double`, no `double(forKey:)`).
        defaults.set("garbage", forKey: AppPreferences.Keys.pendingIntentSaveAt)

        #expect(PendingIntentSaveSignal.consume(defaults: defaults) == nil)
        #expect(defaults.object(forKey: AppPreferences.Keys.pendingIntentSaveAt) == nil)
    }

    @Test func ageBucket_boundaries() {
        #expect(PendingIntentSaveSignal.ageBucket(0) == "<10s")
        #expect(PendingIntentSaveSignal.ageBucket(9.9) == "<10s")
        #expect(PendingIntentSaveSignal.ageBucket(10) == "10s-5m")
        #expect(PendingIntentSaveSignal.ageBucket(299) == "10s-5m")
        #expect(PendingIntentSaveSignal.ageBucket(300) == ">5m")
        #expect(PendingIntentSaveSignal.ageBucket(10_000) == ">5m")
    }
}
